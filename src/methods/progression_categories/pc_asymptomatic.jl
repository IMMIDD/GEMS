@with_kw mutable struct TEMP_Asymptomatic <: ProgressionCategory
    exposure_to_infectiousness::Union{Distribution, Real}
    infectiousness_to_recovery::Union{Distribution, Real}
end


function calculate_progression(individual::Individual, tick::Int16, dp::TEMP_Asymptomatic)
    # Calculate the time to infectiousness
    infectiousness_onset = tick + rand(dp.exposure_to_infectiousness)

    # Calculate the time to recovery
    recovery = tick + rand(dp.infectiousness_to_recovery)

    return DiseaseProgression(
        exposure = tick,
        infectiousness_onset = infectiousness_onset,
        recovery = recovery
    )
end