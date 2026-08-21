export CareContribution, HealthOutcome, combine_outcome, compute_health!
export CareLevel, CARE_HOSPITAL, CARE_ICU, CARE_VENTILATION

###
### HOST HEALTH
###
### What a health progression policy produces — care contributions and a terminal outcome — and the
### framework entry point that validates them and commits them to the host and the schedule.
###

"""
    CareLevel

The host care ladder. Declaration order is the ladder; the drain depends on it.
"""
@enum CareLevel::Int8 CARE_HOSPITAL = 1 CARE_ICU = 2 CARE_VENTILATION = 3

"""
    _care_event(level::CareLevel, is_admission::Bool)

The `HealthLogger` event symbol for one care level's admission or discharge.
"""
@inline function _care_event(level::CareLevel, is_admission::Bool)
    if level === CARE_HOSPITAL
        return is_admission ? :hospital_admission : :hospital_discharge
    elseif level === CARE_ICU
        return is_admission ? :icu_admission : :icu_discharge
    else
        return is_admission ? :ventilation_admission : :ventilation_discharge
    end
end

"""
    _demand(individual::Individual, level::CareLevel)

The host's current demand count for one care level.
"""
@inline _demand(individual::Individual, level::CareLevel) =
    level === CARE_HOSPITAL ? individual.hospital_demands :
    level === CARE_ICU ? individual.icu_demands : individual.ventilation_demands

"""
    _set_demand!(individual::Individual, level::CareLevel, n::Int16)

Writes one care level's demand count and returns it.
"""
@inline function _set_demand!(individual::Individual, level::CareLevel, n::Int16)
    level === CARE_HOSPITAL ? (individual.hospital_demands = n) :
    level === CARE_ICU ? (individual.icu_demands = n) : (individual.ventilation_demands = n)
    return n
end

"""
    _adjust_demand!(individual::Individual, level::CareLevel, delta::Int16)

Adds `delta` to one care level's demand count and returns the new value, from which the caller
detects the 0-1 and 1-0 edges.

Throws on a negative result, which also catches overflow since `Int16` wraps.
"""
@inline function _adjust_demand!(individual::Individual, level::CareLevel, delta::Int16)
    n = _demand(individual, level) + delta
    n < 0 && throw(ArgumentError("care demand for $level went negative on host $(individual.id): a discharge with no matching admission. Only simulation-level reset! is safe."))
    return _set_demand!(individual, level, n)
end

"""
    CareContribution

Isbits value type holding a host's precomputed care timeline: hospital/ICU/ventilation
admission and discharge ticks. Unset ticks are `-1`.

# Constraints
- Each admission requires its discharge and cannot happen after it.
- The care ladder must hold: ICU is gated behind hospital, ventilation behind ICU.
"""
struct CareContribution
    hospital_admission::Int16
    hospital_discharge::Int16
    icu_admission::Int16
    icu_discharge::Int16
    ventilation_admission::Int16
    ventilation_discharge::Int16

    function CareContribution(hospital_admission::Int16, hospital_discharge::Int16,
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

    @inline function CareContribution(;
        hospital_admission = Int16(-1),
        hospital_discharge = Int16(-1),
        icu_admission = Int16(-1),
        icu_discharge = Int16(-1),
        ventilation_admission = Int16(-1),
        ventilation_discharge = Int16(-1)
    )
        return CareContribution(
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
    CareContribution(level::CareLevel, admission::Int16, discharge::Int16)

One interval of care at `level`, with the ladder below it filled in — an ICU contribution carries its
ward cover, a ventilation contribution carries both. A patient in the ICU is in the hospital, so the
cover is real care, not bookkeeping: it lengthens the host's hospital episode too.

Use the keyword constructor instead to nest a short ICU stay inside a longer ward stay.
"""
function CareContribution(level::CareLevel, admission::Int16, discharge::Int16)
    icu = level >= CARE_ICU ? admission : Int16(-1)
    icu_end = level >= CARE_ICU ? discharge : Int16(-1)
    vent = level >= CARE_VENTILATION ? admission : Int16(-1)
    vent_end = level >= CARE_VENTILATION ? discharge : Int16(-1)
    return CareContribution(admission, discharge, icu, icu_end, vent, vent_end)
end

function Base.show(io::IO, ct::CareContribution)
    max_val = ct.hospital_discharge
    max_width = max(4, length("$max_val")) # max width of tick column

    spcs(x, max) = length("$x") > max ? "" : repeat(" ", max - length("$x")) * "$x"

    res = "Care Contribution(\n"
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

function Base.show(io::IO, o::HealthOutcome)
    o.death >= 0 && return print(io, "HealthOutcome(death at tick $(o.death), pathogen $(o.death_pathogen_id))")
    print(io, "HealthOutcome(alive)")
end

"""
    combine_outcome(a::HealthOutcome, b::HealthOutcome)

The earlier of two deaths, with its attributed pathogen.

Applied by `compute_health!`, so a policy returning `HealthOutcome()` cannot cancel a committed death.
"""
function combine_outcome(a::HealthOutcome, b::HealthOutcome)
    if a.death < 0
        return HealthOutcome(death = b.death, death_pathogen_id = b.death_pathogen_id)
    elseif b.death < 0 || a.death <= b.death
        return HealthOutcome(death = a.death, death_pathogen_id = a.death_pathogen_id)
    else
        return HealthOutcome(death = b.death, death_pathogen_id = b.death_pathogen_id)
    end
end

"""
    _committed_outcome(individual::Individual)

The host's currently scheduled death, read off the individual into a `HealthOutcome`.
"""
@inline _committed_outcome(individual::Individual) =
    HealthOutcome(death = individual.death, death_pathogen_id = individual.killing_pathogen_id)

"""
    _check_contribution(care::CareContribution, tick::Int16)

Enforces the one rule a contribution must satisfy: every tick in it is after `tick`. Anything earlier
lands in a drained bucket and never fires.
"""
@inline function _check_contribution(care::CareContribution, tick::Int16)
    for (field, value) in ((:hospital_admission, care.hospital_admission),
            (:hospital_discharge, care.hospital_discharge),
            (:icu_admission, care.icu_admission),
            (:icu_discharge, care.icu_discharge),
            (:ventilation_admission, care.ventilation_admission),
            (:ventilation_discharge, care.ventilation_discharge))
        (value < 0 || value > tick) && continue
        throw(ArgumentError("calculate_health_progression! contributed $field = $value at tick $tick: every tick in a contribution must be after the current tick."))
    end
    return nothing
end

"""
    _validate_health_plan(contributions, outcome::HealthOutcome, tick::Int16)

Checks a policy's whole output before any of it is committed, so one that throws partway leaves
nothing behind. `outcome` is checked separately because it is returned, not contributed.
"""
function _validate_health_plan(contributions::Vector{CareContribution}, outcome::HealthOutcome, tick::Int16)
    for care in contributions
        _check_contribution(care, tick)
    end
    outcome.death >= 0 && outcome.death <= tick && throw(ArgumentError(
        "calculate_health_progression! returned death = $(outcome.death) at tick $tick: a death may only be scheduled after the current tick."))
    return nothing
end

"""
    compute_health!(individual::Individual, infections::InfectionRegistry, hp::HealthProgression, new_infection::InfectionState, tick::Int16, rng::Xoshiro, sched::AbstractHealthSchedule)

Framework entry point, not overridable. Hands `calculate_health_progression!` the shard's buffer to
contribute care into, folds the death it proposes with the host's committed one, validates the whole
result, and only then files the transitions and writes the death. Invoked whenever a new infection is
added to a host.
"""
function compute_health!(individual::Individual, infections::InfectionRegistry,
        hp::HealthProgression, new_infection::InfectionState, tick::Int16, rng::Xoshiro,
        sched::AbstractHealthSchedule)
    dead(individual) && return nothing

    contributions = sched.buffer
    empty!(contributions)
    proposed = calculate_health_progression!(contributions, individual, infections, hp,
        new_infection, tick, rng)
    outcome = combine_outcome(_committed_outcome(individual), proposed)

    _validate_health_plan(contributions, outcome, tick)

    host_id = id(individual)
    for care in contributions
        _emit_contribution!(sched, host_id, care)
    end
    wake_at!(sched, outcome.death)
    individual.death = outcome.death
    individual.killing_pathogen_id = outcome.death >= 0 ? outcome.death_pathogen_id : DEFAULT_PATHOGEN_ID
    empty!(contributions)
    return nothing
end
