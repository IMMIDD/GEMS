export Hospitalized

"""
    Hospitalized <: ProgressionCategory

Backwards-compatibility category for the pre-decoupling `Hospitalized` progression, which folded a
disease course and a (deterministic) ward stay into one category. On the decoupled model the disease
course is a plain severe tier and the ward stay is host care, so this category produces a
severe-shaped [`DiseaseProgression`](@ref) and hands its ward-care delays to the
[`LegacyHealthProgression`](@ref) harvest (always hospitalized, no ICU, no death). Prefer a modern
`Severe` category with an embedded `SevereHealthProfile` in new code.

# Parameters
- `exposure_to_infectiousness_onset::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_onset_to_symptom_onset::Union{Distribution, Real}`: Time from becoming infectious to symptom onset.
- `symptom_onset_to_severeness_onset::Union{Distribution, Real}`: Time from symptom onset to severeness onset.
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Ward admission delay after severeness onset.
- `hospital_admission_to_hospital_discharge::Union{Distribution, Real}`: Ward stay length.
- `hospital_discharge_to_severeness_offset::Union{Distribution, Real}`: Time from ward discharge to severeness offset.
- `severeness_offset_to_recovery::Union{Distribution, Real}`: Time from severeness offset to recovery.
"""
@with_kw mutable struct Hospitalized <: ProgressionCategory
    exposure_to_infectiousness_onset::Union{Distribution, Real}
    infectiousness_onset_to_symptom_onset::Union{Distribution, Real}
    symptom_onset_to_severeness_onset::Union{Distribution, Real}
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_hospital_discharge::Union{Distribution, Real}
    hospital_discharge_to_severeness_offset::Union{Distribution, Real}
    severeness_offset_to_recovery::Union{Distribution, Real}
end

function calculate_progression(individual::Individual, tick::Int16, dp::Hospitalized, rng::Xoshiro)

    # Calculate the time to infectiousness
    infectiousness_onset::Int16 = round(Int16, tick + 1 + _rand_val(dp.exposure_to_infectiousness_onset, rng))

    # Calculate the time to symptom onset
    symptom_onset::Int16 = round(Int16, infectiousness_onset + _rand_val(dp.infectiousness_onset_to_symptom_onset, rng))

    # Calculate the time to severeness onset
    severeness_onset::Int16 = round(Int16, symptom_onset + _rand_val(dp.symptom_onset_to_severeness_onset, rng))

    # the severeness window spans the old ward stay: admission delay + ward stay + discharge-to-offset
    severeness_offset::Int16 = round(Int16, severeness_onset +
        _rand_val(dp.severeness_onset_to_hospital_admission, rng) +
        _rand_val(dp.hospital_admission_to_hospital_discharge, rng) +
        _rand_val(dp.hospital_discharge_to_severeness_offset, rng))

    # Calculate the time to recovery
    recovery::Int16 = round(Int16, severeness_offset + _rand_val(dp.severeness_offset_to_recovery, rng))

    return DiseaseProgression(
        exposure = tick,
        infectiousness_onset = infectiousness_onset,
        symptom_onset = symptom_onset,
        severeness_onset = severeness_onset,
        severeness_offset = severeness_offset,
        recovery = recovery
    )
end
