export Symptomatic

"""
    Symptomatic <: ProgressionCategory

Backwards-compatibility category for the pre-rename `Symptomatic` progression, which was renamed to
[`Mild`](@ref). It accepts the same parameters and produces an identical disease progression, so old
configs and code keep working. Prefer `Mild` in new code.

# Parameters
- `exposure_to_infectiousness_onset::Union{Distribution, Real}`: Time from exposure to becoming infectious.
- `infectiousness_onset_to_symptom_onset::Union{Distribution, Real}`: Time from becoming infectious to symptom onset.
- `symptom_onset_to_recovery::Union{Distribution, Real}`: Time from symptom onset to recovery.
"""
mutable struct Symptomatic <: ProgressionCategory
    inner::Mild

    Symptomatic(; kwargs...) = new(Mild(; kwargs...))
end

# delegate to Mild
calculate_progression(individual::Individual, tick::Int16, dp::Symptomatic, rng::Xoshiro) =
    calculate_progression(individual, tick, dp.inner, rng)
