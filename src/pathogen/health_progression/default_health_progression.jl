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

# care contribution of a single severe-peak infection
function calculate_health_profile(sc::SevereHealthProfile, infection::InfectionState, rng::Xoshiro)
    hospital_admission::Int16 = Int16(-1)
    hospital_discharge::Int16 = Int16(-1)
    if gems_rand(rng) <= Float64(sc.hospital_probability)
        hospital_admission = round(Int16, infection.severeness_onset + _rand_val(sc.severeness_onset_to_hospital_admission, rng))
        hospital_discharge = round(Int16, hospital_admission + _rand_val(sc.hospital_admission_to_hospital_discharge, rng))
    end
    return HealthTimeline(hospital_admission, hospital_discharge, Int16(-1), Int16(-1),
        Int16(-1), Int16(-1), Int16(-1), infection.pathogen_id)
end

"""
    CriticalHealthProfile

Health profile for an infection whose peak tier is `critical`: a hospital admission that can
escalate to ICU and ventilation, plus an ungated death. Each step's probability is conditional
on the step below (`icu_probability` = P(ICU | hospitalized), `ventilation_probability` =
P(ventilation | ICU)); discharges chain inward-out so the stays nest by construction. Timings
are anchored at the infection's `critical_onset`.

# Parameters
- `hospital_probability::Real`: Hospital admission probability (`0.0` by default).
- `critical_onset_to_hospital_admission::Union{Distribution, Real}`: Admission delay after critical onset.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Ward stay length when the patient does not enter the ICU.
- `icu_probability::Real`: ICU probability for a hospitalized patient (`0.0` by default).
- `hospital_admission_to_icu_admission::Union{Distribution, Real}`: Delay from hospital to ICU admission.
- `icu_admission_to_icu_discharge::Union{Distribution, Real}`: ICU stay length when the patient is not ventilated.
- `ventilation_probability::Real`: Ventilation probability for an ICU patient (`0.0` by default).
- `icu_admission_to_ventilation_admission::Union{Distribution, Real}`: Delay from ICU to ventilation admission.
- `ventilation_admission_to_ventilation_discharge::Union{Distribution, Real}`: Ventilation length.
- `ventilation_discharge_to_icu_discharge::Union{Distribution, Real}`: ICU stay after ventilation ends.
- `icu_discharge_to_hospital_discharge::Union{Distribution, Real}`: Hospital stay after ICU discharge.
- `death_probability::Real`: Death probability (not gated by hospital or ICU; `0.0` by default).
- `critical_onset_to_death::Union{Distribution, Real}`: Delay from critical onset to death.
"""
struct CriticalHealthProfile <: HealthProfile
    hospital_probability::Real
    critical_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}
    icu_probability::Real
    hospital_admission_to_icu_admission::Union{Distribution, Real}
    icu_admission_to_icu_discharge::Union{Distribution, Real}
    ventilation_probability::Real
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
        icu_probability = 0.0,
        hospital_admission_to_icu_admission = 0,
        icu_admission_to_icu_discharge = 0,
        ventilation_probability = 0.0,
        icu_admission_to_ventilation_admission = 0,
        ventilation_admission_to_ventilation_discharge = 0,
        ventilation_discharge_to_icu_discharge = 0,
        icu_discharge_to_hospital_discharge = 0,
        death_probability = 0.0,
        critical_onset_to_death = 0)

        for (nm, p) in ((:hospital_probability, hospital_probability),
            (:icu_probability, icu_probability),
            (:ventilation_probability, ventilation_probability),
            (:death_probability, death_probability))
            0.0 <= p <= 1.0 || throw(ArgumentError("$nm must be between 0 and 1 (got $p)."))
        end

        return new(hospital_probability, critical_onset_to_hospital_admission,
            hospital_admission_to_hospital_discharge, icu_probability,
            hospital_admission_to_icu_admission, icu_admission_to_icu_discharge,
            ventilation_probability, icu_admission_to_ventilation_admission,
            ventilation_admission_to_ventilation_discharge, ventilation_discharge_to_icu_discharge,
            icu_discharge_to_hospital_discharge, death_probability, critical_onset_to_death)
    end
end

# care contribution of a single critical-peak infection
function calculate_health_profile(cc::CriticalHealthProfile, infection::InfectionState, rng::Xoshiro)
    hospital_admission::Int16 = Int16(-1)
    hospital_discharge::Int16 = Int16(-1)
    icu_admission::Int16 = Int16(-1)
    icu_discharge::Int16 = Int16(-1)
    ventilation_admission::Int16 = Int16(-1)
    ventilation_discharge::Int16 = Int16(-1)
    death::Int16 = Int16(-1)

    if gems_rand(rng) <= Float64(cc.hospital_probability)
        hospital_admission = round(Int16, infection.critical_onset + _rand_val(cc.critical_onset_to_hospital_admission, rng))
        if gems_rand(rng) <= Float64(cc.icu_probability)
            icu_admission = round(Int16, hospital_admission + _rand_val(cc.hospital_admission_to_icu_admission, rng))
            if gems_rand(rng) <= Float64(cc.ventilation_probability)
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
    # death hangs off critical, ungated by hospital/ICU
    if gems_rand(rng) <= Float64(cc.death_probability)
        death = round(Int16, infection.critical_onset + _rand_val(cc.critical_onset_to_death, rng))
    end
    return HealthTimeline(hospital_admission, hospital_discharge, icu_admission, icu_discharge,
        ventilation_admission, ventilation_discharge, death, infection.pathogen_id)
end

"""
    DefaultHealthProgression <: HealthProgression

Default host health policy. Holds a `SevereHealthProfile` and a `CriticalHealthProfile`; each active
infection contributes care from the profile for its peak tier, and the contributions are folded
(`_combine_independent`). Ventilation is disabled by default (`CriticalHealthProfile` has zero ventilation
probability and length).

# Example

```julia
hp = DefaultHealthProgression(
    severe = SevereHealthProfile(hospital_probability = 0.1),
    critical = CriticalHealthProfile(icu_probability = 0.6, death_probability = 0.25))
```
"""
struct DefaultHealthProgression{S<:HealthProfile, C<:HealthProfile} <: HealthProgression
    severe::S
    critical::C

    # the canonical default policy; type parameters are inferred from the profiles
    function DefaultHealthProgression(;
        severe::HealthProfile = SevereHealthProfile(
            hospital_probability = 0.05,
            severeness_onset_to_hospital_admission = Poisson(2),
            hospital_admission_to_hospital_discharge = Poisson(10)),
        critical::HealthProfile = CriticalHealthProfile(
            hospital_probability = 0.95,
            critical_onset_to_hospital_admission = Poisson(1),
            hospital_admission_to_hospital_discharge = Poisson(10),
            icu_probability = 0.5,
            hospital_admission_to_icu_admission = Poisson(1),
            icu_admission_to_icu_discharge = Poisson(8),
            icu_discharge_to_hospital_discharge = Poisson(5),
            death_probability = 0.3,
            critical_onset_to_death = Poisson(7)))

        return new{typeof(severe), typeof(critical)}(severe, critical)
    end
end

"""
    _combine_independent(a::HealthTimeline, b::HealthTimeline)

The default policy's combination of two independent infections' care: earliest admission,
latest discharge, and the earlier death (with its attributed pathogen). A custom `HealthProgression` is free
to combine differently (e.g. coinfection synergy).
"""
function _combine_independent(a::HealthTimeline, b::HealthTimeline)
    if a.death < 0
        death = b.death; death_pathogen_id = b.death_pathogen_id
    elseif b.death < 0 || a.death <= b.death
        death = a.death; death_pathogen_id = a.death_pathogen_id
    else
        death = b.death; death_pathogen_id = b.death_pathogen_id
    end
    return HealthTimeline(
        _min_set(a.hospital_admission, b.hospital_admission),
        _max_set(a.hospital_discharge, b.hospital_discharge),
        _min_set(a.icu_admission, b.icu_admission),
        _max_set(a.icu_discharge, b.icu_discharge),
        _min_set(a.ventilation_admission, b.ventilation_admission),
        _max_set(a.ventilation_discharge, b.ventilation_discharge),
        death, death_pathogen_id)
end



function calculate_health_progression(individual::Individual, infections::InfectionRegistry,
        hp::DefaultHealthProgression, tick::Int16, rng::Xoshiro)

    timeline = HealthTimeline()
    for infection in each_infection(individual, infections)
        # a non-severe infection demands no host care
        infection.severeness_onset < 0 && continue
        tl = infection.critical_onset < 0 ? calculate_health_profile(hp.severe, infection, rng) : calculate_health_profile(hp.critical, infection, rng)
        timeline = _combine_independent(timeline, tl)
    end
    return timeline
end


"""
    _health_profile_type(::Type{<:ProgressionCategory})

The `HealthProfile` type a progression category routes embedded health params into, or `nothing`
if the tier takes no host care. Overridden per category
(e.g. `_health_profile_type(::Type{Severe}) = SevereHealthProfile`).
"""
_health_profile_type(::Type{<:ProgressionCategory}) = nothing

# the embedded HealthProfile of a category (nothing if its tier takes no care)
_embedded_health_profile(c::ProgressionCategory) = _health_profile_type(typeof(c)) === nothing ? nothing : c.care

_has_embedded_health_profile(p) = any(c -> _embedded_health_profile(c) !== nothing, p.progressions)

# assemble the global health policy from care embedded across a single pathogen's categories
function _harvest_health_progression(pathogens)
    severe_profile = nothing
    critical_profile = nothing
    for p in pathogens, c in p.progressions
        profile = _embedded_health_profile(c)
        profile === nothing && continue
        tier = _health_profile_type(typeof(c))
        if tier === SevereHealthProfile
            isnothing(severe_profile) || throw(ArgumentError("more than one severe-tier category carries embedded care"))
            severe_profile = profile
        elseif tier === CriticalHealthProfile
            isnothing(critical_profile) || throw(ArgumentError("more than one critical-tier category carries embedded care"))
            critical_profile = profile
        end
    end
    if !isnothing(severe_profile) && !isnothing(critical_profile)
        return DefaultHealthProgression(severe = severe_profile, critical = critical_profile)
    elseif !isnothing(severe_profile)
        return DefaultHealthProgression(severe = severe_profile)
    elseif !isnothing(critical_profile)
        return DefaultHealthProgression(critical = critical_profile)
    end
    return DefaultHealthProgression()
end
