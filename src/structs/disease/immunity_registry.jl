export ImmunityRegistry, ImmunityState
export push_immunity!, remove_immunity!, get_immunity_state


"""
    ImmunityState

Immutable, bits-type record used for both storage in `ImmunityRegistry` (overflow)
and as the on-individual cache (`immunity_cache`) and the public snapshot passed to
`ImmunityProfile.calculate_immunity`.

One entry per `(individual, pathogen)` — combines natural and vaccine immunity.
`next::Int32` chains overflow nodes; always 0 for cache states.
`immunity_level::Int8` is the computed immunity level (0–100), updated each tick
by `update_immunity!` and read by transmission functions directly from the
individual without touching the registry.

An entry is considered inactive when `pathogen_id == DEFAULT_PATHOGEN_ID`.
"""
struct ImmunityState
    next::Int32
    natural_acquired_tick::Int16  # DEFAULT_TICK if no natural immunity
    vaccine_acquired_tick::Int16  # DEFAULT_TICK if not vaccinated
    immunity_level::Int8          # computed each tick; 0 until update_immunity! runs
    pathogen_id::Int8             # DEFAULT_PATHOGEN_ID signals an empty slot
    vaccine_id::Int8              # DEFAULT_VACCINE_ID if not vaccinated
    dose_number::Int8             # 0 if not vaccinated
end

"""
    ImmunityRegistry

Overflow store for immunity records that exceed `IMMUNITY_CACHE_SIZE` per individual.
For single-pathogen simulations this is never populated.

- `states::Vector{ImmunityState}`: record store; freed indices are recycled.
- `free_slots::Vector{Int32}`: LIFO stack of reusable indices.
- `head::Vector{Int32}`: `head[host_id]` is the first overflow node (0 if none).
"""
struct ImmunityRegistry
    states::Vector{ImmunityState}
    free_slots::Vector{Int32}
    head::Vector{Int32}

    function ImmunityRegistry(n::Int32; eventual_fraction::Float64 = 0.85)
        states = ImmunityState[]
        sizehint!(states, round(Int, n * eventual_fraction))
        free_slots = Int32[]
        sizehint!(free_slots, 1024)
        return new(states, free_slots, zeros(Int32, n))
    end
end



@inline _is_active_immunity(s::ImmunityState) = s.pathogen_id != DEFAULT_PATHOGEN_ID

@inline _empty_immunity_state() =
    ImmunityState(Int32(0), DEFAULT_TICK, DEFAULT_TICK, Int8(0), DEFAULT_PATHOGEN_ID, DEFAULT_VACCINE_ID, Int8(0))

@inline _empty_immunity_state(pathogen_id::Int8) =
    ImmunityState(Int32(0), DEFAULT_TICK, DEFAULT_TICK, Int8(0), pathogen_id, DEFAULT_VACCINE_ID, Int8(0))

@inline function _alloc_state_ir!(reg::ImmunityRegistry, state::ImmunityState)::Int32
    if isempty(reg.free_slots)
        push!(reg.states, state)
        return Int32(length(reg.states))
    else
        idx = pop!(reg.free_slots)
        @inbounds reg.states[idx] = state
        return idx
    end
end

@inline function _push_overflow_ir!(reg::ImmunityRegistry, host_id::Int32, state::ImmunityState)::Int32
    linked = ImmunityState(reg.head[host_id], state.natural_acquired_tick, state.vaccine_acquired_tick, state.immunity_level, state.pathogen_id, state.vaccine_id, state.dose_number)
    idx = _alloc_state_ir!(reg, linked)
    reg.head[host_id] = idx
    return idx
end

@inline function _remove_overflow_node_ir!(reg::ImmunityRegistry, host_id::Int32, node_idx::Int32)
    prev = Int32(0)
    cur  = reg.head[host_id]
    while cur != 0
        @inbounds state = reg.states[cur]
        if cur == node_idx
            if prev == 0
                reg.head[host_id] = state.next
            else
                @inbounds existing = reg.states[prev]
                @inbounds reg.states[prev] = ImmunityState(state.next, existing.natural_acquired_tick,
                    existing.vaccine_acquired_tick, existing.immunity_level, existing.pathogen_id,
                    existing.vaccine_id, existing.dose_number)
            end
            push!(reg.free_slots, node_idx)
            return nothing
        end
        prev = cur
        cur  = state.next
    end
end



"""
    get_immunity_state(registry, host_id, pathogen_id)::ImmunityState

Lookup in the overflow store only. For the hot path, read `individual.immunity_cache`
directly instead.
"""
function get_immunity_state(reg::ImmunityRegistry, host_id::Int32, pathogen_id::Int8)::ImmunityState
    node = reg.head[host_id]
    while node != 0
        @inbounds s = reg.states[node]
        s.pathogen_id == pathogen_id && return s
        node = s.next
    end
    return _empty_immunity_state(pathogen_id)
end

"""
    push_immunity!(registry, host_id, pathogen_id, source, acquired_tick, vaccine_id)

Insert or update an overflow immunity record for `(host_id, pathogen_id)`.
Called only when the individual's `immunity_cache` is full.

- Natural: updates `natural_acquired_tick`; vaccine fields unchanged.
- Vaccine: updates `vaccine_acquired_tick` and `vaccine_id`; increments `dose_number`.
"""
function push_immunity!(
    reg::ImmunityRegistry,
    host_id::Int32,
    pathogen_id::Int8,
    source::Int8,
    acquired_tick::Int16,
    vaccine_id::Int8,
)
    # Search existing overflow node
    node = reg.head[host_id]
    while node != 0
        @inbounds existing = reg.states[node]
        if existing.pathogen_id == pathogen_id
            @inbounds reg.states[node] = if source == IMMUNITY_SOURCE_NATURAL
                ImmunityState(existing.next, acquired_tick, existing.vaccine_acquired_tick,
                              existing.immunity_level, pathogen_id, existing.vaccine_id, existing.dose_number)
            else
                ImmunityState(existing.next, existing.natural_acquired_tick, acquired_tick,
                              existing.immunity_level, pathogen_id, vaccine_id, existing.dose_number + Int8(1))
            end
            return nothing
        end
        node = existing.next
    end

    # New overflow entry
    new_state = if source == IMMUNITY_SOURCE_NATURAL
        ImmunityState(Int32(0), acquired_tick, DEFAULT_TICK, Int8(0), pathogen_id, DEFAULT_VACCINE_ID, Int8(0))
    else
        ImmunityState(Int32(0), DEFAULT_TICK, acquired_tick, Int8(0), pathogen_id, vaccine_id, Int8(1))
    end
    _push_overflow_ir!(reg, host_id, new_state)
    return nothing
end

"""
    remove_immunity!(registry, host_id)

Remove all overflow immunity records for `host_id` (called from `reset!`).
"""
function remove_immunity!(reg::ImmunityRegistry, host_id::Int32)
    cur = reg.head[host_id]
    while cur != 0
        @inbounds nxt = reg.states[cur].next
        push!(reg.free_slots, cur)
        cur = nxt
    end
    reg.head[host_id] = Int32(0)
    return nothing
end