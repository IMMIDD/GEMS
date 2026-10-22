export Ward

"""
    Ward <: ProgressionCategory

A disease progression category for individuals who develop severe symptoms and are always admitted to the ward.
Requires a `WardHealthProfile`; unlike `Severe`, hospitalization is not drawn.

**IMPORTANT**: The infectiousness onset must be at least 1 tick after exposure to avoid issues with immediate transmission.
Therefore, the calculation for infectiousness_onset includes a +1 offset.
The provided distributions should account for this offset to ensure realistic timing.
Providing, for example a Poisson(2) distribution would result in an average of 3 ticks from exposure to infectiousness onset (Poisson(2) + 1).

# Disease events
`exposure` -> `infectiousness_onset` -> `symptom_onset` -> `severeness_onset` -> `severeness_offset` -> `recovery`.

# Parameters
- `exposure_to_infectiousness_onset::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_onset_to_symptom_onset::Union{Distribution, Real}`: Time from becoming infectious to symptom onset.
- `symptom_onset_to_severeness_onset::Union{Distribution, Real}`: Time from symptom onset to severeness onset.
- `severeness_onset_to_severeness_offset::Union{Distribution, Real}`: Time from severeness onset to severeness offset.
- `severeness_offset_to_recovery::Union{Distribution, Real}`: Time from severeness offset to recovery.
- `health::WardHealthProfile`: Ward care, given as an object or as flat `WardHealthProfile` parameters.

# Example

```julia
dp = Ward(
    exposure_to_infectiousness_onset = Poisson(3),
    infectiousness_onset_to_symptom_onset = Poisson(1),
    symptom_onset_to_severeness_onset = Poisson(2),
    severeness_onset_to_severeness_offset = Poisson(8),
    severeness_offset_to_recovery = Poisson(7),
    severeness_onset_to_hospital_admission = 0,
    hospital_admission_to_hospital_discharge = Poisson(8)
)
```
"""
mutable struct Ward <: ProgressionCategory
    # the course, built once from this category's timings
    inner::Severe
    # embedded host health (build-time only; harvested into the HealthProgression, ignored by calculate_progression)
    health::WardHealthProfile

    function Ward(;
        exposure_to_infectiousness_onset,
        infectiousness_onset_to_symptom_onset,
        symptom_onset_to_severeness_onset,
        severeness_onset_to_severeness_offset,
        severeness_offset_to_recovery,
        health::Union{Nothing, WardHealthProfile} = nothing,
        health_params...)

        profile = _embed_health(Ward, health, nothing, health_params)
        isnothing(profile) && throw(ArgumentError("Ward requires a health profile; pass `health = WardHealthProfile(...)` or its parameters."))
        inner = Severe(; exposure_to_infectiousness_onset, infectiousness_onset_to_symptom_onset,
            symptom_onset_to_severeness_onset, severeness_onset_to_severeness_offset, severeness_offset_to_recovery)
        return new(inner, profile)
    end
end

_health_profile_type(::Type{Ward}) = WardHealthProfile

calculate_progression(individual::Individual, tick::Int16, dp::Ward, rng::Xoshiro) =
    calculate_progression(individual, tick, dp.inner, rng)
