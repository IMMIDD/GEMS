export each_infection, each_immunity


# Resolves the shard registry only when overflow is actually reached, so a cache-only
# individual never touches the registry. Dispatches on the concrete source type, so it stays
# type-stable; the registries-vector form is what a Simulation passes.
@inline _shard_registry(src::Union{InfectionRegistry,ImmunityRegistry}, ind::Individual) = src
@inline _shard_registry(src::Union{Vector{InfectionRegistry},Vector{ImmunityRegistry}}, ind::Individual) = @inbounds src[_owner_shard(id(ind))]

"""
    InfectionIterator

Iterates over all active `InfectionState` entries for an individual: cache slots
first, then overflow nodes. Only yields entries where `active == true`.

`src` is either a single `InfectionRegistry` or the simulation's `Vector{InfectionRegistry}`;
the shard is resolved lazily, so a cache-only individual never touches the registry.
"""
struct InfectionIterator{S<:Union{InfectionRegistry,Vector{InfectionRegistry}}}
    individual::Individual
    src::S
end

"""
    each_infection(individual, registry) → InfectionIterator

Returns an iterator over all active `InfectionState` entries for `individual`.
"""
@inline each_infection(ind::Individual, reg::InfectionRegistry) = InfectionIterator(ind, reg)
@inline each_infection(ind::Individual, sim::Simulation) = InfectionIterator(ind, sim.infection_registries)
@inline each_infection(ind::Individual, registries::Vector{InfectionRegistry}) = InfectionIterator(ind, registries)

@inline function Base.iterate(iter::InfectionIterator, state::Tuple{Int32,Bool} = (Int32(1), true))
    i, in_cache = state

    if in_cache
        while i <= Int32(INFECTIONS_CACHE_SIZE)
            @inbounds s = iter.individual.infection_cache[i]
            s.active && return (s, (i + Int32(1), true))
            i += Int32(1)
        end
        i = iter.individual.infection_head
    end

    i == Int32(0) && return nothing
    reg = _shard_registry(iter.src, iter.individual)
    @inbounds s = reg.states[i]
    return (s, (s.next, false))
end

Base.eltype(::Type{<:InfectionIterator}) = InfectionState
Base.IteratorSize(::Type{<:InfectionIterator}) = Base.SizeUnknown()



"""
    ImmunityIterator

Iterates over all `ImmunityState` entries for an individual: cache slots first,
then overflow nodes in the linked-list registry. Yields only active entries.
Users of custom `TransmissionFunction` implementations should use this rather
than accessing `immunity_cache` or the registry directly.
"""
struct ImmunityIterator{S<:Union{ImmunityRegistry,Vector{ImmunityRegistry}}}
    individual::Individual
    src::S
end

"""
    each_immunity(individual, registry) → ImmunityIterator

Returns an iterator over all active `ImmunityState` entries for `individual`,
covering both on-individual cache slots and any overflow nodes in `registry`.

`src` is either a single `ImmunityRegistry` or the simulation's `Vector{ImmunityRegistry}`;
the shard is resolved lazily, so a cache-only individual never touches the registry.
"""
@inline each_immunity(ind::Individual, reg::ImmunityRegistry) = ImmunityIterator(ind, reg)
@inline each_immunity(ind::Individual, sim::Simulation) = ImmunityIterator(ind, sim.immunity_registries)
@inline each_immunity(ind::Individual, registries::Vector{ImmunityRegistry}) = ImmunityIterator(ind, registries)

# state = (next_index::Int32, in_cache::Bool)
@inline function Base.iterate(iter::ImmunityIterator, state::Tuple{Int32,Bool} = (Int32(1), true))
    i, in_cache = state

    if in_cache
        while i <= Int32(IMMUNITY_CACHE_SIZE)
            @inbounds s = iter.individual.immunity_cache[i]
            _is_active_immunity(s) && return (s, (i + Int32(1), true))
            i += Int32(1)
        end
        i = iter.individual.immunity_head
    end

    i == Int32(0) && return nothing
    reg = _shard_registry(iter.src, iter.individual)
    @inbounds s = reg.states[i]
    return (s, (s.next, false))
end

Base.eltype(::Type{<:ImmunityIterator}) = ImmunityState
Base.IteratorSize(::Type{<:ImmunityIterator}) = Base.SizeUnknown()