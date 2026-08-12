export CareTimeline, HealthOutcome, HealthContext

"""
    CareTimeline

Isbits value type holding a host's precomputed care timeline: hospital/ICU/ventilation
admission and discharge ticks. Unset ticks are `-1`.

# Constraints
- Each admission requires its discharge and cannot happen after it.
- The care ladder must hold: ICU is gated behind hospital, ventilation behind ICU.
"""
struct CareTimeline
    hospital_admission::Int16
    hospital_discharge::Int16
    icu_admission::Int16
    icu_discharge::Int16
    ventilation_admission::Int16
    ventilation_discharge::Int16

    function CareTimeline(hospital_admission::Int16, hospital_discharge::Int16,
            icu_admission::Int16, icu_discharge::Int16,
            ventilation_admission::Int16, ventilation_discharge::Int16)

        # SANITY CHECKS
        # hospital
        hospital_admission >= 0 && hospital_discharge < 0 && throw(ArgumentError("Hospital admission requires a hospital discharge (hospital_admission: $hospital_admission, hospital_discharge: $hospital_discharge)."))
        hospital_discharge >= 0 && hospital_admission < 0 && throw(ArgumentError("Hospital discharge requires a hospital admission (hospital_admission: $hospital_admission, hospital_discharge: $hospital_discharge)."))
        hospital_discharge >= 0 && hospital_discharge < hospital_admission && throw(ArgumentError("Hospital discharge cannot happen before hospital admission (hospital_admission: $hospital_admission, hospital_discharge: $hospital_discharge)."))
        # ICU (gated behind hospital)
        icu_admission >= 0 && hospital_admission < 0 && throw(ArgumentError("ICU admission requires a hospital admission (hospital_admission: $hospital_admission, icu_admission: $icu_admission)."))
        icu_admission >= 0 && icu_admission < hospital_admission && throw(ArgumentError("ICU admission cannot happen before hospital admission (hospital_admission: $hospital_admission, icu_admission: $icu_admission)."))
        icu_admission >= 0 && icu_discharge < 0 && throw(ArgumentError("ICU admission requires an ICU discharge (icu_admission: $icu_admission, icu_discharge: $icu_discharge)."))
        icu_discharge >= 0 && icu_admission < 0 && throw(ArgumentError("ICU discharge requires an ICU admission (icu_admission: $icu_admission, icu_discharge: $icu_discharge)."))
        icu_discharge >= 0 && icu_discharge < icu_admission && throw(ArgumentError("ICU discharge cannot happen before ICU admission (icu_admission: $icu_admission, icu_discharge: $icu_discharge)."))
        icu_discharge >= 0 && icu_discharge > hospital_discharge && throw(ArgumentError("ICU discharge cannot happen after hospital discharge (icu_discharge: $icu_discharge, hospital_discharge: $hospital_discharge)."))
        # ventilation (gated behind ICU)
        ventilation_admission >= 0 && icu_admission < 0 && throw(ArgumentError("Ventilation admission requires an ICU admission (icu_admission: $icu_admission, ventilation_admission: $ventilation_admission)."))
        ventilation_admission >= 0 && ventilation_admission < icu_admission && throw(ArgumentError("Ventilation admission cannot happen before ICU admission (icu_admission: $icu_admission, ventilation_admission: $ventilation_admission)."))
        ventilation_admission >= 0 && ventilation_discharge < 0 && throw(ArgumentError("Ventilation admission requires a ventilation discharge (ventilation_admission: $ventilation_admission, ventilation_discharge: $ventilation_discharge)."))
        ventilation_discharge >= 0 && ventilation_admission < 0 && throw(ArgumentError("Ventilation discharge requires a ventilation admission (ventilation_admission: $ventilation_admission, ventilation_discharge: $ventilation_discharge)."))
        ventilation_discharge >= 0 && ventilation_discharge < ventilation_admission && throw(ArgumentError("Ventilation discharge cannot happen before ventilation admission (ventilation_admission: $ventilation_admission, ventilation_discharge: $ventilation_discharge)."))
        ventilation_discharge >= 0 && ventilation_discharge > icu_discharge && throw(ArgumentError("Ventilation discharge cannot happen after ICU discharge (ventilation_discharge: $ventilation_discharge, icu_discharge: $icu_discharge)."))

        return new(hospital_admission, hospital_discharge, icu_admission, icu_discharge,
            ventilation_admission, ventilation_discharge)
    end

    @inline function CareTimeline(;
        hospital_admission = Int16(-1),
        hospital_discharge = Int16(-1),
        icu_admission = Int16(-1),
        icu_discharge = Int16(-1),
        ventilation_admission = Int16(-1),
        ventilation_discharge = Int16(-1)
    )
        return CareTimeline(
            Int16(hospital_admission),
            Int16(hospital_discharge),
            Int16(icu_admission),
            Int16(icu_discharge),
            Int16(ventilation_admission),
            Int16(ventilation_discharge)
        )
    end
end

"""
    HealthOutcome

Isbits value type holding a host's precomputed terminal outcome: the death tick and the
pathogen credited for it. Unset `death` is `-1`.
"""
struct HealthOutcome
    death::Int16
    death_pathogen_id::Int8

    @inline function HealthOutcome(; death = Int16(-1), death_pathogen_id = DEFAULT_PATHOGEN_ID)
        return new(Int16(death), Int8(death_pathogen_id))
    end
end

"""
    HealthContext

Isbits value type handed to `calculate_health_progression`, telling the policy what the host is
already committed to so it can plan forward instead of re-deciding the past.

# Fields
- `committed_care::CareTimeline`: current care timeline. Ticks `<= tick` are realized and already
  logged; ticks `> tick` are scheduled and may be revised.
- `committed_outcome::HealthOutcome`: currently scheduled death, if any. Always `> tick` when set.
- `new_infection::InfectionState`: the infection that triggered this recompute.
- `tick::Int16`: the current tick.
"""
struct HealthContext
    committed_care::CareTimeline
    committed_outcome::HealthOutcome
    new_infection::InfectionState
    tick::Int16
end

function Base.show(io::IO, ct::CareTimeline)
    max_val = ct.hospital_discharge
    max_width = max(4, length("$max_val")) # max width of tick column

    spcs(x, max) = length("$x") > max ? "" : repeat(" ", max - length("$x")) * "$x"

    res = "Care Timeline(\n"
    res *= "  $(spcs("tick", max_width)) | event\n"
    res *= ct.hospital_admission >= 0 ?    "  $(spcs(ct.hospital_admission, max_width)) | hospital_admission\n" : ""
    res *= ct.icu_admission >= 0 ?         "  $(spcs(ct.icu_admission, max_width)) | icu_admission\n" : ""
    res *= ct.ventilation_admission >= 0 ? "  $(spcs(ct.ventilation_admission, max_width)) | ventilation_admission\n" : ""
    res *= ct.ventilation_discharge >= 0 ? "  $(spcs(ct.ventilation_discharge, max_width)) | ventilation_discharge\n" : ""
    res *= ct.icu_discharge >= 0 ?         "  $(spcs(ct.icu_discharge, max_width)) | icu_discharge\n" : ""
    res *= ct.hospital_discharge >= 0 ?    "  $(spcs(ct.hospital_discharge, max_width)) | hospital_discharge\n" : ""
    res *= ")"
    print(io, res)
end

function Base.show(io::IO, o::HealthOutcome)
    o.death >= 0 && return print(io, "HealthOutcome(death at tick $(o.death), pathogen $(o.death_pathogen_id))")
    print(io, "HealthOutcome(alive)")
end

"""
    _min_set(a::Int16, b::Int16)

Earliest of two ticks, ignoring the `-1` (unset) sentinel.
"""
@inline _min_set(a::Int16, b::Int16) = a < 0 ? b : (b < 0 ? a : min(a, b))

"""
    _max_set(a::Int16, b::Int16)

Latest of two ticks, ignoring the `-1` (unset) sentinel.
"""
@inline _max_set(a::Int16, b::Int16) = a < 0 ? b : (b < 0 ? a : max(a, b))

"""
    _cap_care(care::CareTimeline, outcome::HealthOutcome)

Reconciliation step: a scheduled `outcome.death` caps any ongoing care interval (normalized,
not rejected). An admission at or after death is dropped entirely; a discharge after death is
pulled back to the death tick.
"""
function _cap_care(care::CareTimeline, outcome::HealthOutcome)
    outcome.death < 0 && return care
    death = outcome.death

    hospital_admission, hospital_discharge = care.hospital_admission, care.hospital_discharge
    icu_admission, icu_discharge = care.icu_admission, care.icu_discharge
    ventilation_admission, ventilation_discharge = care.ventilation_admission, care.ventilation_discharge

    if hospital_admission >= 0 && death <= hospital_admission
        hospital_admission = Int16(-1); hospital_discharge = Int16(-1)
    elseif hospital_discharge >= 0
        hospital_discharge = min(hospital_discharge, death)
    end
    if icu_admission >= 0 && death <= icu_admission
        icu_admission = Int16(-1); icu_discharge = Int16(-1)
    elseif icu_discharge >= 0
        icu_discharge = min(icu_discharge, death)
    end
    if ventilation_admission >= 0 && death <= ventilation_admission
        ventilation_admission = Int16(-1); ventilation_discharge = Int16(-1)
    elseif ventilation_discharge >= 0
        ventilation_discharge = min(ventilation_discharge, death)
    end

    return CareTimeline(hospital_admission, hospital_discharge, icu_admission, icu_discharge,
        ventilation_admission, ventilation_discharge)
end

"""
    _committed_care(individual::Individual)

The host's current care timeline, read off the individual into a `CareTimeline`.
"""
@inline _committed_care(individual::Individual) = CareTimeline(
    individual.hospital_admission, individual.hospital_discharge,
    individual.icu_admission, individual.icu_discharge,
    individual.ventilation_admission, individual.ventilation_discharge)

"""
    _committed_outcome(individual::Individual)

The host's currently scheduled death, read off the individual into a `HealthOutcome`.
"""
@inline _committed_outcome(individual::Individual) =
    HealthOutcome(death = individual.death, death_pathogen_id = individual.killing_pathogen_id)

"""
    _check_plan_tick(level::Symbol, field::Symbol, planned::Int16, committed::Int16, tick::Int16)

Enforces one field of the forward-plan contract: a planned tick must be unset, after `tick`, or
equal to the committed value it replaces (echoing a realized event).
"""
@inline function _check_plan_tick(level::Symbol, field::Symbol, planned::Int16, committed::Int16, tick::Int16)
    (planned < 0 || planned > tick || planned == committed) && return nothing
    throw(ArgumentError("calculate_health_progression returned $(level)_$(field) = $planned at tick $tick: a plan may only schedule events after the current tick, or echo an already-realized one (committed $planned vs $committed). Events at or before the current tick have already been logged and cannot be changed."))
end

"""
    _check_episode(level::Symbol, planned_admission::Int16, planned_discharge::Int16, committed_admission::Int16, committed_discharge::Int16, tick::Int16)

Validates one care level's planned episode: both ticks must satisfy the forward-plan contract, and
an episode still open at `tick` must keep its admission. That admission has already been logged,
and only one episode per level is representable, so dropping it orphans the logged admission and
its discharge is never emitted.
"""
@inline function _check_episode(level::Symbol, planned_admission::Int16, planned_discharge::Int16,
        committed_admission::Int16, committed_discharge::Int16, tick::Int16)
    _check_plan_tick(level, :admission, planned_admission, committed_admission, tick)
    _check_plan_tick(level, :discharge, planned_discharge, committed_discharge, tick)
    (0 <= committed_admission <= tick < committed_discharge) || return nothing
    planned_admission == committed_admission && return nothing
    throw(ArgumentError("calculate_health_progression returned $(level)_admission = $planned_admission at tick $tick while the host is still in that care level (admitted $committed_admission, discharge $committed_discharge). An open episode must keep its admission; its discharge may be moved, but only to a tick after $tick."))
end

"""
    _validate_health_plan(care::CareTimeline, outcome::HealthOutcome, ctx::HealthContext)

Checks a policy's returned plan against the forward-plan contract documented on
`calculate_health_progression`. Throws on a violation rather than clamping, because clamping a
past-anchored event into the present produces care that no infection's clinical course supports
and that the tick's already-completed logging pass can never emit.
"""
function _validate_health_plan(care::CareTimeline, outcome::HealthOutcome, ctx::HealthContext)
    tick = ctx.tick
    c = ctx.committed_care
    _check_episode(:hospital, care.hospital_admission, care.hospital_discharge, c.hospital_admission, c.hospital_discharge, tick)
    _check_episode(:icu, care.icu_admission, care.icu_discharge, c.icu_admission, c.icu_discharge, tick)
    _check_episode(:ventilation, care.ventilation_admission, care.ventilation_discharge, c.ventilation_admission, c.ventilation_discharge, tick)

    outcome.death >= 0 && outcome.death <= tick && throw(ArgumentError(
        "calculate_health_progression returned death = $(outcome.death) at tick $tick: a plan may only schedule a death after the current tick. A death drawn into the past kills the host on the next update instead of at the drawn latency."))
    return nothing
end

"""
    _write_health_timeline!(individual::Individual, care::CareTimeline, outcome::HealthOutcome)

Commits `care` and `outcome` onto the individual, crediting `killing_pathogen_id`.
"""
@inline function _write_health_timeline!(individual::Individual, care::CareTimeline, outcome::HealthOutcome)
    individual.hospital_admission = care.hospital_admission
    individual.hospital_discharge = care.hospital_discharge
    individual.icu_admission = care.icu_admission
    individual.icu_discharge = care.icu_discharge
    individual.ventilation_admission = care.ventilation_admission
    individual.ventilation_discharge = care.ventilation_discharge
    individual.death = outcome.death
    individual.killing_pathogen_id = outcome.death >= 0 ? outcome.death_pathogen_id : DEFAULT_PATHOGEN_ID
    return nothing
end

"""
    compute_health!(individual, infections, hp, new_infection, tick, rng)

Framework wrapper around the `calculate_health_progression` policy: skips the dead, builds the
`HealthContext`, validates the returned plan, caps care at a scheduled death, and commits it onto
the individual.
"""
function compute_health!(individual::Individual, infections::InfectionRegistry,
        hp::HealthProgression, new_infection::InfectionState, tick::Int16, rng::Xoshiro)
    dead(individual) && return nothing
    ctx = HealthContext(_committed_care(individual), _committed_outcome(individual), new_infection, tick)
    care, outcome = calculate_health_progression(individual, infections, hp, ctx, rng)
    _validate_health_plan(care, outcome, ctx)
    care = _cap_care(care, outcome)
    _write_health_timeline!(individual, care, outcome)
    return nothing
end