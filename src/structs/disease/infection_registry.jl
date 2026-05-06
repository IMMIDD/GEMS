export InfectionRegistry, InfectionState, PendingInfection
export get_infection_state, push_infection!, remove_infection!, find_infection_index


"""
    InfectionState

Immutable, bits-type record used for both storage in `InfectionRegistry` (overflow)
and as the on-individual cache (`infection_cache`) and the public snapshot passed to
`InfectiousnessProfile.calculate_infectiousness`.

`active = false` signals an empty cache slot or a missing registry lookup.
`next::Int32` chains overflow nodes in the linked list; always 0 for cache states.
`infectiousness::Int8` is computed each tick by `progress_disease!` and stored
here so the spread phase reads it directly from the individual without touching
the registry.
"""
struct InfectionState
    infection_id::Int32
    next::Int32
    exposure::Int16
    infectiousness_onset::Int16
    symptom_onset::Int16
    severeness_onset::Int16
    hospital_admission::Int16
    icu_admission::Int16
    icu_discharge::Int16
    ventilation_admission::Int16
    ventilation_discharge::Int16
    hospital_discharge::Int16
    severeness_offset::Int16
    recovery::Int16
    death::Int16
    infectiousness::Int8
    pathogen_id::Int8
    active::Bool
end

"""
    InfectionRegistry

Overflow store for infections that exceed `INFECTIONS_CACHE_SIZE` per individual.
For single-pathogen simulations this is never populated — all infections live in
`individual.infection_cache` and this registry is never accessed in the hot path.

- `states::Vector{InfectionState}`: record store; freed indices are recycled.
- `free_slots::Vector{Int32}`: LIFO stack of reusable indices.
- `head::Vector{Int32}`: `head[host_id]` is the first overflow node index for that
  individual (0 if no overflow). 
"""
struct InfectionRegistry
    states::Vector{InfectionState}
    free_slots::Vector{Int32}
    head::Vector{Int32}

    function InfectionRegistry(n::Int32; overflow_fraction::Float64 = 0.01)
        states = InfectionState[]
        sizehint!(states, round(Int, n * overflow_fraction))
        free_slots = Int32[]
        sizehint!(free_slots, round(Int, n * overflow_fraction))
        return new(states, free_slots, zeros(Int32, n))
    end
end


"""
    PendingInfection

Per-thread transfer struct staged in `infection_buffers` during the threaded
contact phase, then drained into the individual cache / registry by
`flush_pending_infections!`.
"""
struct PendingInfection
    host_id::Int32
    infection_id::Int32
    pathogen_id::Int8
    dp::DiseaseProgression
end




@inline function _empty_infection_state()::InfectionState
    return InfectionState(
        DEFAULT_INFECTION_ID, Int32(0),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int8(0), Int8(0), false,
    )
end


@inline function _placeholder_infection_state(pathogen_id::Int8)::InfectionState
    return InfectionState(
        DEFAULT_INFECTION_ID, Int32(0),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int8(0), pathogen_id, true,
    )
end

@inline function _state_from_pending(pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)::InfectionState
    return InfectionState(
        infection_id, Int32(0),
        exposure(dp),
        infectiousness_onset(dp),
        symptom_onset(dp),
        severeness_onset(dp),
        hospital_admission(dp),
        icu_admission(dp),
        icu_discharge(dp),
        ventilation_admission(dp),
        ventilation_discharge(dp),
        hospital_discharge(dp),
        severeness_offset(dp),
        recovery(dp),
        death(dp),
        Int8(0),
        pathogen_id,
        true,
    )
end

"""
    _setstate(state, ::Val{name}, value)::InfectionState

Return a copy of `state` with field `name` replaced by `value`.
Used by the disease-history tick-setter functions and by `progress_disease!`
to update `infectiousness`.
"""
@inline @generated function _setstate(state::InfectionState, ::Val{name}, value) where {name}
    fields = fieldnames(InfectionState)
    args = [field === name ? :value : :(getfield(state, $(QuoteNode(field)))) for field in fields]
    return :(InfectionState($(args...)))
end




@inline function _alloc_state!(reg::InfectionRegistry, state::InfectionState)::Int32
    if isempty(reg.free_slots)
        push!(reg.states, state)
        return Int32(length(reg.states))
    else
        idx = pop!(reg.free_slots)
        @inbounds reg.states[idx] = state
        return idx
    end
end

# Prepend new_state to the overflow linked list for host_id.
@inline function _push_overflow!(reg::InfectionRegistry, host_id::Int32, state::InfectionState)::Int32
    linked = _setstate(state, Val(:next), reg.head[host_id])
    idx = _alloc_state!(reg, linked)
    reg.head[host_id] = idx
    return idx
end

# Unlink and free the specific node node_idx from host_id's overflow list.
@inline function _remove_overflow_node!(reg::InfectionRegistry, host_id::Int32, node_idx::Int32)
    prev = Int32(0)
    cur  = reg.head[host_id]
    while cur != 0
        @inbounds state = reg.states[cur]
        if cur == node_idx
            if prev == 0
                reg.head[host_id] = state.next
            else
                @inbounds reg.states[prev] = _setstate(reg.states[prev], Val(:next), state.next)
            end
            push!(reg.free_slots, node_idx)
            return nothing
        end
        prev = cur
        cur  = state.next
    end
end




"""
    find_infection_index(infections, host_id, pathogen_id)::Int

Return the index in `infections.states` for the overflow node `(host_id, pathogen_id)`,
or 0 if there is no overflow node. Does NOT search the individual's cache.
"""
@inline function find_infection_index(reg::InfectionRegistry, host_id::Int32, pathogen_id::Int8)::Int
    node = reg.head[host_id]
    while node != 0
        @inbounds s = reg.states[node]
        s.pathogen_id == pathogen_id && return Int(node)
        node = s.next
    end
    return 0
end

"""
    get_infection_state(infections, idx)::InfectionState

Direct index lookup into the overflow store.
Returns the empty sentinel when `idx == 0`.
"""
@inline function get_infection_state(reg::InfectionRegistry, idx::Int32)::InfectionState
    idx == 0 && return _empty_infection_state()
    @inbounds return reg.states[idx]
end

"""
    push_infection!(infections, host_id, pathogen_id, infection_id, dp)

Insert a new overflow infection record. Called only when the individual's
`infection_cache` is already full.
"""
function push_infection!(reg::InfectionRegistry, host_id::Int32, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)
    _push_overflow!(reg, host_id, _state_from_pending(pathogen_id, infection_id, dp))
    return nothing
end

"""
    remove_infection!(infections, host_id, pathogen_id)

Remove the overflow node for `(host_id, pathogen_id)`.
"""
function remove_infection!(reg::InfectionRegistry, host_id::Int32, pathogen_id::Int8)
    idx = find_infection_index(reg, host_id, pathogen_id)
    idx == 0 && return nothing
    _remove_overflow_node!(reg, host_id, Int32(idx))
    return nothing
end

"""
    remove_infection!(infections, host_id)

Remove all overflow nodes for `host_id` (called from `reset!`).
"""
function remove_infection!(reg::InfectionRegistry, host_id::Int32)
    cur = reg.head[host_id]
    while cur != 0
        @inbounds nxt = reg.states[cur].next
        push!(reg.free_slots, cur)
        cur = nxt
    end
    reg.head[host_id] = Int32(0)
    return nothing
end