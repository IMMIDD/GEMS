export Severe

"""
    Severe <: ProgressionCategory

A disease progression category for individuals who develop severe symptoms.
They will stay home during the severe stage of their illness but do not require hospitalization.

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

# Example
The code below instantiates a `Severe` progression category with specific distributions for the time intervals.

```julia
dp = Severe(
    exposure_to_infectiousness_onset = Poisson(3),
    infectiousness_onset_to_symptom_onset = Poisson(1),
    symptom_onset_to_severeness_onset = Poisson(2),
    severeness_onset_to_severeness_offset = Poisson(3),
    severeness_offset_to_recovery = Poisson(7)
)
```
"""
@with_kw mutable struct Severe <: ProgressionCategory
    exposure_to_infectiousness_onset::Union{Distribution, Real}
    infectiousness_onset_to_symptom_onset::Union{Distribution, Real}
    symptom_onset_to_severeness_onset::Union{Distribution, Real}
    severeness_onset_to_severeness_offset::Union{Distribution, Real}
    severeness_offset_to_recovery::Union{Distribution, Real}
end

function calculate_progression(individual::Individual, tick::Int16, dp::Severe;
        rng::AbstractRNG = Random.default_rng())

    # Calculate the time to infectiousness
    infectiousness_onset = tick + Int16(1) + rand_val(dp.exposure_to_infectiousness_onset, rng)

    # Calculate the time to symptom onset
    symptom_onset = infectiousness_onset + rand_val(dp.infectiousness_onset_to_symptom_onset, rng)

    # Calculate the time to severeness onset
    severeness_onset = symptom_onset + rand_val(dp.symptom_onset_to_severeness_onset, rng)

    # Calculate the time to severeness offset
    severeness_offset = severeness_onset + rand_val(dp.severeness_onset_to_severeness_offset, rng)

    # Calculate the time to recovery
    recovery = severeness_offset + rand_val(dp.severeness_offset_to_recovery, rng)

    return DiseaseProgression(
        exposure = tick,
        infectiousness_onset = infectiousness_onset,
        symptom_onset = symptom_onset,
        severeness_onset = severeness_onset,
        severeness_offset = severeness_offset,
        recovery = recovery
    )
end