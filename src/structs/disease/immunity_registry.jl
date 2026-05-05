export ImmunityRegistry, ImmunityRow, ImmunityState
export push_immunity!, remove_immunity!, get_immunity_state

"""
    ImmunityState

Stack-allocated, immutable, per-pathogen immunity snapshot passed to
`calculate_immunity`. Combines all sources (natural recovery and vaccination)
for one pathogen into a single struct so the profile has full context.

Fields with value `DEFAULT_TICK` / `DEFAULT_VACCINE_ID` indicate that
source is absent for this individual.
"""
struct ImmunityState
    host_id::Int32
    pathogen_id::Int8
    natural_acquired_tick::Int16   # DEFAULT_TICK if no natural immunity
    vaccine_acquired_tick::Int16   # DEFAULT_TICK if not vaccinated
    vaccine_id::Int8               # DEFAULT_VACCINE_ID if not vaccinated
    dose_number::Int8              # 0 if not vaccinated
end

"""
    ImmunityRow

Immutable, bits-type record for one `(host, pathogen, source)` entry stored
in `ImmunityRegistry`. One row per acquisition source per pathogen.
"""
struct ImmunityRow
    host_id::Int32
    pathogen_id::Int8
    source::Int8
    acquired_tick::Int16
    vaccine_id::Int8
    dose_number::Int8
end

"""
    ImmunityRegistry

Two-level storage for all immunity records in the simulation.

- `rows::Vector{ImmunityRow}`: flat, densely-packed record store.
- `slot_to_row::Matrix{Int32}`: `MAX_TRACKED_IMMUNITIES × n_individuals`
  lookup matrix. `slot_to_row[s, host_id]` is the row index of the
  individual's s-th immunity slot, or 0 if the slot is empty.

One slot per `(pathogen, source)` pair per individual. At most two slots per
pathogen: one for `IMMUNITY_SOURCE_NATURAL` and one for `IMMUNITY_SOURCE_VACCINE`.
`MAX_TRACKED_IMMUNITIES` caps the total number of slots across all pathogens.
"""
mutable struct ImmunityRegistry
    rows::Vector{ImmunityRow}
    slot_to_row::Matrix{Int32}

    function ImmunityRegistry(n::Int32)
        return new(ImmunityRow[], zeros(Int32, MAX_TRACKED_IMMUNITIES, n))
    end
end


@inline function _find_slot_and_row_ir(
        registry::ImmunityRegistry,
        host_id::Int32,
        pathogen_id::Int8,
        source::Int8,
)
    @inbounds for s in 1:MAX_TRACKED_IMMUNITIES
        row_idx = registry.slot_to_row[s, host_id]
        row_idx == 0 && continue
        r = registry.rows[row_idx]
        r.pathogen_id == pathogen_id && r.source == source && return s, Int(row_idx)
    end
    return 0, 0
end

@inline function _find_empty_slot_ir(registry::ImmunityRegistry, host_id::Int32)
    @inbounds for s in 1:MAX_TRACKED_IMMUNITIES
        registry.slot_to_row[s, host_id] == 0 && return s
    end
    return 0
end

"""
Swap-and-pop removal.
"""
@inline function _remove_at_slot_ir!(
        registry::ImmunityRegistry,
        host_id::Int32,
        slot::Int,
        row_idx::Int,
)
    last_idx = length(registry.rows)
    if row_idx != last_idx
        @inbounds last_row = registry.rows[last_idx]
        last_host = last_row.host_id
        @inbounds for ds in 1:MAX_TRACKED_IMMUNITIES
            if registry.slot_to_row[ds, last_host] == last_idx
                registry.slot_to_row[ds, last_host] = Int32(row_idx)
                break
            end
        end
        @inbounds registry.rows[row_idx] = last_row
    end
    pop!(registry.rows)
    @inbounds registry.slot_to_row[slot, host_id] = Int32(0)
    return nothing
end

"""
    _build_immunity_state(host_id, pathogen_id, natural_row, vaccine_row)

Build a combined `ImmunityState` from up to two rows (either may be `nothing`).
"""
@inline function _build_immunity_state(
        host_id::Int32,
        pathogen_id::Int8,
        natural_row::Union{ImmunityRow, Nothing},
        vaccine_row::Union{ImmunityRow, Nothing},
)::ImmunityState
    return ImmunityState(
        host_id,
        pathogen_id,
        isnothing(natural_row) ? DEFAULT_TICK : natural_row.acquired_tick,
        isnothing(vaccine_row) ? DEFAULT_TICK : vaccine_row.acquired_tick,
        isnothing(vaccine_row) ? DEFAULT_VACCINE_ID : vaccine_row.vaccine_id,
        isnothing(vaccine_row) ? Int8(0) : vaccine_row.dose_number,
    )
end

"""
    get_immunity_state(registry, host_id, pathogen_id)::ImmunityState

Return the combined `ImmunityState` for `(host_id, pathogen_id)`, merging
natural and vaccine rows. All absent fields are set to their defaults.
"""
function get_immunity_state(
        registry::ImmunityRegistry,
        host_id::Int32,
        pathogen_id::Int8,
)::ImmunityState
    _, nat_idx = _find_slot_and_row_ir(registry, host_id, pathogen_id, IMMUNITY_SOURCE_NATURAL)
    _, vac_idx = _find_slot_and_row_ir(registry, host_id, pathogen_id, IMMUNITY_SOURCE_VACCINE)
    nat_row = nat_idx == 0 ? nothing : registry.rows[nat_idx]
    vac_row = vac_idx == 0 ? nothing : registry.rows[vac_idx]
    return _build_immunity_state(host_id, pathogen_id, nat_row, vac_row)
end

"""
    push_immunity!(registry, host_id, pathogen_id, source, acquired_tick, vaccine_id)

Insert or overwrite the `(host_id, pathogen_id, source)` immunity record.
Dose number is tracked internally: incremented on each vaccine overwrite,
always 0 for natural immunity.
Emits a warning and skips if all `MAX_TRACKED_IMMUNITIES` slots are full.
"""
function push_immunity!(
        registry::ImmunityRegistry,
        host_id::Int32,
        pathogen_id::Int8,
        source::Int8,
        acquired_tick::Int16,
        vaccine_id::Int8,
)
    s, existing_idx = _find_slot_and_row_ir(registry, host_id, pathogen_id, source)

    dose = source == IMMUNITY_SOURCE_VACCINE ?
        (s != 0 ? registry.rows[existing_idx].dose_number + Int8(1) : Int8(1)) : Int8(0)

    row = ImmunityRow(host_id, pathogen_id, source, acquired_tick, vaccine_id, dose)

    if s != 0
        @inbounds registry.rows[existing_idx] = row
        return nothing
    end

    s = _find_empty_slot_ir(registry, host_id)
    if s == 0
        @warn "Individual $host_id has all $MAX_TRACKED_IMMUNITIES immunity " *
              "slots filled — skipping immunity record for pathogen $pathogen_id."
        return nothing
    end

    push!(registry.rows, row)
    @inbounds registry.slot_to_row[s, host_id] = Int32(length(registry.rows))
    return nothing
end

"""
    remove_immunity!(registry, host_id, pathogen_id, source)

Remove the `(host_id, pathogen_id, source)` record. No-op if absent.
"""
function remove_immunity!(
        registry::ImmunityRegistry,
        host_id::Int32,
        pathogen_id::Int8,
        source::Int8,
)
    s, row_idx = _find_slot_and_row_ir(registry, host_id, pathogen_id, source)
    s == 0 && return nothing
    _remove_at_slot_ir!(registry, host_id, s, row_idx)
    return nothing
end

"""
    remove_immunity!(registry, host_id)

Remove all immunity records for the given host (used during `reset!`).
"""
function remove_immunity!(registry::ImmunityRegistry, host_id::Int32)
    @inbounds for s in 1:MAX_TRACKED_IMMUNITIES
        row_idx = registry.slot_to_row[s, host_id]
        row_idx == 0 && continue
        _remove_at_slot_ir!(registry, host_id, s, Int(row_idx))
    end
    return nothing
end