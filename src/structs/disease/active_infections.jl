export ActiveInfections, InfectionRow, InfectionState, PendingInfection
export get_infection_state, push_infection!, remove_infection!, find_infection_index

"""
    InfectionRow

Immutable, bits-type record for one active (host, pathogen) infection.
"""
struct InfectionRow
    host_id::Int32
    pathogen_id::Int8
    infection_id::Int32

    # Natural disease history
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
end

"""
    ActiveInfections

Two-level storage for all active infections in the simulation.
"""
mutable struct ActiveInfections
    rows::Vector{InfectionRow}
    slot_to_row::Matrix{Int32} 

    function ActiveInfections(n::Int32)
        return new(InfectionRow[], zeros(Int32, MAX_CONCURRENT_INFECTIONS, n))
    end
end

"""
    InfectionState

Public, stack-allocated snapshot of an individual's disease state for one
pathogen.
"""
struct InfectionState
    active::Bool
    host_id::Int32
    pathogen_id::Int8
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
end

"""
    PendingInfection

Per-thread transfer struct staged in `infection_buffers` during the threaded
contact phase, then drained into `ActiveInfections` by `flush_pending_infections!`.
"""
struct PendingInfection
    host_id::Int32
    pathogen_id::Int8
    infection_id::Int32
    dp::DiseaseProgression
end




"""
    _find_slot_and_row(infections, host_id, pathogen_id)::(slot, row_idx)

Returns the lookup-table slot and the row index for the given`(host_id, pathogen_id)` pair, 
or `(0, 0)` if the host has no record for this pathogen.
"""
@inline function _find_slot_and_row(infections::ActiveInfections, host_id::Int32, pathogen_id::Int8)
    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        row_idx = infections.slot_to_row[s, host_id]
        row_idx == 0 && continue
        if infections.rows[row_idx].pathogen_id == pathogen_id
            return s, Int(row_idx)
        end
    end
    return 0, 0
end

"""
    _find_empty_slot(infections, host_id)::slot

First slot index in `slot_to_row[:, host_id]` whose entry is 0, or 0 if all `MAX_CONCURRENT_INFECTIONS` slots are occupied.
"""
@inline function _find_empty_slot(infections::ActiveInfections, host_id::Int32)
    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        if infections.slot_to_row[s, host_id] == 0
            return s
        end
    end
    return 0
end

"""
    _row_from_pending(host_id, pathogen_id, infection_id, dp)::InfectionRow

Build a new `InfectionRow` from the pending-infection inputs.
"""
@inline function _row_from_pending(host_id::Int32, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)::InfectionRow
    return InfectionRow(
        host_id,
        pathogen_id,
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
    )
end

"""
    _row_to_state(row::InfectionRow)::InfectionState

Convert a stored row into the public snapshot type. `active` is true because rows only exist for live records; the empty case is handled separately by `_empty_state`.
"""
@inline function _row_to_state(row::InfectionRow)::InfectionState
    return InfectionState(
        true,
        row.host_id,
        row.pathogen_id,
        row.infection_id,
        row.exposure,
        row.infectiousness_onset,
        row.symptom_onset,
        row.severeness_onset,
        row.hospital_admission,
        row.icu_admission,
        row.icu_discharge,
        row.ventilation_admission,
        row.ventilation_discharge,
        row.hospital_discharge,
        row.severeness_offset,
        row.recovery,
        row.death,
    )
end

@inline function _empty_state(host_id::Int32)::InfectionState
    return InfectionState(
        false, host_id, Int8(0), Int32(0),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), Int16(-1), Int16(-1),
    )
end

"""
    _setrow(row, ::Val{name}, value)::InfectionRow

Return a copy of `row` with field `name` replaced by `value`.
"""
@inline @generated function _setrow(row::InfectionRow, ::Val{name}, value) where {name}
    fields = fieldnames(InfectionRow)
    args = Expr[ field === name ? :value : :(getfield(row, $(QuoteNode(field)))) for field in fields ]
    return :(InfectionRow($(args...)))
end

"""
    _remove_at_slot!(infections, host_id, slot, row_idx)

Internal swap-and-pop removal. The row currently at `row_idx` is removed by moving the last row of `rows` into its place (if it isn't already last) and popping. 
"""
@inline function _remove_at_slot!(infections::ActiveInfections, host_id::Int32, slot::Int32, row_idx::Int32)
    last_idx = length(infections.rows)

    if row_idx != last_idx
        @inbounds last_row = infections.rows[last_idx]
        last_host = last_row.host_id

        @inbounds for ds in 1:MAX_CONCURRENT_INFECTIONS
            if infections.slot_to_row[ds, last_host] == last_idx
                infections.slot_to_row[ds, last_host] = Int32(row_idx)
                break
            end
        end
        @inbounds infections.rows[row_idx] = last_row
    end

    pop!(infections.rows)
    @inbounds infections.slot_to_row[slot, host_id] = Int32(0)
    return nothing
end



"""
    find_infection_index(infections::ActiveInfections, host_id, pathogen_id)::Int

Return the row index in `infections.rows` for the given `(host_id, pathogen_id)`, or `0` if no such record exists.
"""
@inline function find_infection_index(infections::ActiveInfections, host_id::Int32, pathogen_id::Int8)::Int
    _, idx = _find_slot_and_row(infections, host_id, pathogen_id)
    return idx
end

"""
    get_infection_state(infections::ActiveInfections, idx::Int32, host_id::Int32)::InfectionState

Build an `InfectionState` from a known row index. `idx == 0` returns the empty (uninfected) state.
"""
function get_infection_state(infections::ActiveInfections, idx::Int32, host_id::Int32)::InfectionState
    idx == 0 && return _empty_state(host_id)
    @inbounds return _row_to_state(infections.rows[idx])
end

"""
    get_infection_state(host_id::Int32, infections::ActiveInfections, pathogen_id::Int8)::InfectionState

Look up `InfectionState` for `(host_id, pathogen_id)`. Returns the empty state if the host has no record for that pathogen.
"""
function get_infection_state(host_id::Int32, infections::ActiveInfections, pathogen_id::Int8)::InfectionState
    idx = find_infection_index(infections, host_id, pathogen_id)
    idx == 0 && return _empty_state(host_id)
    @inbounds return _row_to_state(infections.rows[idx])
end



"""
    push_infection!(infections, host_id, pathogen_id, infection_id, dp)

Insert a new infection record for `(host_id, pathogen_id)`.
"""
function push_infection!(infections::ActiveInfections, host_id::Int32, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)
    existing_s, _ = _find_slot_and_row(infections, host_id, pathogen_id)
    if existing_s != 0
        return nothing 
    end

    s = _find_empty_slot(infections, host_id)
    if s == 0
        @warn "Individual $host_id has all $MAX_CONCURRENT_INFECTIONS concurrent infection slots filled — skipping new infection with pathogen $pathogen_id."
        return nothing
    end

    push!(infections.rows, _row_from_pending(host_id, pathogen_id, infection_id, dp))
    @inbounds infections.slot_to_row[s, host_id] = Int32(length(infections.rows))
    return nothing
end

"""
    remove_infection!(infections, host_id, pathogen_id)

Remove the (host_id, pathogen_id) record.
"""
function remove_infection!(infections::ActiveInfections, host_id::Int32, pathogen_id::Int8)
    s, row_idx = _find_slot_and_row(infections, host_id, pathogen_id)
    s == 0 && return nothing
    return _remove_at_slot!(infections, host_id, s, row_idx)
end

"""
    remove_infection!(infections, host_id)

Remove every record for the given host.
"""
function remove_infection!(infections::ActiveInfections, host_id::Int32)
    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        row_idx = infections.slot_to_row[s, host_id]
        row_idx == 0 && continue
        _remove_at_slot!(infections, host_id, s, Int(row_idx))
    end
    return nothing
end