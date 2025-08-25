"""
    Critical <: ProgressionCategory

A disease progression category for individuals who develop critical symptoms requiring ICU care, with a probability of death.

**IMPORTANT**: The infectiousness onset must be at least 1 tick after exposure to avoid issues with immediate transmission.
Therefore, the calculation for infectiousness_onset includes a +1 offset.
The provided distributions should account for this offset to ensure realistic timing.
Providing, for example a Poisson(2) distribution would result in an average of 3 ticks from exposure to infectiousness onset (Poisson(2) + 1).

# Disease events
`exposure` -> `infectiousness_onset` -> `symptom_onset` -> `severeness_onset` -> `hospital_admission` -> `icu_admission` -> (`icu_discharge` -> `hospital_discharge` -> `recovery`) OR (`death`).

# Parameters
- `exposure_to_infectiousness::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_to_symptom_onset::Union{Distribution, Real}`: Time from becoming infectious to symptom onset.
- `symptom_onset_to_severeness_onset::Union{Distribution, Real}`: Time from symptom onset to severeness onset.
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Time from severeness onset to hospital admission.
- `hospital_admission_to_icu_admission::Union{Distribution, Real}`: Time from hospital admission to ICU admission.
- `death_probability::Real`: Probability of death for individuals in this progression category. Must be between 0 and 1.
- `icu_admission_to_icu_discharge::Union{Distribution, Real}`: Time from ICU admission to ICU discharge (if recovering).
- `icu_discharge_to_hospital_discharge::Union{Distribution, Real}`: Time from ICU discharge to hospital discharge (if recovering).
- `hospital_discharge_to_recovery::Union{Distribution, Real}`: Time from hospital discharge to recovery (if recovering).
- `icu_admission_to_death::Union{Distribution, Real}`: Time from ICU admission to death (if dying).

# Example

The code below instantiates a `Critical` progression category with specific distributions for the time intervals and a death probability.

```julia
dp = Critical(
    exposure_to_infectiousness = Poisson(3),
    infectiousness_to_symptom_onset = Poisson(1),
    symptom_onset_to_severeness_onset = Poisson(2),
    severeness_onset_to_hospital_admission = Poisson(1),
    hospital_admission_to_icu_admission = Poisson(1),
    death_probability = 0.3,
    icu_admission_to_icu_discharge = Poisson(10),
    icu_discharge_to_hospital_discharge = Poisson(5),
    hospital_discharge_to_recovery = Poisson(7),
    icu_admission_to_death = Poisson(10)
)
```
"""
mutable struct Critical <: ProgressionCategory
    exposure_to_infectiousness::Union{Distribution, Real}
    infectiousness_to_symptom_onset::Union{Distribution, Real}
    symptom_onset_to_severeness_onset::Union{Distribution, Real}
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_icu_admission::Union{Distribution, Real}

    # death probability
    death_probability::Real

    # if recovering
    icu_admission_to_icu_discharge::Union{Distribution, Real}
    icu_discharge_to_hospital_discharge::Union{Distribution, Real}
    hospital_discharge_to_recovery::Union{Distribution, Real}

    # if dying
    icu_admission_to_death::Union{Distribution, Real}

    function Critical(; death_probability, kwargs...)
        !(0.0 .<= death_probability .<= 1.0) && throw(ArgumentError("death_probability must be between 0 and 1."))
        
        return new(
            kwargs...,
            death_probability = death_probability
        )
    end
end

function calculate_progression(individual::Individual, tick::Int16, dp::Critical)
    # Calculate the time to infectiousness
    infectiousness_onset = tick + Int16(1) + rand_val(dp.exposure_to_infectiousness)

    # Calculate the time to symptom onset
    symptom_onset = infectiousness_onset + rand_val(dp.infectiousness_to_symptom_onset)

    # Calculate the time to severeness onset
    severeness_onset = symptom_onset + rand_val(dp.symptom_onset_to_severeness_onset)

    # Calculate the time to hospital admission
    hospital_admission = severeness_onset + rand_val(dp.severeness_onset_to_hospital_admission)

    # Calculate the time to ICU admission
    icu_admission = hospital_admission + rand_val(dp.hospital_admission_to_icu_admission)

    # Decide recovery or death
    # If individual dies
    if rand() <= dp.death_probability
        # Calculate the time to death
        death = icu_admission + rand_val(dp.icu_admission_to_death)

        return DiseaseProgression(
            exposure = tick,
            infectiousness_onset = infectiousness_onset,
            symptom_onset = symptom_onset,
            severeness_onset = severeness_onset,
            hospital_admission = hospital_admission,
            icu_admission = icu_admission,
            # set icu and hospital discharge to death time
            icu_discharge = death,
            hospital_discharge = death,
            death = death
        )
    end

    # If individual recovers
    # Calculate the time to ICU discharge
    icu_discharge = icu_admission + rand_val(dp.icu_admission_to_icu_discharge)

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
        icu_admission = icu_admission,
        icu_discharge = icu_discharge,
        hospital_discharge = hospital_discharge,
        recovery = recovery
    )
end