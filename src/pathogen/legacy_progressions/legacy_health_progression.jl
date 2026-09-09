export LegacyCriticalHealthProfile

"""
    LegacyCriticalHealthProfile <: HealthProfile

Health profile reproducing the pre-decoupling `Critical` care course: deterministic hospital -> ICU
admission and a probabilistic death anchored at ICU admission. Unlike the modern
`CriticalHealthProfile`, death shares the drawn ICU-admission tick (preserving the old within-infection
ICU<->death coupling), and hospital/ICU are always entered. Anchored at `infection.critical_onset`
(= the old hospital admission). Discharges are reconciled against a scheduled death downstream by
`compute_health!`.

# Parameters
- `hospital_admission_to_icu_admission::Union{Distribution, Real}`: ICU admission delay after hospital admission.
- `icu_admission_to_icu_discharge::Union{Distribution, Real}`: ICU stay length.
- `icu_discharge_to_hospital_discharge::Union{Distribution, Real}`: Hospital stay after ICU discharge.
- `death_probability::Real`: Death probability (`0` by default).
- `icu_admission_to_death::Union{Distribution, Real}`: Death delay after ICU admission.
"""
struct LegacyCriticalHealthProfile <: HealthProfile
    hospital_admission_to_icu_admission::Union{Distribution, Real}
    icu_admission_to_icu_discharge::Union{Distribution, Real}
    icu_discharge_to_hospital_discharge::Union{Distribution, Real}
    death_probability::Real
    icu_admission_to_death::Union{Distribution, Real}

    function LegacyCriticalHealthProfile(;
        hospital_admission_to_icu_admission = 0,
        icu_admission_to_icu_discharge = 0,
        icu_discharge_to_hospital_discharge = 0,
        death_probability = 0.0,
        icu_admission_to_death = 0)

        0.0 <= death_probability <= 1.0 || throw(ArgumentError("death_probability must be between 0 and 1 (got $death_probability)."))
        return new(hospital_admission_to_icu_admission, icu_admission_to_icu_discharge,
            icu_discharge_to_hospital_discharge, death_probability, icu_admission_to_death)
    end
end

"""
    calculate_health_profile(cc::LegacyCriticalHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)

Care and mortality contribution of a legacy critical infection, anchored at `infection.critical_onset`
(the old hospital admission). Hospital and ICU are always entered; death is drawn off the ICU-admission
tick as in the old model.
"""
function calculate_health_profile(cc::LegacyCriticalHealthProfile, individual::Individual, infection::InfectionState, rng::Xoshiro)
    hospital_admission::Int16 = infection.critical_onset
    icu_admission::Int16 = rand_round(hospital_admission + _rand_val(cc.hospital_admission_to_icu_admission, rng), rng)
    icu_discharge::Int16 = rand_round(icu_admission + _rand_val(cc.icu_admission_to_icu_discharge, rng), rng)
    hospital_discharge::Int16 = rand_round(icu_discharge + _rand_val(cc.icu_discharge_to_hospital_discharge, rng), rng)

    death::Int16 = Int16(-1)
    if gems_rand(rng) <= cc.death_probability
        death = rand_round(icu_admission + _rand_val(cc.icu_admission_to_death, rng), rng)
    end

    care = CareContribution(hospital_admission = hospital_admission, hospital_discharge = hospital_discharge,
        icu_admission = icu_admission, icu_discharge = icu_discharge)
    outcome = HealthOutcome(death = death, death_pathogen_id = infection.pathogen_id)
    return care, outcome
end


"""
    _has_legacy_category(pathogen)

`true` if any of `pathogen`'s progression categories carries legacy host care
([`Hospitalized`](@ref) or [`LegacyCritical`](@ref)). A lone `Symptomatic` has no health and does not count.
"""
_has_legacy_category(pathogen) = any(c -> c isa Hospitalized || c isa LegacyCritical, pathogen.progressions)

"""
    _harvest_legacy_health_profiles(pathogens, baseline = nothing)

Assembles the `HealthProfileIndex` for the legacy compatibility categories, keyed by
`(pathogen_id, 1-based slot)`: `Hospitalized` becomes a ward-only `SevereHealthProfile`,
`LegacyCritical` a `LegacyCriticalHealthProfile`. Keying on the slot is what lets a
severe-peaking `Hospitalized` (ward) and `Severe` (home) coexist. A modern category alongside them
falls back to `baseline`.
"""
function _harvest_legacy_health_profiles(pathogens, baseline = nothing)
    profiles = HealthProfileIndex()
    for p in pathogens
        pid = id(p)
        for (k, c) in enumerate(p.progressions)
            key = (pid, Int8(k))
            if c isa Hospitalized
                profiles[key] = SevereHealthProfile(
                    hospital_probability = 1.0,
                    severeness_onset_to_hospital_admission = c.severeness_onset_to_hospital_admission,
                    hospital_admission_to_hospital_discharge = c.hospital_admission_to_hospital_discharge)
            elseif c isa LegacyCritical
                profiles[key] = LegacyCriticalHealthProfile(
                    hospital_admission_to_icu_admission = c.hospital_admission_to_icu_admission,
                    icu_admission_to_icu_discharge = c.icu_admission_to_icu_discharge,
                    icu_discharge_to_hospital_discharge = c.icu_discharge_to_hospital_discharge,
                    death_probability = c.death_probability,
                    icu_admission_to_death = c.icu_admission_to_death)
            else
                profile = _baseline_profile(baseline, _health_profile_type(typeof(c)))
                isnothing(profile) || (profiles[key] = profile)
            end
        end
    end
    return profiles
end
