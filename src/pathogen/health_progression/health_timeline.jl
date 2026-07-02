export CareTimeline, HealthOutcome

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
        # ventilation (gated behind ICU)
        ventilation_admission >= 0 && icu_admission < 0 && throw(ArgumentError("Ventilation admission requires an ICU admission (icu_admission: $icu_admission, ventilation_admission: $ventilation_admission)."))
        ventilation_admission >= 0 && ventilation_admission < icu_admission && throw(ArgumentError("Ventilation admission cannot happen before ICU admission (icu_admission: $icu_admission, ventilation_admission: $ventilation_admission)."))
        ventilation_admission >= 0 && ventilation_discharge < 0 && throw(ArgumentError("Ventilation admission requires a ventilation discharge (ventilation_admission: $ventilation_admission, ventilation_discharge: $ventilation_discharge)."))
        ventilation_discharge >= 0 && ventilation_admission < 0 && throw(ArgumentError("Ventilation discharge requires a ventilation admission (ventilation_admission: $ventilation_admission, ventilation_discharge: $ventilation_discharge)."))
        ventilation_discharge >= 0 && ventilation_discharge < ventilation_admission && throw(ArgumentError("Ventilation discharge cannot happen before ventilation admission (ventilation_admission: $ventilation_admission, ventilation_discharge: $ventilation_discharge)."))

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
    _keep_realized_care(care::CareTimeline, individual::Individual, tick::Int16)

Merges freshly computed `care` with the individual's already-realized care events, so a
recompute never rewrites the past.
"""
@inline function _keep_realized_care(care::CareTimeline, individual::Individual, tick::Int16)
    hospital_admission, hospital_discharge = _resolve(individual.hospital_admission, individual.hospital_discharge, care.hospital_admission, care.hospital_discharge, tick)
    icu_admission, icu_discharge = _resolve(individual.icu_admission, individual.icu_discharge, care.icu_admission, care.icu_discharge, tick)
    ventilation_admission, ventilation_discharge = _resolve(individual.ventilation_admission, individual.ventilation_discharge, care.ventilation_admission, care.ventilation_discharge, tick)
    return CareTimeline(hospital_admission, hospital_discharge, icu_admission, icu_discharge,
        ventilation_admission, ventilation_discharge)
end

"""
    _resolve(realized_admission, realized_discharge, candidate_admission, candidate_discharge, tick)

Keeps a realized (past) admission; otherwise takes the candidate, never starting before `tick`.
"""
@inline function _resolve(realized_admission::Int16, realized_discharge::Int16,
        candidate_admission::Int16, candidate_discharge::Int16, tick::Int16)
    0 <= realized_admission <= tick && return (realized_admission, _max_set(realized_discharge, candidate_discharge))
    (candidate_admission >= 0 && candidate_admission < tick) && return (tick, _max_set(candidate_discharge, Int16(tick + 1)))
    return (candidate_admission, candidate_discharge)
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
    compute_health!(individual, infections, hp, tick, rng)

Framework wrapper around the `calculate_health_progression` policy: skips the dead, caps care
at a scheduled death, preserves already-realized care episodes, and commits the result onto
the individual.
"""
function compute_health!(individual::Individual, infections::InfectionRegistry,
        hp::HealthProgression, tick::Int16, rng::Xoshiro)
    dead(individual) && return nothing
    care, outcome = calculate_health_progression(individual, infections, hp, tick, rng)
    care = _cap_care(care, outcome)
    care = _keep_realized_care(care, individual, tick)
    _write_health_timeline!(individual, care, outcome)
    return nothing
end