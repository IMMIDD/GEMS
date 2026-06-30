export HealthTimeline

"""
    HealthTimeline

Isbits value type holding a host's precomputed care timeline: hospital/ICU/ventilation
admission and discharge ticks, the host death tick, and the pathogen credited for that death.
Returned by `calculate_health_progression`. Unset ticks are `-1`.

# Constraints
- A scheduled `death` caps any ongoing care interval (normalized, not rejected).
- Each admission requires its discharge and cannot happen after it.
- The care ladder must hold: ICU is gated behind hospital, ventilation behind ICU.
"""
struct HealthTimeline
    hospital_admission::Int16
    hospital_discharge::Int16
    icu_admission::Int16
    icu_discharge::Int16
    ventilation_admission::Int16
    ventilation_discharge::Int16
    death::Int16
    death_pathogen_id::Int8

    function HealthTimeline(hospital_admission::Int16, hospital_discharge::Int16,
            icu_admission::Int16, icu_discharge::Int16,
            ventilation_admission::Int16, ventilation_discharge::Int16,
            death::Int16, death_pathogen_id::Int8)
        # a scheduled death caps any ongoing care interval
        if death >= 0
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
        end

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
            ventilation_admission, ventilation_discharge, death, death_pathogen_id)
    end

    @inline function HealthTimeline(;
        hospital_admission = Int16(-1),
        hospital_discharge = Int16(-1),
        icu_admission = Int16(-1),
        icu_discharge = Int16(-1),
        ventilation_admission = Int16(-1),
        ventilation_discharge = Int16(-1),
        death = Int16(-1),
        death_pathogen_id = DEFAULT_PATHOGEN_ID
    )
        return HealthTimeline(
            Int16(hospital_admission),
            Int16(hospital_discharge),
            Int16(icu_admission),
            Int16(icu_discharge),
            Int16(ventilation_admission),
            Int16(ventilation_discharge),
            Int16(death),
            Int8(death_pathogen_id)
        )
    end
end

function Base.show(io::IO, tl::HealthTimeline)
    max_val = max(tl.hospital_discharge, tl.death)
    max_width = max(4, length("$max_val")) # max width of tick column

    spcs(x, max) = length("$x") > max ? "" : repeat(" ", max - length("$x")) * "$x"

    res = "Health Timeline(\n"
    res *= "  $(spcs("tick", max_width)) | event\n"
    res *= tl.hospital_admission >= 0 ?    "  $(spcs(tl.hospital_admission, max_width)) | hospital_admission\n" : ""
    res *= tl.icu_admission >= 0 ?         "  $(spcs(tl.icu_admission, max_width)) | icu_admission\n" : ""
    res *= tl.ventilation_admission >= 0 ? "  $(spcs(tl.ventilation_admission, max_width)) | ventilation_admission\n" : ""
    res *= tl.ventilation_discharge >= 0 ? "  $(spcs(tl.ventilation_discharge, max_width)) | ventilation_discharge\n" : ""
    res *= tl.icu_discharge >= 0 ?         "  $(spcs(tl.icu_discharge, max_width)) | icu_discharge\n" : ""
    res *= tl.hospital_discharge >= 0 ?    "  $(spcs(tl.hospital_discharge, max_width)) | hospital_discharge\n" : ""
    res *= tl.death >= 0 ?                 "  $(spcs(tl.death, max_width)) | death\n" : ""
    res *= ")"
    print(io, res)
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
    _keep_realized(timeline::HealthTimeline, individual::Individual, tick::Int16)

Merges the freshly computed `timeline` with the individual's already-realized care events,
so a recompute never rewrites the past.
"""
@inline function _keep_realized(timeline::HealthTimeline, individual::Individual, tick::Int16)
    hospital_admission, hospital_discharge = _resolve(individual.hospital_admission, individual.hospital_discharge, timeline.hospital_admission, timeline.hospital_discharge, tick)
    icu_admission, icu_discharge = _resolve(individual.icu_admission, individual.icu_discharge, timeline.icu_admission, timeline.icu_discharge, tick)
    ventilation_admission, ventilation_discharge = _resolve(individual.ventilation_admission, individual.ventilation_discharge, timeline.ventilation_admission, timeline.ventilation_discharge, tick)
    return HealthTimeline(hospital_admission, hospital_discharge, icu_admission, icu_discharge,
        ventilation_admission, ventilation_discharge, timeline.death, timeline.death_pathogen_id)
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
    _write_health_timeline!(individual::Individual, timeline::HealthTimeline)

Commits a `HealthTimeline`'s ticks onto the individual, crediting `killing_pathogen_id`.
"""
@inline function _write_health_timeline!(individual::Individual, timeline::HealthTimeline)
    individual.hospital_admission = timeline.hospital_admission
    individual.hospital_discharge = timeline.hospital_discharge
    individual.icu_admission = timeline.icu_admission
    individual.icu_discharge = timeline.icu_discharge
    individual.ventilation_admission = timeline.ventilation_admission
    individual.ventilation_discharge = timeline.ventilation_discharge
    individual.death = timeline.death
    individual.killing_pathogen_id = timeline.death >= 0 ? timeline.death_pathogen_id : DEFAULT_PATHOGEN_ID
    return nothing
end

"""
    compute_health!(individual, infections, hp, tick, rng)

Framework wrapper around the `calculate_health_progression` policy: skips the dead, preserves
already-realized care episodes, and commits the resulting `HealthTimeline` onto the individual.
"""
function compute_health!(individual::Individual, infections::InfectionRegistry,
        hp::HealthProgression, tick::Int16, rng::Xoshiro)
    dead(individual) && return nothing
    timeline = calculate_health_progression(individual, infections, hp, tick, rng)
    timeline = _keep_realized(timeline, individual, tick)
    _write_health_timeline!(individual, timeline)
    return nothing
end
