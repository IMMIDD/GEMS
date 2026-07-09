export LegacyCritical

"""
    LegacyCritical <: ProgressionCategory

Backwards-compatibility category for the pre-decoupling `Critical` progression (deterministic
hospital -> ICU, probabilistic death anchored at ICU admission). The `Critical` name now denotes a
pure disease tier, so this reproduces the old coupled behavior instead: it produces a critical-shaped
[`DiseaseProgression`](@ref) whose `critical_onset` anchors at the old hospital admission, and hands
its care/death delays to the [`LegacyHealthProgression`](@ref) harvest. Config files keep using the
name `Critical` (rerouted here during parsing); Julia code must call `LegacyCritical` directly.

Reproduction is distributional, not bit-exact: disease and health now roll in separate passes.

# Parameters
- `exposure_to_infectiousness_onset::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_onset_to_symptom_onset::Union{Distribution, Real}`: Time from becoming infectious to symptom onset.
- `symptom_onset_to_severeness_onset::Union{Distribution, Real}`: Time from symptom onset to severeness onset.
- `severeness_onset_to_hospital_admission::Union{Distribution, Real}`: Hospital admission delay after severeness onset.
- `hospital_admission_to_icu_admission::Union{Distribution, Real}`: ICU admission delay after hospital admission.
- `death_probability::Real`: Probability of death (must be between 0 and 1).
- `icu_admission_to_icu_discharge::Union{Distribution, Real}`: ICU stay length (recovering).
- `icu_discharge_to_hospital_discharge::Union{Distribution, Real}`: Hospital stay after ICU discharge (recovering).
- `hospital_discharge_to_severeness_offset::Union{Distribution, Real}`: Time from hospital discharge to severeness offset.
- `severeness_offset_to_recovery::Union{Distribution, Real}`: Time from severeness offset to recovery.
- `icu_admission_to_death::Union{Distribution, Real}`: Death delay after ICU admission (dying).
"""
@with_kw mutable struct LegacyCritical <: ProgressionCategory
    exposure_to_infectiousness_onset::Union{Distribution, Real}
    infectiousness_onset_to_symptom_onset::Union{Distribution, Real}
    symptom_onset_to_severeness_onset::Union{Distribution, Real}
    severeness_onset_to_hospital_admission::Union{Distribution, Real}
    hospital_admission_to_icu_admission::Union{Distribution, Real}
    death_probability::Real
    icu_admission_to_icu_discharge::Union{Distribution, Real}
    icu_discharge_to_hospital_discharge::Union{Distribution, Real}
    hospital_discharge_to_severeness_offset::Union{Distribution, Real}
    severeness_offset_to_recovery::Union{Distribution, Real}
    icu_admission_to_death::Union{Distribution, Real}
end

function calculate_progression(individual::Individual, tick::Int16, dp::LegacyCritical, rng::Xoshiro)

    # Calculate the time to infectiousness
    infectiousness_onset::Int16 = round(Int16, tick + 1 + _rand_val(dp.exposure_to_infectiousness_onset, rng))

    # Calculate the time to symptom onset
    symptom_onset::Int16 = round(Int16, infectiousness_onset + _rand_val(dp.infectiousness_onset_to_symptom_onset, rng))

    # Calculate the time to severeness onset
    severeness_onset::Int16 = round(Int16, symptom_onset + _rand_val(dp.symptom_onset_to_severeness_onset, rng))

    # critical onset anchors at the old hospital admission (so the harvested health profile maps identity)
    critical_onset::Int16 = round(Int16, severeness_onset + _rand_val(dp.severeness_onset_to_hospital_admission, rng))

    # the critical window spans the old hospital stay: admission -> ICU -> ICU discharge -> hospital discharge
    critical_offset::Int16 = round(Int16, critical_onset +
        _rand_val(dp.hospital_admission_to_icu_admission, rng) +
        _rand_val(dp.icu_admission_to_icu_discharge, rng) +
        _rand_val(dp.icu_discharge_to_hospital_discharge, rng))

    # Calculate the time to severeness offset
    severeness_offset::Int16 = round(Int16, critical_offset + _rand_val(dp.hospital_discharge_to_severeness_offset, rng))

    # Calculate the time to recovery
    recovery::Int16 = round(Int16, severeness_offset + _rand_val(dp.severeness_offset_to_recovery, rng))

    return DiseaseProgression(
        exposure = tick,
        infectiousness_onset = infectiousness_onset,
        symptom_onset = symptom_onset,
        severeness_onset = severeness_onset,
        critical_onset = critical_onset,
        critical_offset = critical_offset,
        severeness_offset = severeness_offset,
        recovery = recovery
    )
end
