export ConstantInfectiousness, StagedInfectiousness


"""
    ConstantInfectiousness <: InfectiousnessProfile

The default `InfectiousnessProfile`. Produces a single fixed shedding level
throughout the entire infectious window `[infectiousness_onset, max(recovery, death))`,
regardless of disease stage.

# Fields
- `level::Int8`: Shedding level during the infectious window (0–100, default 100).
"""
struct ConstantInfectiousness <: InfectiousnessProfile
    level::Int8
    ConstantInfectiousness(; level::Integer = 100) = new(Int8(level))
end

@inline function calculate_infectiousness(profile::ConstantInfectiousness, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    end_t = max(state.recovery, state.death)
    return (state.infectiousness_onset >= 0 && state.infectiousness_onset <= tick < end_t) ? profile.level : Int8(0)
end


"""
    StagedInfectiousness

Per-pathogen mapping from disease stage to infectiousness level (`Int8`, 0–100).

# Fields
- `asymptomatic::Int8`: Infectious individuals who never become symptomatic
  (i.e. `state.symptom_onset < 0`).
- `presymptomatic::Int8`: Past `infectiousness_onset` but before `symptom_onset`,
  for individuals that *will* become symptomatic.
- `symptomatic::Int8`: Past `symptom_onset`, before any severe stage.
- `severe::Int8`: Past `severeness_onset`, before `severeness_offset`.
- `critical::Int8`: While in ICU (between `icu_admission` and `icu_discharge`).
"""
@with_kw struct StagedInfectiousness  <: InfectiousnessProfile
    asymptomatic::Int8 = Int8(50)
    presymptomatic::Int8 = Int8(50)
    symptomatic::Int8 = Int8(100)
    severe::Int8 = Int8(100)
    critical::Int8 = Int8(100)

    function StagedInfectiousness(asymptomatic, presymptomatic, symptomatic, severe, critical)
        for (nm, v) in (
            (:asymptomatic, asymptomatic), (:presymptomatic, presymptomatic),
            (:symptomatic, symptomatic),  (:severe, severe), (:critical, critical),
        )
            v < 0 && throw(ArgumentError("InfectiousnessProfile.$nm must be non-negative (got $v)."))
        end
        return new(Int8(asymptomatic), Int8(presymptomatic), Int8(symptomatic),
                   Int8(severe), Int8(critical))
    end
end

"""
    calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Compute the current infectiousness for a single (host, pathogen) infectionat tick `tick`, given the pathogen's `profile`, the infection's `state`,
the `individual` host, and an `rng` (unused by built-in profiles but available for user-defined extensions).

Returns `Int8(0)` if `tick` is outside the infectious window `[infectiousness_onset, max(recovery, death))`. 
Otherwise picks the profile field that matches the highest active disease stage at `tick`.
"""
@inline function calculate_infectiousness(profile::StagedInfectiousness, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    end_t = max(state.recovery, state.death)
    # outside the infectious window
    if state.infectiousness_onset < 0 || tick < state.infectiousness_onset || tick >= end_t
        return Int8(0)
    end

    # pick the highest stage active at tick
    if 0 <= state.icu_admission <= tick < state.icu_discharge
        return profile.critical
    end
    if 0 <= state.severeness_onset <= tick < state.severeness_offset
        return profile.severe
    end
    if 0 <= state.symptom_onset <= tick
        return profile.symptomatic
    end
    # infectious but not symptomatic
    return state.symptom_onset >= 0 ? profile.presymptomatic : profile.asymptomatic
end


"""
    calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16)::Int8

Fallback for `InfectiousnessProfile` that doesn'tick need an RNG.
"""
@inline function calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16)::Int8
    return calculate_infectiousness(profile, state, individual, tick, default_gems_rng())
end