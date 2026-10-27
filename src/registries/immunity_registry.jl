export ImmunityRegistry, ImmunityState
export natural_immunity_recorded, vaccine_immunity_recorded
export natural_immunity_active, vaccine_immunity_active
export natural_immunity_pending, vaccine_immunity_pending
export immunity_active, previous_dose_interval


"""
    ImmunityState

Immutable, bits-type record used for both storage in `ImmunityRegistry` (overflow)
and as the on-individual cache (`immunity_cache`) and the public snapshot passed to
`ImmunityProfile.calculate_immunity`.

One entry per `(individual, pathogen)` — combines natural and vaccine immunity.
`next::Int32` chains overflow nodes; always 0 for cache states.
Holds no level; levels are computed on read, see `immunity_level`.

An entry is considered inactive when `pathogen_id == DEFAULT_PATHOGEN_ID`.
"""
struct ImmunityState
    next::Int32
    natural_acquired_tick::Int16  # NO_IMMUNITY_TICK if no natural immunity
    vaccine_acquired_tick::Int16  # NO_IMMUNITY_TICK if not vaccinated
    pathogen_id::Int8             # DEFAULT_PATHOGEN_ID signals an empty slot
    vaccine_id::Int8              # DEFAULT_VACCINE_ID if not vaccinated
    dose_number::Int8             # 0 if not vaccinated
    prev_dose_interval::UInt8     # ticks since the previous dose, log-encoded; 0 if none

    ImmunityState(next::Int32, natural_acquired_tick::Int16, vaccine_acquired_tick::Int16, pathogen_id::Int8,
        vaccine_id::Int8, dose_number::Int8, prev_dose_interval::UInt8) =
        new(next, natural_acquired_tick, vaccine_acquired_tick, pathogen_id, vaccine_id, dose_number, prev_dose_interval)
end

"""
    ImmunityState(next, natural_acquired_tick, vaccine_acquired_tick, pathogen_id, vaccine_id, dose_number[, prev_dose_interval::UInt8])

Converting constructor; without `prev_dose_interval` the state has no previous dose.
"""
ImmunityState(next::Integer, natural_acquired_tick::Integer, vaccine_acquired_tick::Integer, pathogen_id::Integer,
        vaccine_id::Integer, dose_number::Integer, prev_dose_interval::UInt8 = 0x00) =
    ImmunityState(Int32(next), Int16(natural_acquired_tick), Int16(vaccine_acquired_tick), Int8(pathogen_id),
        Int8(vaccine_id), Int8(dose_number), prev_dose_interval)

"""
    ImmunityState(next, natural_acquired_tick, vaccine_acquired_tick, immunity_level, pathogen_id, vaccine_id, dose_number)

Deprecated; `immunity_level` is ignored and `DEFAULT_TICK` ticks are read as `NO_IMMUNITY_TICK`.
"""
function ImmunityState(next::Integer, natural_acquired_tick::Integer, vaccine_acquired_tick::Integer, ::Integer,
        pathogen_id::Integer, vaccine_id::Integer, dose_number::Integer)
    Base.depwarn("ImmunityState no longer stores a level; drop the fourth argument.", :ImmunityState)
    # old callers marked a missing source with DEFAULT_TICK
    _no_record(t) = t == DEFAULT_TICK ? NO_IMMUNITY_TICK : t
    return ImmunityState(next, _no_record(natural_acquired_tick), _no_record(vaccine_acquired_tick), pathogen_id, vaccine_id, dose_number)
end

"""
    ImmunityState()

Constructs an empty/inactive `ImmunityState` sentinel.
Used for initializing caches and representing unassigned immunity slots.
"""
function ImmunityState()::ImmunityState
    return ImmunityState(Int32(0), NO_IMMUNITY_TICK, NO_IMMUNITY_TICK, DEFAULT_PATHOGEN_ID, DEFAULT_VACCINE_ID, Int8(0))
end

"""
    ImmunityState(pathogen_id::Int8)

Constructs an empty `ImmunityState` reserved for a specific pathogen.
Used as a safe return value when querying immunity for a pathogen the individual has no record of.
"""
function ImmunityState(pathogen_id::Int8)::ImmunityState
    return ImmunityState(Int32(0), NO_IMMUNITY_TICK, NO_IMMUNITY_TICK, pathogen_id, DEFAULT_VACCINE_ID, Int8(0))
end



"""
    natural_immunity_recorded(s::ImmunityState)::Bool

`true` if a natural (post-recovery) immunity record exists, regardless of whether its
acquired tick has been reached yet.
"""
@inline natural_immunity_recorded(s::ImmunityState)::Bool = s.natural_acquired_tick != NO_IMMUNITY_TICK

"""
    vaccine_immunity_recorded(s::ImmunityState)::Bool

`true` if a vaccine immunity record exists, regardless of whether its acquired tick has
been reached yet.
"""
@inline vaccine_immunity_recorded(s::ImmunityState)::Bool = s.vaccine_acquired_tick != NO_IMMUNITY_TICK

"""
    natural_immunity_active(s::ImmunityState, tick::Int16)::Bool

`true` if natural immunity is recorded and its acquired (recovery) tick is at or before
`tick`, i.e. the individual has recovered from a natural infection by `tick`.
"""
@inline natural_immunity_active(s::ImmunityState, tick::Int16)::Bool =
    s.natural_acquired_tick != NO_IMMUNITY_TICK && tick >= s.natural_acquired_tick

"""
    vaccine_immunity_active(s::ImmunityState, tick::Int16)::Bool

`true` if vaccine immunity is recorded and its acquired tick is at or before `tick`.
"""
@inline vaccine_immunity_active(s::ImmunityState, tick::Int16)::Bool =
    s.vaccine_acquired_tick != NO_IMMUNITY_TICK && tick >= s.vaccine_acquired_tick

"""
    natural_immunity_pending(s::ImmunityState, tick::Int16)::Bool

`true` if natural immunity is recorded but its acquired tick lies strictly after `tick`.
"""
@inline natural_immunity_pending(s::ImmunityState, tick::Int16)::Bool =
    s.natural_acquired_tick != NO_IMMUNITY_TICK && tick < s.natural_acquired_tick

"""
    vaccine_immunity_pending(s::ImmunityState, tick::Int16)::Bool

`true` if vaccine immunity is recorded but its acquired tick lies strictly after `tick`.
"""
@inline vaccine_immunity_pending(s::ImmunityState, tick::Int16)::Bool =
    s.vaccine_acquired_tick != NO_IMMUNITY_TICK && tick < s.vaccine_acquired_tick

"""
    immunity_active(s::ImmunityState, tick::Int16)::Bool

`true` if either natural or vaccine immunity is active at `tick`.
"""
@inline immunity_active(s::ImmunityState, tick::Int16)::Bool =
    natural_immunity_active(s, tick) || vaccine_immunity_active(s, tick)

# encodes `e` ticks as 1 + round(16 log2(1 + e)) (~4% resolution); 0 for no or an unusable interval
@inline function _encode_dose_interval(e::Integer)::UInt8
    0 <= e <= typemax(Int16) || return 0x00
    return UInt8(1 + round(Int, 16 * log2(1 + e)))
end

"""
    previous_dose_interval(s::ImmunityState)::Int16

Ticks from the previous vaccine dose to the current one (rounded to ~4%), or `NO_IMMUNITY_TICK` if there is none.
"""
@inline function previous_dose_interval(s::ImmunityState)::Int16
    s.prev_dose_interval == 0x00 && return NO_IMMUNITY_TICK
    return Int16(min(round(Int, exp2((s.prev_dose_interval - 1) / 16) - 1), typemax(Int16)))
end

# the encoded interval a new dose at `tick` has since the dose recorded in `s`
@inline _dose_interval_since(s::ImmunityState, tick::Int16)::UInt8 =
    vaccine_immunity_recorded(s) ? _encode_dose_interval(Int(tick) - Int(s.vaccine_acquired_tick)) : 0x00

"""
    ImmunityRegistry

Overflow store for immunity records that exceed `IMMUNITY_CACHE_SIZE` per individual.
For single-pathogen simulations this is never populated.

- `states::Vector{ImmunityState}`: record store; freed indices are recycled.
- `free_slots::Vector{Int32}`: LIFO stack of reusable indices.
"""
struct ImmunityRegistry
    states::Vector{ImmunityState}
    free_slots::Vector{Int32}

    function ImmunityRegistry(n::Int32, num_shards::Int = 1; overflow_fraction::Float64 = 0.0)
        states = ImmunityState[]
        capacity = max(1, round(Int, (n * overflow_fraction) / num_shards))
        sizehint!(states, capacity)
        free_slots = Int32[]
        sizehint!(free_slots, capacity)
        return new(states, free_slots)
    end

    ImmunityRegistry() = new(ImmunityState[], Int32[])
end

