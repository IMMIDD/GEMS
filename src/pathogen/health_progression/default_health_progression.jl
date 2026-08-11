export DefaultHealthProgression, SevereHealthProfile, CriticalHealthProfile

"""
    SevereHealthProfile

Health profile for an infection whose peak tier is `severe`: a possible hospital (ward)
admission, anchored at the infection's `severeness_onset`.

# Parameters
- `hospital_probability::Real`: Hospital admission probability (`0.0` by default).
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Admission delay after severeness onset.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Ward stay length.
"""
struct SevereHealthProfile <: HealthProfile
    hospital_probability::Real
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}

    function SevereHealthProfile(;
        hospital_probability = 0.0,
        severeness_onset_to_hospital_admission = 0,
        hospital_admission_to_hospital_discharge = 0)

        0.0 <= hospital_probability <= 1.0 || throw(ArgumentError("hospital_probability must be between 0 and 1 (got $hospital_probability)."))
        return new(hospital_probability, severeness_onset_to_hospital_admission,
            hospital_admission_to_hospital_discharge)
    end
end

"""
    calculate_health_profile(sc::SevereHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)

Care contribution of a single `severe`-peak infection: a Bernoulli hospital admission anchored
at `infection.severeness_onset`. `severe` carries no mortality risk, so the returned
`HealthOutcome` is always empty.
"""
function calculate_health_profile(sc::SevereHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)
    hospital_admission::Int16 = Int16(-1)
    hospital_discharge::Int16 = Int16(-1)
    if gems_rand(rng) <= Float64(sc.hospital_probability)
        hospital_admission = round(Int16, infection.severeness_onset + _rand_val(sc.severeness_onset_to_hospital_admission, rng))
        hospital_discharge = round(Int16, hospital_admission + _rand_val(sc.hospital_admission_to_hospital_discharge, rng))
    end
    care = CareTimeline(hospital_admission = hospital_admission, hospital_discharge = hospital_discharge)
    return care, HealthOutcome()
end

"""
    CriticalHealthProfile

Health profile for an infection whose peak tier is `critical`: a hospital admission that can
escalate to ICU and ventilation, plus mortality risk. Each step's probability is conditional
on the step below (`hospital_to_icu_probability` = P(ICU | hospitalized), `icu_to_ventilation_probability` =
P(ventilation | ICU)); discharges chain inward-out so the stays nest by construction. Timings
are anchored at the infection's `critical_onset`. Care and mortality are computed independently
here and reconciled once, downstream, by `compute_health!`.

# Parameters
- `hospital_probability::Real`: Hospital admission probability (`0.0` by default).
- `critical_onset_to_hospital_admission::Union{Distribution, Real}`: Admission delay after critical onset.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Ward stay length when the patient does not enter the ICU.
- `hospital_to_icu_probability::Real`: ICU probability for a hospitalized patient (`0.0` by default).
- `hospital_admission_to_icu_admission::Union{Distribution, Real}`: Delay from hospital to ICU admission.
- `icu_admission_to_icu_discharge::Union{Distribution, Real}`: ICU stay length when the patient is not ventilated.
- `icu_to_ventilation_probability::Real`: Ventilation probability for an ICU patient (`0.0` by default).
- `icu_admission_to_ventilation_admission::Union{Distribution, Real}`: Delay from ICU to ventilation admission.
- `ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}`: Ventilation length.
- `ventilation_discharge_to_icu_discharge::Union{Distribution, Real}`: ICU stay after ventilation ends.
- `icu_discharge_to_hospital_discharge::Union{Distribution, Real}`: Hospital stay after ICU discharge.
- `death_probability::Real`: Death probability (`0.0` by default).
- `critical_onset_to_death::Union{Distribution, Real}`: Delay from critical onset to death.
"""
struct CriticalHealthProfile <: HealthProfile
    hospital_probability::Real
    critical_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}
    hospital_to_icu_probability::Real
    hospital_admission_to_icu_admission::Union{Distribution, Real}
    icu_admission_to_icu_discharge::Union{Distribution, Real}
    icu_to_ventilation_probability::Real
    icu_admission_to_ventilation_admission::Union{Distribution, Real}
    ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}
    ventilation_discharge_to_icu_discharge::Union{Distribution, Real}
    icu_discharge_to_hospital_discharge::Union{Distribution, Real}
    death_probability::Real
    critical_onset_to_death::Union{Distribution, Real}

    function CriticalHealthProfile(;
        hospital_probability = 0.0,
        critical_onset_to_hospital_admission = 0,
        hospital_admission_to_hospital_discharge = 0,
        hospital_to_icu_probability = 0.0,
        hospital_admission_to_icu_admission = 0,
        icu_admission_to_icu_discharge = 0,
        icu_to_ventilation_probability = 0.0,
        icu_admission_to_ventilation_admission = 0,
        ventilation_admission_to_ventilation_discharge = 0,
        ventilation_discharge_to_icu_discharge = 0,
        icu_discharge_to_hospital_discharge = 0,
        death_probability = 0.0,
        critical_onset_to_death = 0)

        for (nm, p) in ((:hospital_probability, hospital_probability),
            (:hospital_to_icu_probability, hospital_to_icu_probability),
            (:icu_to_ventilation_probability, icu_to_ventilation_probability),
            (:death_probability, death_probability))
            0.0 <= p <= 1.0 || throw(ArgumentError("$nm must be between 0 and 1 (got $p)."))
        end

        return new(hospital_probability, critical_onset_to_hospital_admission,
            hospital_admission_to_hospital_discharge, hospital_to_icu_probability,
            hospital_admission_to_icu_admission, icu_admission_to_icu_discharge,
            icu_to_ventilation_probability, icu_admission_to_ventilation_admission,
            ventilation_admission_to_ventilation_discharge, ventilation_discharge_to_icu_discharge,
            icu_discharge_to_hospital_discharge, death_probability, critical_onset_to_death)
    end
end

"""
    calculate_health_profile(cc::CriticalHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)

Care and mortality contribution of a single `critical`-peak infection, anchored at
`infection.critical_onset`. Hospital, ICU, and ventilation escalate via nested Bernoulli draws;
death is drawn independently of them.
"""
function calculate_health_profile(cc::CriticalHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)
    hospital_admission::Int16 = Int16(-1)
    hospital_discharge::Int16 = Int16(-1)
    icu_admission::Int16 = Int16(-1)
    icu_discharge::Int16 = Int16(-1)
    ventilation_admission::Int16 = Int16(-1)
    ventilation_discharge::Int16 = Int16(-1)
    death::Int16 = Int16(-1)

    if gems_rand(rng) <= Float64(cc.hospital_probability)
        hospital_admission = round(Int16, infection.critical_onset + _rand_val(cc.critical_onset_to_hospital_admission, rng))
        if gems_rand(rng) <= Float64(cc.hospital_to_icu_probability)
            icu_admission = round(Int16, hospital_admission + _rand_val(cc.hospital_admission_to_icu_admission, rng))
            if gems_rand(rng) <= Float64(cc.icu_to_ventilation_probability)
                ventilation_admission = round(Int16, icu_admission + _rand_val(cc.icu_admission_to_ventilation_admission, rng))
                ventilation_discharge = round(Int16, ventilation_admission + _rand_val(cc.ventilation_admission_to_ventilation_discharge, rng))
                icu_discharge = round(Int16, ventilation_discharge + _rand_val(cc.ventilation_discharge_to_icu_discharge, rng))
            else
                icu_discharge = round(Int16, icu_admission + _rand_val(cc.icu_admission_to_icu_discharge, rng))
            end
            hospital_discharge = round(Int16, icu_discharge + _rand_val(cc.icu_discharge_to_hospital_discharge, rng))
        else
            hospital_discharge = round(Int16, hospital_admission + _rand_val(cc.hospital_admission_to_hospital_discharge, rng))
        end
    end
    # death is independent of hospital/ICU here; the ladder and the outcome are reconciled downstream
    if gems_rand(rng) <= Float64(cc.death_probability)
        death = round(Int16, infection.critical_onset + _rand_val(cc.critical_onset_to_death, rng))
    end

    care = CareTimeline(hospital_admission = hospital_admission, hospital_discharge = hospital_discharge,
        icu_admission = icu_admission, icu_discharge = icu_discharge,
        ventilation_admission = ventilation_admission, ventilation_discharge = ventilation_discharge)
    outcome = HealthOutcome(death = death, death_pathogen_id = infection.pathogen_id)
    return care, outcome
end

"""
    DefaultHealthProgression <: HealthProgression

Default host health policy. Holds a `SevereHealthProfile` and a `CriticalHealthProfile`; each
infection contributes care and mortality risk from the profile for its peak tier once, when it
arrives. Care is folded into the host's committed timeline via `_merge_care` and mortality via
`_combine_outcome` (earliest death wins), independently of each other. Ventilation is disabled by
default (`CriticalHealthProfile` has zero ventilation probability and length).

Contributions are independent, not synergistic: a host's care demand is the union of what each
infection demanded on its own. Override `calculate_health_progression` to model interaction
between co-active infections.

# Example

```julia
hp = DefaultHealthProgression(
    severe = SevereHealthProfile(hospital_probability = 0.1),
    critical = CriticalHealthProfile(hospital_to_icu_probability = 0.6, death_probability = 0.25))
```
"""
struct DefaultHealthProgression{S<:HealthProfile, C<:HealthProfile} <: HealthProgression
    severe::S
    critical::C

    # the canonical default policy; type parameters are inferred from the profiles
    function DefaultHealthProgression(;
        severe::HealthProfile = SevereHealthProfile(),
        critical::HealthProfile = CriticalHealthProfile()
        )

        return new{typeof(severe), typeof(critical)}(severe, critical)
    end
end

"""
    _combine_outcome(a::HealthOutcome, b::HealthOutcome)

The default policy's combination of two independent infections' terminal risk: the earlier
death, with its attributed pathogen. A custom `HealthProgression` is free to combine
differently (e.g. capacity-constrained mortality that reads the already-combined `CareTimeline`).
"""
function _combine_outcome(a::HealthOutcome, b::HealthOutcome)
    if a.death < 0
        return HealthOutcome(death = b.death, death_pathogen_id = b.death_pathogen_id)
    elseif b.death < 0 || a.death <= b.death
        return HealthOutcome(death = a.death, death_pathogen_id = a.death_pathogen_id)
    else
        return HealthOutcome(death = b.death, death_pathogen_id = b.death_pathogen_id)
    end
end

"""
    _merge_episode(committed_admission, committed_discharge, added_admission, added_discharge, tick)

Merges one care tier's committed episode with a newly drawn contribution.

An episode still open at `tick` keeps its realized admission and extends to the later discharge.
A committed episode that has already closed is left alone and replaced by the new contribution.
"""
@inline function _merge_episode(committed_admission::Int16, committed_discharge::Int16,
        added_admission::Int16, added_discharge::Int16, tick::Int16)
    (0 <= committed_admission <= tick < committed_discharge) &&
        return (committed_admission, _max_set(committed_discharge, added_discharge))
    (committed_discharge >= 0 && committed_discharge <= tick) && return (added_admission, added_discharge)
    return (_min_set(committed_admission, added_admission), _max_set(committed_discharge, added_discharge))
end

"""
    _merge_care(committed::CareTimeline, added::CareTimeline, tick::Int16)

Folds a new contribution into the host's committed care timeline, per tier, via `_merge_episode`.
"""
@inline function _merge_care(committed::CareTimeline, added::CareTimeline, tick::Int16)
    hospital_admission, hospital_discharge = _merge_episode(committed.hospital_admission, committed.hospital_discharge, added.hospital_admission, added.hospital_discharge, tick)
    icu_admission, icu_discharge = _merge_episode(committed.icu_admission, committed.icu_discharge, added.icu_admission, added.icu_discharge, tick)
    ventilation_admission, ventilation_discharge = _merge_episode(committed.ventilation_admission, committed.ventilation_discharge, added.ventilation_admission, added.ventilation_discharge, tick)
    return CareTimeline(hospital_admission, hospital_discharge, icu_admission, icu_discharge,
        ventilation_admission, ventilation_discharge)
end

"""
    calculate_health_progression(individual::Individual, infections::InfectionRegistry, hp::HealthProgression, ctx::HealthContext, rng::Xoshiro)

Generic combination policy: draws the contribution of `ctx.new_infection` only and folds it into
what the host is already committed to, via `_merge_care`/`_combine_outcome`. An infection that
selects no profile leaves the committed timeline untouched.

Override this method to model coinfection synergy; it receives every active infection via
`infections`, and must return a plan anchored after `ctx.tick`.
"""
function calculate_health_progression(individual::Individual, infections::InfectionRegistry,
        hp::HealthProgression, ctx::HealthContext, rng::Xoshiro)

    profile = select_health_profile(hp, ctx.new_infection)
    profile === nothing && return ctx.committed_care, ctx.committed_outcome
    c, o = calculate_health_profile(profile, individual, ctx.new_infection, rng)
    return _merge_care(ctx.committed_care, c, ctx.tick), _combine_outcome(ctx.committed_outcome, o)
end

"""
    select_health_profile(hp::DefaultHealthProgression, infection::InfectionState)

Routes by peak tier: `severe` for a severe-peak infection, `critical` for a critical-peak one, and
`nothing` for an infection that never reached `severe`.
"""
function select_health_profile(hp::DefaultHealthProgression, infection::InfectionState)
    infection.severeness_onset < 0 && return nothing
    infection.critical_onset < 0 ? hp.severe : hp.critical
end