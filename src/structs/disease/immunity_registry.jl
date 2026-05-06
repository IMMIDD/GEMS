export ImmunityRegistry, ImmunityState
export push_immunity!, remove_immunity!, get_immunity_state
 
 
"""
    ImmunityState
 
Immutable, bits-type record used for both storage inside `ImmunityRegistry`
and as the public snapshot passed to `ImmunityProfile.calculate_immunity`.
There is no separate row type.
 
One entry per `(individual, pathogen)` combines natural and vaccine immunity
rather than keeping a separate row per acquisition source.
 
Field layout (8 bytes, zero padding):
  2×Int16 (4), 3×Int8 (3), 1 byte alignment padding
 
Fields set to `DEFAULT_TICK` / `DEFAULT_VACCINE_ID` indicate that source is absent.
"""
struct ImmunityState
    natural_acquired_tick::Int16  # DEFAULT_TICK if no natural immunity
    vaccine_acquired_tick::Int16  # DEFAULT_TICK if not vaccinated
    pathogen_id::Int8
    vaccine_id::Int8              # DEFAULT_VACCINE_ID if not vaccinated
    dose_number::Int8             # 0 if not vaccinated
end
 
"""
    ImmunityRegistry
 
Two-level storage for all immunity records in the simulation.
 
- `states::Vector{ImmunityState}`: flat record store. One entry per
  `(individual, pathogen)`. Freed indices go onto `free_slots` for reuse.
- `free_slots::Vector{Int32}`: LIFO stack of reusable indices.
- `slot_to_row::Matrix{Int32}`: `MAX_TRACKED_IMMUNITIES × n_individuals`
  lookup table. `MAX_TRACKED_IMMUNITIES` is 4 — one slot per pathogen.
"""
mutable struct ImmunityRegistry
    states::Vector{ImmunityState}
    free_slots::Vector{Int32}
    slot_to_row::Matrix{Int32}
 
    function ImmunityRegistry(n::Int32; eventual_fraction::Float64 = 0.85)
        states = ImmunityState[]
        sizehint!(states, round(Int, n * eventual_fraction))
        free_slots = Int32[]
        sizehint!(free_slots, 1024)
        return new(states, free_slots, zeros(Int32, MAX_TRACKED_IMMUNITIES, n))
    end
end
 
 
 
# Lookup by pathogen_id only.
@inline function _find_slot_and_row_ir(reg::ImmunityRegistry, host_id::Int32, pathogen_id::Int8)
    @inbounds for s in 1:MAX_TRACKED_IMMUNITIES
        row_idx = reg.slot_to_row[s, host_id]
        row_idx == 0 && continue
        reg.states[row_idx].pathogen_id == pathogen_id && return s, Int(row_idx)
    end
    return 0, 0
end
 
@inline function _find_empty_slot_ir(reg::ImmunityRegistry, host_id::Int32)
    @inbounds for s in 1:MAX_TRACKED_IMMUNITIES
        reg.slot_to_row[s, host_id] == 0 && return s
    end
    return 0
end
 
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
 
@inline function _free_slot_ir!(reg::ImmunityRegistry, host_id::Int32, slot::Int, row_idx::Int) 
    push!(reg.free_slots, Int32(row_idx))
    @inbounds reg.slot_to_row[slot, host_id] = Int32(0)
    return nothing
end
 
@inline _empty_immunity_state(pathogen_id::Int8) = ImmunityState(DEFAULT_TICK, DEFAULT_TICK, pathogen_id, DEFAULT_VACCINE_ID, Int8(0))
 
 
 
"""
    get_immunity_state(registry, host_id, pathogen_id)::ImmunityState
 
Returns the merged natural+vaccine immunity state for `(host_id, pathogen_id)`.
Returns an all-default state if no record exists.
"""
function get_immunity_state(reg::ImmunityRegistry, host_id::Int32, pathogen_id::Int8)::ImmunityState
    _, idx = _find_slot_and_row_ir(reg, host_id, pathogen_id)
    idx == 0 && return _empty_immunity_state(pathogen_id)
    @inbounds return reg.states[idx]
end
 
"""
    push_immunity!(registry, host_id, pathogen_id, source, acquired_tick, vaccine_id)
 
Insert or update the merged immunity record for `(host_id, pathogen_id)`.
 
- Natural immunity: updates `natural_acquired_tick`; vaccine fields are unchanged.
- Vaccine immunity: updates `vaccine_acquired_tick` and `vaccine_id`; increments
  `dose_number`; natural tick is unchanged.
 
If no record exists yet, one is created with defaults for the other source.
Warns and skips if all `MAX_TRACKED_IMMUNITIES` slots are occupied.
"""
function push_immunity!( 
    reg::ImmunityRegistry,
    host_id::Int32,
    pathogen_id::Int8,
    source::Int8,
    acquired_tick::Int16,
    vaccine_id::Int8,
)
    _, idx = _find_slot_and_row_ir(reg, host_id, pathogen_id)
 
    if idx != 0
        # update existing merged entry in-place
        existing = reg.states[idx]
        @inbounds reg.states[idx] = if source == IMMUNITY_SOURCE_NATURAL
            ImmunityState(acquired_tick, existing.vaccine_acquired_tick,
                          pathogen_id, existing.vaccine_id, existing.dose_number)
        else
            ImmunityState(existing.natural_acquired_tick, acquired_tick,
                          pathogen_id, vaccine_id, existing.dose_number + Int8(1))
        end
        return nothing
    end
 
    # first immunity record for this pathogen — initialise with defaults for the other source
    new_state = if source == IMMUNITY_SOURCE_NATURAL
        ImmunityState(acquired_tick, DEFAULT_TICK, pathogen_id, DEFAULT_VACCINE_ID, Int8(0))
    else
        ImmunityState(DEFAULT_TICK, acquired_tick, pathogen_id, vaccine_id, Int8(1))
    end
 
    s = _find_empty_slot_ir(reg, host_id)
    if s == 0
        @warn "Individual $host_id has all $MAX_TRACKED_IMMUNITIES immunity slots filled — skipping pathogen $pathogen_id."
        return nothing
    end
 
    idx = _alloc_state_ir!(reg, new_state)
    @inbounds reg.slot_to_row[s, host_id] = idx
    return nothing
end
 
"""
    remove_immunity!(registry, host_id)
 
Remove all immunity records for `host_id` and return their indices to the free list.
Called only from `reset!`.
"""
function remove_immunity!(reg::ImmunityRegistry, host_id::Int32)
    @inbounds for s in 1:MAX_TRACKED_IMMUNITIES
        row_idx = reg.slot_to_row[s, host_id]
        row_idx == 0 && continue
        _free_slot_ir!(reg, host_id, s, Int(row_idx))
    end
    return nothing
end
