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

    function Symptomatic(; kwargs...)
        inner = Mild(; kwargs...)
        isnothing(inner.health) || throw(ArgumentError("Symptomatic takes no host health; use `Mild` instead."))
        return new(inner)
    end
end

# delegate to Mild
calculate_progression(individual::Individual, tick::Int16, dp::Symptomatic, rng::Xoshiro) =
    calculate_progression(individual, tick, dp.inner, rng)

# the positional and copy constructors `@with_kw` generated for `Mild` up to v1.3.4
Mild(exposure_to_infectiousness_onset, infectiousness_onset_to_symptom_onset, symptom_onset_to_recovery) =
    Mild(exposure_to_infectiousness_onset = exposure_to_infectiousness_onset,
        infectiousness_onset_to_symptom_onset = infectiousness_onset_to_symptom_onset,
        symptom_onset_to_recovery = symptom_onset_to_recovery)

Mild(m::Mild; kws...) = Mild(; merge((exposure_to_infectiousness_onset = m.exposure_to_infectiousness_onset,
    infectiousness_onset_to_symptom_onset = m.infectiousness_onset_to_symptom_onset,
    symptom_onset_to_recovery = m.symptom_onset_to_recovery, health = m.health), kws)...)
Mild(m::Mild, d::AbstractDict) = Mild(m; d...)
Mild(m::Mild, kv::Tuple{Symbol, Any}...) = Mild(m; kv...)
