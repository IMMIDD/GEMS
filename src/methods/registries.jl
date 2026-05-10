export get_infection_state, push_infection!, remove_infections!, remove_infection!, find_infection_index
export get_immunity_state, push_immunity!, remove_immunities!



"""
    _setstate(state, ::Val{name}, value)::InfectionState

Return a copy of `state` with field `name` replaced by `value`.
Used by the disease-history tick-setter functions and by `progress_disease!`
to update `infectiousness`.
"""
@inline @generated function _setstate(state::T, ::Val{name}, value) where {T, name}
    fields = fieldnames(T)
    args = [field === name ? :value : :(getfield(state, $(QuoteNode(field)))) for field in fields]
    return :($(T)($(args...)))
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



"""
    _link_overflow!(reg::InfectionRegistry, ind::Individual, state::InfectionState)::Int32

Prepends a new `InfectionState` to the individual's overflow linked list.
Allocates a new slot in the `InfectionRegistry` memory pool and updates the 
individual's `infection_head` pointer to point to this new node. Returns the 
index of the newly allocated slot.
"""
@inline function _link_overflow!(reg::InfectionRegistry, ind::Individual, state::InfectionState)::Int32
    linked = _setstate(state, Val(:next), ind.infection_head)
    idx = _alloc_state!(reg, linked)
    ind.infection_head = idx
    return idx
end


"""
    _unlink_overflow!(reg::InfectionRegistry, ind::Individual, node_idx::Int32)

Unlinks and frees the specific overflow node at `node_idx` from the individual's 
intrusive linked list. Safely updates either the previous node's `next` pointer 
or the individual's `infection_head` (if it was the first node), and returns the 
index back to the registry's `free_slots` pool for reuse.
"""
@inline function _unlink_overflow!(reg::InfectionRegistry, ind::Individual, node_idx::Int32)
    prev = Int32(0)
    cur  = ind.infection_head
    while cur != 0
        @inbounds state = reg.states[cur]
        if cur == node_idx
            if prev == 0
                ind.infection_head = state.next # Agent head now skips the removed node
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
    _promote_to_cache!(reg::InfectionRegistry, ind::Individual, cache_slot::Int32)
 
Moves the first overflow node into a freed cache slot.
"""
@inline function _promote_to_cache!(reg::InfectionRegistry, ind::Individual, cache_slot::Int32)
    head_idx = ind.infection_head 
    head_idx == 0 && return nothing
 
    @inbounds promoted = reg.states[head_idx]
    ind.infection_cache = Base.setindex(ind.infection_cache, _setstate(promoted, Val(:next), Int32(0)), Int(cache_slot))
 
    ind.infection_head = promoted.next
    push!(reg.free_slots, head_idx)
    return nothing
end



"""
    find_infection_index(reg::InfectionRegistry, ind::Individual, pathogen_id::Int8)::Int

Return the index in `infections.states` for the overflow node `(ind, pathogen_id)`,
or 0 if there is no overflow node. Does NOT search the individual's cache.
"""
@inline function find_infection_index(reg::InfectionRegistry, ind::Individual, pathogen_id::Int8)::Int
    node = ind.infection_head
    while node != 0
        @inbounds s = reg.states[node]
        s.pathogen_id == pathogen_id && return Int(node)
        node = s.next
    end
    return 0
end

"""
    get_infection_state(reg::InfectionRegistry, idx::Int32)::InfectionState

Direct index lookup into the overflow store.
Returns the empty sentinel when `idx == 0`.
"""
@inline function get_infection_state(reg::InfectionRegistry, idx::Int32)::InfectionState
    idx == 0 && return InfectionState()
    @inbounds return reg.states[idx]
end


function push_infection!(reg::InfectionRegistry, ind::Individual, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)
    state = InfectionState(pathogen_id, infection_id, dp)
    @inbounds for i in 1:INFECTIONS_CACHE_SIZE
        if !ind.infection_cache[i].active
            ind.infection_cache = Base.setindex(ind.infection_cache, state, i)
            return nothing
        end
    end
    _link_overflow!(reg, ind, state)
    return nothing
end


function remove_infection!(reg::InfectionRegistry, ind::Individual, val::Int32)
    if val < 0
        ind.infection_head != 0 && _promote_to_cache!(reg, ind, Int32(-val))
    else
        _unlink_overflow!(reg, ind, val)
    end
end

"""
    remove_infections!(reg::InfectionRegistry, ind::Individual)

Remove all overflow nodes for `ind` (called from `reset!`).
"""
function remove_infections!(reg::InfectionRegistry, ind::Individual)
    cur = ind.infection_head
    while cur != 0
        @inbounds nxt = reg.states[cur].next
        push!(reg.free_slots, cur)
        cur = nxt
    end
    ind.infection_head = Int32(0)
    return nothing
end







@inline _is_active_immunity(s::ImmunityState) = s.pathogen_id != DEFAULT_PATHOGEN_ID

@inline function _alloc_state!(reg::ImmunityRegistry, state::ImmunityState)::Int32
    if isempty(reg.free_slots)
        push!(reg.states, state)
        return Int32(length(reg.states))
    else
        idx = pop!(reg.free_slots)
        @inbounds reg.states[idx] = state
        return idx
    end
end

@inline function _link_overflow!(reg::ImmunityRegistry, ind::Individual, state::ImmunityState)::Int32
    linked = _setstate(state, Val(:next), ind.immunity_head)
    idx = _alloc_state!(reg, linked)
    ind.immunity_head = idx
    return idx
end

@inline function _unlink_overflow!(reg::ImmunityRegistry, ind::Individual, node_idx::Int32)
    prev = Int32(0)
    cur  = ind.immunity_head
    while cur != 0
        @inbounds state = reg.states[cur]
        if cur == node_idx
            if prev == 0
                ind.immunity_head = state.next
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
    get_immunity_state(reg::ImmunityRegistry, ind::Individual, pathogen_id::Int8)::ImmunityState

Lookup in the overflow store only. For the hot path, read `individual.immunity_cache`
directly instead.
"""
function get_immunity_state(reg::ImmunityRegistry, ind::Individual, pathogen_id::Int8)::ImmunityState
    node = ind.immunity_head
    while node != 0
        @inbounds s = reg.states[node]
        s.pathogen_id == pathogen_id && return s
        node = s.next
    end
    return ImmunityState(pathogen_id)
end

"""
    _push_immunity_overflow!(reg::ImmunityRegistry, ind::Individual, pathogen_id::Int8, source::Int8, acquired_tick::Int16, vaccine_id::Int8)

Insert or update an overflow immunity record for `(ind, pathogen_id)`.
Called only when the individual's `immunity_cache` is full.

- Natural: updates `natural_acquired_tick`; vaccine fields unchanged.
- Vaccine: updates `vaccine_acquired_tick` and `vaccine_id`; increments `dose_number`.
"""
function _push_immunity_overflow!(
    reg::ImmunityRegistry,
    ind::Individual,
    pathogen_id::Int8,
    source::Int8,
    acquired_tick::Int16,
    vaccine_id::Int8
)
    # Search existing overflow node
    node = ind.immunity_head
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
    _link_overflow!(reg, ind, new_state)
    return nothing
end

function push_immunity!(
    reg::ImmunityRegistry,
    ind::Individual,
    pathogen_id::Int8,
    source::Int8,
    acquired_tick::Int16,
    vaccine_id::Int8
)
    # Update existing cache entry
    @inbounds for i in 1:IMMUNITY_CACHE_SIZE
        s = ind.immunity_cache[i]
        _is_active_immunity(s) && s.pathogen_id == pathogen_id || continue
        ind.immunity_cache = Base.setindex(ind.immunity_cache,
            source == IMMUNITY_SOURCE_NATURAL ?
                ImmunityState(Int32(0), acquired_tick, s.vaccine_acquired_tick, s.immunity_level, pathogen_id, s.vaccine_id, s.dose_number) :
                ImmunityState(Int32(0), s.natural_acquired_tick, acquired_tick, s.immunity_level, pathogen_id, vaccine_id, s.dose_number + Int8(1)),
            i)
        return nothing
    end

    # Free cache slot
    @inbounds for i in 1:IMMUNITY_CACHE_SIZE
        s = ind.immunity_cache[i]
        _is_active_immunity(s) && continue
        ind.immunity_cache = Base.setindex(ind.immunity_cache,
            source == IMMUNITY_SOURCE_NATURAL ?
                ImmunityState(Int32(0), acquired_tick, DEFAULT_TICK, Int8(0), pathogen_id, DEFAULT_VACCINE_ID, Int8(0)) :
                ImmunityState(Int32(0), DEFAULT_TICK, acquired_tick, Int8(0), pathogen_id, vaccine_id, Int8(1)),
            i)
        return nothing
    end

    # Cache full: overflow
    _push_immunity_overflow!(reg, ind, pathogen_id, source, acquired_tick, vaccine_id)
    return nothing
end

"""
    remove_immunities!(reg::ImmunityRegistry, ind::Individual)

Remove all overflow immunity records for `ind` (called from `reset!`).
"""
function remove_immunities!(reg::ImmunityRegistry, ind::Individual)
    cur = ind.immunity_head
    while cur != 0
        @inbounds nxt = reg.states[cur].next
        push!(reg.free_slots, cur)
        cur = nxt
    end
    ind.immunity_head = Int32(0) 
    return nothing
end