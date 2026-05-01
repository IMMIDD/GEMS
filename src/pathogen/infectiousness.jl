export ConstantInfectiousness, StagedInfectiousness
export infectiousness


"""
    ConstantInfectiousness <: InfectiousnessProfile

The default `InfectiousnessProfile`. Produces a single fixed shedding level
throughout the entire infectious window `[infectiousness_onset, max(recovery, death))`,
regardless of disease stage.

# Fields
- `level::Int8`: Shedding level during the infectious window (0–127, default 100).
"""
struct ConstantInfectiousness <: InfectiousnessProfile
    level::Int8
    ConstantInfectiousness(; level::Integer = 100) = new(Int8(level))
end

@inline function infectiousness(p::ConstantInfectiousness, state::InfectionState, t::Int16)::Int8
    end_t = max(state.recovery, state.death)
    return (state.infectiousness_onset >= 0 && state.infectiousness_onset <= t < end_t) ? p.level : Int8(0)
end


"""
    StagedInfectiousness

Per-pathogen mapping from disease stage to infectiousness level (`Int8`, 0–127).

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

    function InfectiousnessProfile(asymptomatic, presymptomatic, symptomatic, severe, critical)
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
    infectiousness(profile::InfectiousnessProfile, state::InfectionState, t::Int16)::Int8

Compute the current infectiousness for a single (host, pathogen) infection
at tick `t`, given the pathogen's `profile` and the infection's `state`.

Returns `Int8(0)` if `t` is outside the infectious window
`[infectiousness_onset, max(recovery, death))`. Otherwise picks the
profile field that matches the highest active disease stage at `t`.

"""
@inline function infectiousness(profile::StagedInfectiousness, state::InfectionState, t::Int16)::Int8
    end_t = max(state.recovery, state.death)
    # outside the infectious window
    if state.infectiousness_onset < 0 || t < state.infectiousness_onset || t >= end_t
        return Int8(0)
    end

    # pick the highest stage active at t
    if 0 <= state.icu_admission <= t < state.icu_discharge
        return profile.critical
    end
    if 0 <= state.severeness_onset <= t < state.severeness_offset
        return profile.severe
    end
    if 0 <= state.symptom_onset <= t
        return profile.symptomatic
    end
    # infectious but not (yet?) symptomatic
    return state.symptom_onset >= 0 ? profile.presymptomatic : profile.asymptomatic
end