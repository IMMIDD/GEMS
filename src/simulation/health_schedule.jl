###
### HEALTH SCHEDULE
###
### Tick-keyed store of pending host care transitions, drained each tick onto the per-level demand
### counters on the individual, plus the ticks the simulation must not fast-forward past.
###

"""
    CareTransition

One host entering or leaving one care level.
"""
struct CareTransition
    host_id::Int32
    level::CareLevel
    is_admission::Bool
end

"""
    HealthSchedule <: AbstractHealthSchedule

Per-shard store of pending care transitions and of ticks that must stay awake.

- `buckets`: transitions due at each tick — work the drain performs.
- `wake_ticks`: ticks with no work here that the simulation must still not fast-forward past. A
  scheduled death registers one, because it is realized by `progress_disease!` inside the individual
  loop, which a dormant tick skips.
- `buffer`: reused buffer a policy contributes into.
- `admitted`: hosts admitted to hospital by the current drain, for the trigger phase.
- `head`: lowest tick not yet drained.
"""
mutable struct HealthSchedule <: AbstractHealthSchedule
    buckets::Dict{Int16, Vector{CareTransition}}
    wake_ticks::Set{Int16}
    buffer::Vector{CareContribution}
    admitted::Vector{Int32}
    head::Int
end

"""
    HealthSchedule()

Builds an empty `HealthSchedule`.
"""
HealthSchedule() = HealthSchedule(
    Dict{Int16, Vector{CareTransition}}(),
    Set{Int16}(),
    CareContribution[],
    Int32[],
    0
)

"""
    due_now(schedule::HealthSchedule, tick::Int16)

`true` if there is work in this tick's bucket, or a reason to be awake for it anyway.

Must stay a due-now test: an "anything outstanding" one would hold the simulation awake for every tick
up to the last scheduled event. Because it only ever asks about the current tick, a `wake_ticks` entry
left behind after its tick has passed is inert.
"""
@inline due_now(schedule::HealthSchedule, tick::Int16) =
    haskey(schedule.buckets, tick) || (tick in schedule.wake_ticks)

"""
    schedule!(schedule::HealthSchedule, host_id::Int32, level::CareLevel, is_admission::Bool, tick::Int16)

Files one care transition for `tick`.
"""
@inline function schedule!(schedule::HealthSchedule, host_id::Int32, level::CareLevel,
        is_admission::Bool, tick::Int16)
    bucket = get!(() -> CareTransition[], schedule.buckets, tick)
    push!(bucket, CareTransition(host_id, level, is_admission))
    return nothing
end

"""
    wake_at!(schedule::HealthSchedule, tick::Int16)

Registers `tick` as one the simulation must stay awake for.

An index over `individual.death`, which stays authoritative; `compute_health!` is the only writer.
"""
@inline function wake_at!(schedule::HealthSchedule, tick::Int16)
    tick >= 0 && push!(schedule.wake_ticks, tick)
    return nothing
end

"""
    _emit_level!(schedule::HealthSchedule, host_id::Int32, level::CareLevel, admission::Int16, discharge::Int16)

Files one care level's admission/discharge pair, or nothing if the level is unset.
"""
@inline function _emit_level!(schedule::HealthSchedule, host_id::Int32, level::CareLevel,
        admission::Int16, discharge::Int16)
    admission < 0 && return nothing
    schedule!(schedule, host_id, level, true, admission)
    schedule!(schedule, host_id, level, false, discharge)
    return nothing
end

"""
    _emit_contribution!(schedule::HealthSchedule, host_id::Int32, care::CareContribution)

Expands one contribution into up to six transitions.

The care ladder needs no cross-level check: each contribution nests, and a union of nested intervals
is nested.
"""
@inline function _emit_contribution!(schedule::HealthSchedule, host_id::Int32, care::CareContribution)
    _emit_level!(schedule, host_id, CARE_HOSPITAL, care.hospital_admission, care.hospital_discharge)
    _emit_level!(schedule, host_id, CARE_ICU, care.icu_admission, care.icu_discharge)
    _emit_level!(schedule, host_id, CARE_VENTILATION, care.ventilation_admission, care.ventilation_discharge)
    return nothing
end

"""
    reset_care!(schedule::HealthSchedule)

Clears every pending transition and wake tick. Only safe alongside clearing the hosts' demand
counters; see `reset!(::Simulation)`.
"""
function reset_care!(schedule::HealthSchedule)
    empty!(schedule.buckets)
    empty!(schedule.wake_ticks)
    empty!(schedule.buffer)
    empty!(schedule.admitted)
    schedule.head = 0
    return nothing
end

