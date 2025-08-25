export Symptomatic

"""
    Symptomatic <: ProgressionCategory

A disease progression category for individuals who develop symptoms but do not require hospitalization.

**IMPORTANT**: The infectiousness onset must be at least 1 tick after exposure to avoid issues with immediate transmission.
Therefore, the calculation for infectiousness_onset includes a +1 offset.
The provided distributions should account for this offset to ensure realistic timing.
Providing, for example a Poisson(2) distribution would result in an average of 3 ticks from exposure to infectiousness onset (Poisson(2) + 1).

# Disease events
`exposure` -> `infectiousness_onset` -> `symptom_onset` -> `recovery`.

# Parameters
- `exposure_to_infectiousness::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_to_symptom_onset::Union{Distribution, Real}`: Time from becoming infectious to symptom onset.
- `symptom_onset_to_recovery::Union{Distribution, Real}`: Time from symptom onset to recovery.

# Example
The code below instantiates a `Symptomatic` progression category with specific distributions for the time intervals.

```julia
dp = Symptomatic(
    exposure_to_infectiousness = Poisson(3),
    infectiousness_to_symptom_onset = Poisson(1),
    symptom_onset_to_recovery = Poisson(7)
)
```
"""
@with_kw mutable struct Symptomatic <: ProgressionCategory
    exposure_to_infectiousness::Union{Distribution, Real}
    infectiousness_to_symptom_onset::Union{Distribution, Real}
    symptom_onset_to_recovery::Union{Distribution, Real}
end

function calculate_progression(individual::Individual, tick::Int16, dp::Symptomatic)
    # Calculate the time to infectiousness
    infectiousness_onset = tick + Int16(1) + rand(dp.exposure_to_infectiousness)

    # Calculate the time to symptom onset
    symptom_onset = infectiousness_onset + rand(dp.infectiousness_to_symptom_onset)

    # Calculate the time to recovery
    recovery = symptom_onset + rand(dp.symptom_onset_to_recovery)

    return DiseaseProgression(
        exposure = tick,
        infectiousness_onset = infectiousness_onset,
        symptom_onset = symptom_onset,
        recovery = recovery
    )
end