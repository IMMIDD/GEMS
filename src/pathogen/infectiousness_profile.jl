export ConstantInfectiousness, StagedInfectiousness, BetaInfectiousness


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
    end_t = state.recovery
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
- `critical::Int8`: While critically ill (between `critical_onset` and `critical_offset`).
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

Returns `Int8(0)` if `tick` is outside the infectious window `[infectiousness_onset, recovery)`.
Otherwise picks the profile field that matches the highest active disease stage at `tick`.
"""
@inline function calculate_infectiousness(profile::StagedInfectiousness, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    end_t = state.recovery
    # outside the infectious window
    if state.infectiousness_onset < 0 || tick < state.infectiousness_onset || tick >= end_t
        return Int8(0)
    end

    return _stage_value(state, tick, profile.asymptomatic, profile.presymptomatic,
        profile.symptomatic, profile.severe, profile.critical)
end

"""
    _stage_value(state::InfectionState, tick::Int16, asym, presym, sym, sev, crit)

Returns whichever of the five arguments corresponds to the highest disease stage active at
`tick`. Generic over the value type so that stage levels and stage factors resolve identically.
Assumes `tick` is already known to lie inside the infectious window.
"""
@inline function _stage_value(state::InfectionState, tick::Int16, asym, presym, sym, sev, crit)
    0 <= state.critical_onset <= tick < state.critical_offset && return crit
    0 <= state.severeness_onset <= tick < state.severeness_offset && return sev
    0 <= state.symptom_onset <= tick && return sym
    # infectious but not symptomatic
    return state.symptom_onset >= 0 ? presym : asym
end


"""
    BetaInfectiousness

Shedding that rises to a peak `time_to_peak` ticks after infectiousness onset and declines to
zero at recovery, following the kernel of a beta distribution fitted to the infection's own
infectious window. The peak stays at the same tick however long the infection lasts; a longer
infection stretches the decay. Stage factors scale the curve by the highest active disease stage.

# Fields
- `time_to_peak::Float64`: Ticks from infectiousness onset to peak shedding (default 2).
  An infection that ends earlier rises monotonically and is cut off before the peak.
- `concentration::Float64`: Beta's `α + β` (default 7, must be > 2). Larger values make the
  curve narrower relative to the infectious window.
- `level::Int8`: Infectiousness at the peak (0–100, default 100).
- `asymptomatic_factor::Float64`, `presymptomatic_factor::Float64`, `symptomatic_factor::Float64`,
  `severe_factor::Float64`, `critical_factor::Float64`: Per-stage multipliers (default 1.0).
  Stages are as defined for `StagedInfectiousness`.
"""
@with_kw struct BetaInfectiousness <: InfectiousnessProfile
    time_to_peak::Float64 = 2.0
    concentration::Float64 = 7.0
    level::Int8 = Int8(100)
    asymptomatic_factor::Float64 = 1.0
    presymptomatic_factor::Float64 = 1.0
    symptomatic_factor::Float64 = 1.0
    severe_factor::Float64 = 1.0
    critical_factor::Float64 = 1.0

    function BetaInfectiousness(time_to_peak, concentration, level, asymptomatic_factor,
            presymptomatic_factor, symptomatic_factor, severe_factor, critical_factor)
        time_to_peak > 0 || throw(ArgumentError("BetaInfectiousness.time_to_peak must be positive (got $time_to_peak)."))
        concentration > 2 || throw(ArgumentError("BetaInfectiousness.concentration must be greater than 2 (got $concentration)."))
        0 <= level <= 100 || throw(ArgumentError("BetaInfectiousness.level must be between 0 and 100 (got $level)."))
        for (nm, v) in (
            (:asymptomatic_factor, asymptomatic_factor), (:presymptomatic_factor, presymptomatic_factor),
            (:symptomatic_factor, symptomatic_factor), (:severe_factor, severe_factor),
            (:critical_factor, critical_factor),
        )
            v < 0 && throw(ArgumentError("BetaInfectiousness.$nm must be non-negative (got $v)."))
        end
        return new(Float64(time_to_peak), Float64(concentration), Int8(level),
            Float64(asymptomatic_factor), Float64(presymptomatic_factor), Float64(symptomatic_factor),
            Float64(severe_factor), Float64(critical_factor))
    end
end

@inline function calculate_infectiousness(profile::BetaInfectiousness, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    onset = state.infectiousness_onset
    end_t = state.recovery
    if onset < 0 || tick < onset || tick >= end_t
        return Int8(0)
    end

    duration = Float64(end_t - onset)
    duration <= 0 && return Int8(0)

    u = (tick - onset) / duration
    # an infection that ends before the peak is capped at m = 1
    m = min(profile.time_to_peak / duration, 1.0)

    # solve the beta shape parameters for a mode at `m`, holding `α + β` fixed so that the curve
    # spans the whole window rather than keeping a fixed width in ticks
    spread = profile.concentration - 2.0
    a = m * spread + 1.0
    b = (1.0 - m) * spread + 1.0

    # peak-normalised, so the beta normalising constant cancels out
    shape = (u / m)^(a - 1.0) * ((1.0 - u) / (1.0 - m))^(b - 1.0)

    factor = _stage_value(state, tick, profile.asymptomatic_factor, profile.presymptomatic_factor,
        profile.symptomatic_factor, profile.severe_factor, profile.critical_factor)

    return Int8(clamp(round(Int, profile.level * shape * factor), 0, 100))
end


"""
    calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16)::Int8

Fallback for `InfectiousnessProfile` that doesn'tick need an RNG.
"""
@inline function calculate_infectiousness(profile::InfectiousnessProfile, state::InfectionState, individual::Individual, tick::Int16)::Int8
    return calculate_infectiousness(profile, state, individual, tick, default_gems_rng())
end