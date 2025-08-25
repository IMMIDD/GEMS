export Hospitalized

"""
    Hospitalized <: ProgressionCategory

A disease progression category for individuals who develop severe symptoms requiring hospitalization but not ICU care.

**IMPORTANT**: The infectiousness onset must be at least 1 tick after exposure to avoid issues with immediate transmission.
Therefore, the calculation for infectiousness_onset includes a +1 offset.
The provided distributions should account for this offset to ensure realistic timing.
Providing, for example a Poisson(2) distribution would result in an average of 3 ticks from exposure to infectiousness onset (Poisson(2) + 1).

# Disease events
`exposure` -> `infectiousness_onset` -> `symptom_onset` -> `severeness_onset` -> `hospital_admission` -> `hospital_discharge` -> `recovery`.

# Parameters
- `exposure_to_infectiousness_onset::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_onset_to_symptom_onset::Union{Distribution, Real}`: Time from becoming infectious to symptom onset.
- `symptom_onset_to_severeness_onset::Union{Distribution, Real}`: Time from symptom onset to severeness onset.
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Time from severeness onset to hospital admission.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Time from hospital admission to hospital discharge.
- `hospital_discharge_to_recovery::Union{Distribution, Real}`: Time from hospital discharge to recovery.

# Example
The code below instantiates a `Hospitalized` progression category with specific distributions for the time intervals.

```julia
dp = Hospitalized(
    exposure_to_infectiousness_onset = Poisson(3),
    infectiousness_onset_to_symptom_onset = Poisson(1),
    symptom_onset_to_severeness_onset = Poisson(2),
    severeness_onset_to_hospital_admission = Poisson(1),
    hospital_admission_to_hospital_discharge = Poisson(10),
    hospital_discharge_to_recovery = Poisson(5)
)
```
"""
@with_kw mutable struct Hospitalized <: ProgressionCategory
    exposure_to_infectiousness_onset::Union{Distribution, Real}
    infectiousness_onset_to_symptom_onset::Union{Distribution, Real}
    symptom_onset_to_severeness_onset::Union{Distribution, Real}
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}
    hospital_discharge_to_recovery::Union{Distribution, Real}
end

function calculate_progression(individual::Individual, tick::Int16, dp::Hospitalized)
    # Calculate the time to infectiousness
    infectiousness_onset = tick + Int16(1) + rand_val(dp.exposure_to_infectiousness_onset)

    # Calculate the time to symptom onset
    symptom_onset = infectiousness_onset + rand_val(dp.infectiousness_onset_to_symptom_onset)

    # Calculate the time to severeness onset
    severeness_onset = symptom_onset + rand_val(dp.symptom_onset_to_severeness_onset)

    # Calculate the time to hospital admission
    hospital_admission = severeness_onset + rand_val(dp.severeness_onset_to_hospital_admission)

    # Calculate the time to hospital discharge
    hospital_discharge = hospital_admission + rand_val(dp.hospital_admission_to_hospital_discharge)

    # Calculate the time to recovery
    recovery = hospital_discharge + rand_val(dp.hospital_discharge_to_recovery)

    return DiseaseProgression(
        exposure = tick,
        infectiousness_onset = infectiousness_onset,
        symptom_onset = symptom_onset,
        severeness_onset = severeness_onset,
        hospital_admission = hospital_admission,
        hospital_discharge = hospital_discharge,
        recovery = recovery
    )
end