export InfectionRegistry, InfectionState, PendingInfection
export get_infection_state, push_infection!, remove_infection!, find_infection_index
 
 
"""
    InfectionState
 
Immutable, bits-type record used for both storage inside `InfectionRegistry`
and as the public snapshot passed to `InfectiousnessProfile.calculate_infectiousness`.
There is no separate row type.
 
`active = false` signals that no record was found (returned by `get_infection_state`
when the index is 0). All tick fields default to `Int16(-1)` in that case.
 
Field layout (32 bytes, zero padding):
  infection_id::Int32 (4), 13×Int16 (26), pathogen_id::Int8 (1), active::Bool (1)
"""
struct InfectionState
    infection_id::Int32
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
    pathogen_id::Int8
    active::Bool
end
 
"""
    InfectionRegistry
 
Two-level storage for all active infections in the simulation.
 
- `states::Vector{InfectionState}`: flat record store. Indices are stable across
  the lifetime of an infection — freed indices go onto `free_slots` and are
  reclaimed by the next insertion, so the vector never grows beyond its peak size.
- `free_slots::Vector{Int32}`: LIFO stack of reusable indices.
- `slot_to_row::Matrix{Int32}`: `MAX_CONCURRENT_INFECTIONS × n_individuals`
  lookup table. A zero entry means the slot is unoccupied.
"""
mutable struct InfectionRegistry
    states::Vector{InfectionState}
    free_slots::Vector{Int32}
    slot_to_row::Matrix{Int32}
 
    function InfectionRegistry(n::Int32; concurrent_fraction::Float64 = 0.5) 
        states = InfectionState[]
        sizehint!(states, round(Int, n * concurrent_fraction))
        free_slots = Int32[]
        sizehint!(free_slots, round(Int, n * concurrent_fraction))
        return new(states, free_slots, zeros(Int32, MAX_CONCURRENT_INFECTIONS, n))
    end
end
 
 
"""
    PendingInfection

Per-thread transfer struct staged in `infection_buffers` during the threaded
contact phase, then drained into `InfectionRegistry` by `flush_pending_infections!`.
"""
struct PendingInfection
    host_id::Int32
    infection_id::Int32
    pathogen_id::Int8
    dp::DiseaseProgression
end

 
@inline function _find_slot_and_row(reg::InfectionRegistry, host_id::Int32, pathogen_id::Int8)
    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        row_idx = reg.slot_to_row[s, host_id]
        row_idx == 0 && continue
        reg.states[row_idx].pathogen_id == pathogen_id && return s, Int(row_idx)
    end
    return 0, 0
end
 
@inline function _find_empty_slot(reg::InfectionRegistry, host_id::Int32)
    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        reg.slot_to_row[s, host_id] == 0 && return s
    end
    return 0
end
 
"""
    _state_from_pending(pathogen_id, infection_id, dp)::InfectionState
 
Build an `InfectionState` from a pending infection.
"""
@inline function _state_from_pending(pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)::InfectionState
    return InfectionState(
        infection_id,
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
        pathogen_id,
        true
    )
end
 
@inline function _empty_infection_state()::InfectionState
    return InfectionState(
        Int32(0),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int8(0),
        false,
    )
end
 
"""
    _setstate(state, ::Val{name}, value)::InfectionState
 
Return a copy of `state` with field `name` replaced by `value`.
Used by the disease-history tick-setter functions.
"""
@inline @generated function _setstate(state::InfectionState, ::Val{name}, value) where {name}
    fields = fieldnames(InfectionState)
    args = Expr[field === name ? :value : :(getfield(state, $(QuoteNode(field)))) for field in fields]
    return :(InfectionState($(args...)))
end
 
"""
    _alloc_state!(reg, state)::Int32
 
Write `state` to the next free index (from `free_slots` if available, otherwise
appends to `states`). Returns the index used.
"""
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
    _free_slot!(reg, host_id, slot, row_idx)
 
Clear `slot_to_row[slot, host_id]` and push `row_idx` onto `free_slots` so the
index can be reused by the next insertion.
"""
@inline function _free_slot!(reg::InfectionRegistry, host_id::Int32, slot::Int32, row_idx::Int32) 
    push!(reg.free_slots, row_idx)
    @inbounds reg.slot_to_row[slot, host_id] = Int32(0)
    return nothing
end
 
 
 
"""
    find_infection_index(infections, host_id, pathogen_id)::Int
 
Return the index in `infections.states` for `(host_id, pathogen_id)`, or 0 if absent.
"""
@inline function find_infection_index(reg::InfectionRegistry, host_id::Int32, pathogen_id::Int8)::Int
    _, idx = _find_slot_and_row(reg, host_id, pathogen_id)
    return idx
end

 
"""
    get_infection_state(infections, idx)::InfectionState
 
Direct index lookup. Returns the inactive sentinel state when `idx == 0`.
"""
@inline function get_infection_state(reg::InfectionRegistry, idx::Int32)::InfectionState
    idx == 0 && return _empty_infection_state()
    @inbounds return reg.states[idx]
end
 
 
"""
    get_infection_state(host_id, infections, pathogen_id)::InfectionState
 
Lookup by `(host_id, pathogen_id)`. Returns the inactive sentinel state if absent.
"""
function get_infection_state(host_id::Int32, reg::InfectionRegistry, pathogen_id::Int8)::InfectionState
    idx = find_infection_index(reg, host_id, pathogen_id)
    return get_infection_state(reg, Int32(idx))
end
 
"""
    push_infection!(infections, host_id, pathogen_id, infection_id, dp)
 
Insert a new infection record. No-op if a record for this pathogen already exists.
Warns and skips if all `MAX_CONCURRENT_INFECTIONS` slots are occupied.
"""
function push_infection!(reg::InfectionRegistry, host_id::Int32, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)
    existing_s, _ = _find_slot_and_row(reg, host_id, pathogen_id)
    existing_s != 0 && return nothing
 
    s = _find_empty_slot(reg, host_id)
    if s == 0
        @warn "Individual $host_id has all $MAX_CONCURRENT_INFECTIONS infection slots filled — skipping pathogen $pathogen_id."
        return nothing
    end
 
    idx = _alloc_state!(reg, _state_from_pending(pathogen_id, infection_id, dp))
    @inbounds reg.slot_to_row[s, host_id] = idx
    return nothing
end
 
"""
    remove_infection!(infections, host_id, pathogen_id)
 
Remove the `(host_id, pathogen_id)` record and return its index to the free list.
"""
function remove_infection!(reg::InfectionRegistry, host_id::Int32, pathogen_id::Int8)
    s, row_idx = _find_slot_and_row(reg, host_id, pathogen_id)
    s == 0 && return nothing
    _free_slot!(reg, host_id, Int32(s), Int32(row_idx))
    return nothing
end
 
"""
    remove_infection!(infections, host_id)
 
Remove every infection record for `host_id` (called from `reset!`).
"""
function remove_infection!(reg::InfectionRegistry, host_id::Int32)
    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        row_idx = reg.slot_to_row[s, host_id]
        row_idx == 0 && continue
        _free_slot!(reg, host_id, Int32(s), Int32(row_idx))
    end
    return nothing
end
