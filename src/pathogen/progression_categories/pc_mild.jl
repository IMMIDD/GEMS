export Mild

"""
    Mild <: ProgressionCategory

A disease progression category for individuals who develop mild symptoms.
They do not require hospitalization and continue their daily activities but are aware of their illness,
unless an embedded `MildHealthProfile` keeps them home while symptomatic.

**IMPORTANT**: The infectiousness onset must be at least 1 tick after exposure to avoid issues with immediate transmission.
Therefore, the calculation for infectiousness_onset includes a +1 offset.
The provided distributions should account for this offset to ensure realistic timing.
Providing, for example a Poisson(2) distribution would result in an average of 3 ticks from exposure to infectiousness onset (Poisson(2) + 1).

# Disease events
`exposure` -> `infectiousness_onset` -> `symptom_onset` -> `recovery`.

# Parameters
- `exposure_to_infectiousness_onset::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_onset_to_symptom_onset::Union{Distribution, Real}`: Time from becoming infectious to symptom onset.
- `symptom_onset_to_recovery::Union{Distribution, Real}`: Time from symptom onset to recovery.

# Example
The code below instantiates a `Mild` progression category with specific distributions for the time intervals.

```julia
dp = Mild(
    exposure_to_infectiousness_onset = Poisson(3),
    infectiousness_onset_to_symptom_onset = Poisson(1),
    symptom_onset_to_recovery = Poisson(7)
)
```

Host health for this tier may be embedded directly, either as a `MildHealthProfile` object or as flat
`MildHealthProfile` parameters:

```julia
dp = Mild(
    exposure_to_infectiousness_onset = Poisson(3),
    infectiousness_onset_to_symptom_onset = Poisson(1),
    symptom_onset_to_recovery = Poisson(7),
    symptomatic_homebound_probability = 0.3
)
```
"""
mutable struct Mild <: ProgressionCategory
    exposure_to_infectiousness_onset::Union{Distribution, Real}
    infectiousness_onset_to_symptom_onset::Union{Distribution, Real}
    symptom_onset_to_recovery::Union{Distribution, Real}
    # embedded host health (build-time only; harvested into the HealthProfileIndex, ignored by
    # calculate_progression). Pass `health=MildHealthProfile(...)` or the MildHealthProfile params directly.
    health::Union{Nothing, HealthProfile}

    function Mild(;
        exposure_to_infectiousness_onset,
        infectiousness_onset_to_symptom_onset,
        symptom_onset_to_recovery,
        health::Union{Nothing, HealthProfile} = nothing,
        health_params...)

        return new(exposure_to_infectiousness_onset, infectiousness_onset_to_symptom_onset,
            symptom_onset_to_recovery, _embed_health(Mild, health, nothing, health_params))
    end
end

_health_profile_type(::Type{Mild}) = MildHealthProfile

function calculate_progression(individual::Individual, tick::Int16, dp::Mild, rng::Xoshiro)

    # Calculate the time to infectiousness
    infectiousness_onset::Int16 = rand_round(tick + 1 + _rand_val(dp.exposure_to_infectiousness_onset, rng), rng)

    # Calculate the time to symptom onset
    symptom_onset::Int16 = rand_round(infectiousness_onset + _rand_val(dp.infectiousness_onset_to_symptom_onset, rng), rng)

    # Calculate the time to recovery
    recovery::Int16 = rand_round(symptom_onset + _rand_val(dp.symptom_onset_to_recovery, rng), rng)

    return DiseaseProgression(
        exposure = tick,
        infectiousness_onset = infectiousness_onset,
        symptom_onset = symptom_onset,
        recovery = recovery
    )
end
