export Critical

"""
    Critical <: ProgressionCategory

A disease progression category for individuals who develop critical symptoms.
`Critical` is the most severe disease tier: it nests a `critical` interval inside the
`severe` interval. Host-level care and outcomes (hospitalization, ICU, ventilation, death)
are not part of the disease progression; they are decided by the simulation's
`HealthProgression` from this tier's `severe`/`critical` demand.

**IMPORTANT**: The infectiousness onset must be at least 1 tick after exposure to avoid issues with immediate transmission.
Therefore, the calculation for infectiousness_onset includes a +1 offset.
The provided distributions should account for this offset to ensure realistic timing.
Providing, for example a Poisson(2) distribution would result in an average of 3 ticks from exposure to infectiousness onset (Poisson(2) + 1).

# Disease events
`exposure` -> `infectiousness_onset` -> `symptom_onset` -> `severeness_onset` -> `critical_onset` -> `critical_offset` -> `severeness_offset` -> `recovery`.

# Parameters
- `exposure_to_infectiousness_onset::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_onset_to_symptom_onset::Union{Distribution, Real}`: Time from becoming infectious to symptom onset.
- `symptom_onset_to_severeness_onset::Union{Distribution, Real}`: Time from symptom onset to severeness onset.
- `severeness_onset_to_critical_onset::Union{Distribution, Real}`: Time from severeness onset to critical onset.
- `critical_onset_to_critical_offset::Union{Distribution, Real}`: Time from critical onset to critical offset.
- `critical_offset_to_severeness_offset::Union{Distribution, Real}`: Time from critical offset to severeness offset.
- `severeness_offset_to_recovery::Union{Distribution, Real}`: Time from severeness offset to recovery.

# Example

```julia
dp = Critical(
    exposure_to_infectiousness_onset = Poisson(3),
    infectiousness_onset_to_symptom_onset = Poisson(1),
    symptom_onset_to_severeness_onset = Poisson(2),
    severeness_onset_to_critical_onset = Poisson(1),
    critical_onset_to_critical_offset = Poisson(5),
    critical_offset_to_severeness_offset = Poisson(2),
    severeness_offset_to_recovery = Poisson(7)
)
```

Host care for this tier may be embedded directly, either as a `CriticalHealthProfile` object or as flat
`CriticalHealthProfile` parameters (the latter is a convenience only; see `CriticalHealthProfile` for its defaults
and the cascading-off caveat):

```julia
dp = Critical(
    exposure_to_infectiousness_onset = Poisson(3),
    infectiousness_onset_to_symptom_onset = Poisson(1),
    symptom_onset_to_severeness_onset = Poisson(2),
    severeness_onset_to_critical_onset = Poisson(1),
    critical_onset_to_critical_offset = Poisson(5),
    critical_offset_to_severeness_offset = Poisson(2),
    severeness_offset_to_recovery = Poisson(7),
    hospital_probability = 0.9,
    icu_probability = 0.5
)
```
"""
mutable struct Critical <: ProgressionCategory
    exposure_to_infectiousness_onset::Union{Distribution, Real}
    infectiousness_onset_to_symptom_onset::Union{Distribution, Real}
    symptom_onset_to_severeness_onset::Union{Distribution, Real}
    severeness_onset_to_critical_onset::Union{Distribution, Real}
    critical_onset_to_critical_offset::Union{Distribution, Real}
    critical_offset_to_severeness_offset::Union{Distribution, Real}
    severeness_offset_to_recovery::Union{Distribution, Real}
    # embedded host care (build-time only; harvested into the global HealthProgression, ignored by
    # calculate_progression). Pass `care=CriticalHealthProfile(...)` or the CriticalHealthProfile params directly.
    care::Union{Nothing, HealthProfile}

    function Critical(;
        exposure_to_infectiousness_onset,
        infectiousness_onset_to_symptom_onset,
        symptom_onset_to_severeness_onset,
        severeness_onset_to_critical_onset,
        critical_onset_to_critical_offset,
        critical_offset_to_severeness_offset,
        severeness_offset_to_recovery,
        care::Union{Nothing, HealthProfile} = nothing,
        care_params...)

        if !isnothing(care)
            isempty(care_params) || throw(ArgumentError("provide either `care` or individual care parameters, not both"))
        elseif !isempty(care_params)
            for k in keys(care_params)
                k in fieldnames(CriticalHealthProfile) || throw(ArgumentError("unknown progression parameter `$k`"))
            end
            care = CriticalHealthProfile(; care_params...)
        end

        return new(exposure_to_infectiousness_onset, infectiousness_onset_to_symptom_onset,
            symptom_onset_to_severeness_onset, severeness_onset_to_critical_onset,
            critical_onset_to_critical_offset, critical_offset_to_severeness_offset,
            severeness_offset_to_recovery, care)
    end
end

_health_profile_type(::Type{Critical}) = CriticalHealthProfile

function calculate_progression(individual::Individual, tick::Int16, dp::Critical, rng::Xoshiro)

    # Calculate the time to infectiousness
    infectiousness_onset::Int16 = round(Int16, tick + 1 + _rand_val(dp.exposure_to_infectiousness_onset, rng))

    # Calculate the time to symptom onset
    symptom_onset::Int16 = round(Int16, infectiousness_onset + _rand_val(dp.infectiousness_onset_to_symptom_onset, rng))

    # Calculate the time to severeness onset
    severeness_onset::Int16 = round(Int16, symptom_onset + _rand_val(dp.symptom_onset_to_severeness_onset, rng))

    # Calculate the time to critical onset
    critical_onset::Int16 = round(Int16, severeness_onset + _rand_val(dp.severeness_onset_to_critical_onset, rng))

    # Calculate the time to critical offset
    critical_offset::Int16 = round(Int16, critical_onset + _rand_val(dp.critical_onset_to_critical_offset, rng))

    # Calculate the time to severeness offset
    severeness_offset::Int16 = round(Int16, critical_offset + _rand_val(dp.critical_offset_to_severeness_offset, rng))

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
