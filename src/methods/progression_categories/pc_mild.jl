@with_kw mutable struct TEMP_Mild <: ProgressionCategory
    exposure_to_infectiousness::Union{Distribution, Real}
    infectiousness_to_symptom_onset::Union{Distribution, Real}
    symptom_onset_to_recovery::Union{Distribution, Real}
end


function calculate_progression(individual::Individual, tick::Int16, dp::TEMP_Mild)
    # Calculate the time to infectiousness
    infectiousness_onset = tick + rand(dp.exposure_to_infectiousness)

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