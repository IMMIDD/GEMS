export ICU

"""
    ICU <: ProgressionCategory

A disease progression category for individuals who develop critical symptoms and are always admitted to the ICU.
Requires an `ICUHealthProfile`; unlike `Critical`, hospital and ICU admission are not drawn.

**IMPORTANT**: The infectiousness onset must be at least 1 tick after exposure to avoid issues with immediate transmission.
Therefore, the calculation for infectiousness_onset includes a +1 offset.
The provided distributions should account for this offset to ensure realistic timing.
Providing, for example a Poisson(2) distribution would result in an average of 3 ticks from exposure to infectiousness onset (Poisson(2) + 1).

# Disease events
`exposure` -> `infectiousness_onset` -> `symptom_onset` -> `severeness_onset` -> `critical_onset` -> `critical_offset` -> `severeness_offset` -> `recovery`.

# Parameters
- `exposure_to_infectiousness_onset::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_onset_to_symptom_onset::Union{Distribution, Real}`: Time from becoming infectious to symptom onset.
- `symptom_onset_to_severeness_onset::Union{Distribution, Real}`: Time from symptom onset to severeness onset.
- `severeness_onset_to_critical_onset::Union{Distribution, Real}`: Time from severeness onset to critical onset.
- `critical_onset_to_critical_offset::Union{Distribution, Real}`: Time from critical onset to critical offset.
- `critical_offset_to_severeness_offset::Union{Distribution, Real}`: Time from critical offset to severeness offset.
- `severeness_offset_to_recovery::Union{Distribution, Real}`: Time from severeness offset to recovery.
- `health::ICUHealthProfile`: ICU care, given as an object or as flat `ICUHealthProfile` parameters.

# Example

```julia
dp = ICU(
    exposure_to_infectiousness_onset = Poisson(3),
    infectiousness_onset_to_symptom_onset = Poisson(1),
    symptom_onset_to_severeness_onset = Poisson(2),
    severeness_onset_to_critical_onset = Poisson(1),
    critical_onset_to_critical_offset = Poisson(8),
    critical_offset_to_severeness_offset = Poisson(5),
    severeness_offset_to_recovery = Poisson(2),
    icu_admission_to_icu_discharge = Poisson(8),
    icu_discharge_to_hospital_discharge = Poisson(5)
)
```
"""
mutable struct ICU <: ProgressionCategory
    # the course, built once from this category's timings
    inner::Critical
    # embedded host health (build-time only; harvested into the HealthProgression, ignored by calculate_progression)
    health::ICUHealthProfile

    function ICU(;
        exposure_to_infectiousness_onset,
        infectiousness_onset_to_symptom_onset,
        symptom_onset_to_severeness_onset,
        severeness_onset_to_critical_onset,
        critical_onset_to_critical_offset,
        critical_offset_to_severeness_offset,
        severeness_offset_to_recovery,
        health::Union{Nothing, ICUHealthProfile} = nothing,
        health_params...)

        profile = _embed_health(ICU, health, nothing, health_params)
        isnothing(profile) && throw(ArgumentError("ICU requires a health profile; pass `health = ICUHealthProfile(...)` or its parameters."))
        inner = Critical(; exposure_to_infectiousness_onset, infectiousness_onset_to_symptom_onset,
            symptom_onset_to_severeness_onset, severeness_onset_to_critical_onset,
            critical_onset_to_critical_offset, critical_offset_to_severeness_offset, severeness_offset_to_recovery)
        return new(inner, profile)
    end
end

_health_profile_type(::Type{ICU}) = ICUHealthProfile

calculate_progression(individual::Individual, tick::Int16, dp::ICU, rng::Xoshiro) =
    calculate_progression(individual, tick, dp.inner, rng)
