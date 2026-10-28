export FullImmunity, NoImmunity, ExponentialWaning, SigmoidalWaning


"""
    FullImmunity <: ImmunityProfile

The default `ImmunityProfile`. Immunity never wanes: natural immunity is full (level 100) from recovery, and a
vaccine dose rises to the vaccine's `peak` over its `buildup_duration` (default 0) and stays there.
"""
struct FullImmunity <: ImmunityProfile end

# a dose's level: ramps from 0 to `peak` over the buildup, then stays at `peak`
@inline function _full_level(acquired_tick::Int16, tick::Int16, buildup_duration::Int16, peak::Int8)::Int8
    tick < acquired_tick && return Int8(0)
    elapsed = tick - acquired_tick
    elapsed < buildup_duration && return Int8(clamp(round(Int, Float32(peak) * elapsed / buildup_duration), 0, 100))
    return peak
end

# during a dose's buildup, the vaccine level is at least what the previous dose still gives
@inline function _full_vaccine_level(state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16)::Int8
    buildup = max(vaccine_protection.buildup_duration, Int16(0))
    peak = vaccine_protection.peak
    current = _full_level(state.vaccine_acquired_tick, tick, buildup, peak)
    elapsed = tick - state.vaccine_acquired_tick
    (0 <= elapsed < buildup && state.prev_dose_interval != 0x00) || return current
    prev_tick = Int(state.vaccine_acquired_tick) - Int(previous_dose_interval(state))
    prev_tick > typemin(Int16) || return current
    return max(current, _full_level(Int16(prev_tick), tick, buildup, peak))
end

@inline function calculate_immunity(profile::FullImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    # full natural immunity combined with any vaccine level is full
    natural_immunity_active(state, tick) && return Int8(100)
    return vaccine_immunity_recorded(state) ? _full_vaccine_level(state, vaccine_protection, tick) : Int8(0)
end

@inline calculate_immunity(profile::FullImmunity, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_immunity(profile, state, VaccineProtection(), individual, tick, rng)

"""
    NoImmunity <: ImmunityProfile

An `ImmunityProfile` that grants no protection regardless of acquisition
history.
"""
struct NoImmunity <: ImmunityProfile end

@inline function calculate_immunity(profile::NoImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    return Int8(0)
end

@inline calculate_immunity(profile::NoImmunity, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_immunity(profile, state, VaccineProtection(), individual, tick, rng)

"""
    ExponentialWaning <: ImmunityProfile

An `ImmunityProfile` that starts at a peak at acquisition and decays
exponentially toward `floor` with the given `halflife` (in ticks): natural
immunity at `natural_peak`, a vaccine dose at the vaccine's `peak`.
When both natural and vaccine immunity exist, each source is treated as an
independent protective barrier and the levels are combined as 1 − (1−p)(1−q).

Vaccine-induced immunity ramps from 0 to its peak over the vaccine's
`buildup_duration`, or `vaccine_buildup_duration` if the vaccine sets none,
before waning begins. Natural immunity (post-recovery) starts at its peak immediately.

Level at elapsed ticks e (after buildup):  `max(min(floor, peak), peak × 0.5^(e / halflife))`

# Fields
- `halflife::Float32`: Ticks for immunity to halve (default: 180).
- `floor::Int8`: Minimum immunity level after full waning, at most the source's peak (default: 0).
- `vaccine_buildup_duration::Int16`: Deprecated, set `buildup_duration` on the vaccine. Ticks from vaccination to peak
  immunity for vaccines that set none (default: 0).
- `natural_peak::Int8`: Level of natural immunity at recovery (default: 100).
"""
@with_kw struct ExponentialWaning <: ImmunityProfile
    halflife::Float32 = 180.0f0
    floor::Int8 = Int8(0)
    vaccine_buildup_duration::Int16 = Int16(0)
    natural_peak::Int8 = Int8(100)

    function ExponentialWaning(halflife, floor, vaccine_buildup_duration, natural_peak)
        halflife > 0 || throw(ArgumentError("halflife must be positive (got $halflife)."))
        0 <= floor <= 100 || throw(ArgumentError("floor must be in [0, 100] (got $floor)."))
        vaccine_buildup_duration >= 0 || throw(ArgumentError("vaccine_buildup_duration must be non-negative."))
        vaccine_buildup_duration == 0 ||
            Base.depwarn("ExponentialWaning(vaccine_buildup_duration) is deprecated; set buildup_duration on the Vaccine.", :ExponentialWaning)
        0 <= natural_peak <= 100 || throw(ArgumentError("natural_peak must be in [0, 100] (got $natural_peak)."))
        return new(Float32(halflife), Int8(floor), Int16(vaccine_buildup_duration), Int8(natural_peak))
    end
end

"""
    ExponentialWaning(halflife, floor, vaccine_buildup_duration)

Positional constructor with the default `natural_peak`.
"""
ExponentialWaning(halflife, floor, vaccine_buildup_duration) =
    ExponentialWaning(halflife, floor, vaccine_buildup_duration, 100)

@inline function _exponential_level(profile::ExponentialWaning, acquired_tick::Int16, tick::Int16, buildup_duration::Int16, peak::Int8)::Int8
    tick < acquired_tick && return Int8(0)
    elapsed = tick - acquired_tick
    if elapsed < buildup_duration
        return Int8(clamp(round(Int, Float32(peak) * elapsed / buildup_duration), 0, 100))
    end
    waning_elapsed = Float32(elapsed - buildup_duration)
    level = Float32(peak) * 0.5f0^(waning_elapsed / profile.halflife)
    return Int8(max(min(Int(profile.floor), Int(peak)), clamp(round(Int, level), 0, 100)))
end

# during a dose's buildup, the vaccine level is at least what the previous dose still gives
@inline function _exponential_vaccine_level(profile::ExponentialWaning, state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16)::Int8
    buildup = vaccine_protection.buildup_duration < 0 ? profile.vaccine_buildup_duration : vaccine_protection.buildup_duration
    peak = vaccine_protection.peak
    current = _exponential_level(profile, state.vaccine_acquired_tick, tick, buildup, peak)
    elapsed = tick - state.vaccine_acquired_tick
    (0 <= elapsed < buildup && state.prev_dose_interval != 0x00) || return current
    prev_tick = Int(state.vaccine_acquired_tick) - Int(previous_dose_interval(state))
    prev_tick > typemin(Int16) || return current
    return max(current, _exponential_level(profile, Int16(prev_tick), tick, buildup, peak))
end

@inline function calculate_immunity(profile::ExponentialWaning, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    nat_level = natural_immunity_recorded(state) ?
        _exponential_level(profile, state.natural_acquired_tick, tick, Int16(0), profile.natural_peak) : Int8(0)
    vac_level = vaccine_immunity_recorded(state) ?
        _exponential_vaccine_level(profile, state, vaccine_protection, tick) : Int8(0)
    return Int8(clamp(round(Int, Int(nat_level) + Int(vac_level) - (Int(nat_level) * Int(vac_level)) / 100.0f0), 0, 100))
end

@inline calculate_immunity(profile::ExponentialWaning, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_immunity(profile, state, VaccineProtection(), individual, tick, rng)



"""
    SigmoidalWaning <: ImmunityProfile
 
An `ImmunityProfile` based on the Hill (sigmoidal) equation. Immunity starts
at a peak at acquisition (natural immunity at `natural_peak`, a vaccine dose at
the vaccine's `peak`) and falls with a characteristic
S-shaped curve toward `floor`.  The `hill` coefficient controls the sharpness
of the drop: at `hill = 1` the decay is hyperbolic; larger
values produce an increasingly steep sigmoidal shoulder before the rapid fall.
When both natural and vaccine immunity exist, each source is treated as an
independent protective barrier and the levels are combined as 1 − (1−p)(1−q).

Vaccine-induced immunity ramps from 0 to its peak over the vaccine's
`buildup_duration`, or `vaccine_buildup_duration` if the vaccine sets none,
before waning begins. Natural immunity (post-recovery) starts at its peak immediately.

Level at elapsed ticks e (after buildup):  `max(min(floor, peak), peak × halflife^n / (halflife^n + e^n))`

# Fields
- `halflife::Float32`: Ticks at which immunity reaches half its peak (default: 180).
- `hill::Float32`: Hill coefficient controlling sigmoidal steepness (default: 3).
- `floor::Int8`: Minimum immunity level after full waning, at most the source's peak (default: 0).
- `vaccine_buildup_duration::Int16`: Deprecated, set `buildup_duration` on the vaccine. Ticks from vaccination to peak
  immunity for vaccines that set none (default: 0).
- `natural_peak::Int8`: Level of natural immunity at recovery (default: 100).
"""
@with_kw struct SigmoidalWaning <: ImmunityProfile
    halflife::Float32 = 180.0f0
    hill::Float32 = 3.0f0
    floor::Int8 = Int8(0)
    vaccine_buildup_duration::Int16 = Int16(0)
    natural_peak::Int8 = Int8(100)

    function SigmoidalWaning(halflife, hill, floor, vaccine_buildup_duration, natural_peak)
        halflife > 0 || throw(ArgumentError("halflife must be positive (got $halflife)."))
        hill > 0 || throw(ArgumentError("hill must be positive (got $hill)."))
        0 <= floor <= 100 || throw(ArgumentError("floor must be in [0, 100] (got $floor)."))
        vaccine_buildup_duration >= 0 || throw(ArgumentError("vaccine_buildup_duration must be non-negative."))
        vaccine_buildup_duration == 0 ||
            Base.depwarn("SigmoidalWaning(vaccine_buildup_duration) is deprecated; set buildup_duration on the Vaccine.", :SigmoidalWaning)
        0 <= natural_peak <= 100 || throw(ArgumentError("natural_peak must be in [0, 100] (got $natural_peak)."))
        return new(Float32(halflife), Float32(hill), Int8(floor), Int16(vaccine_buildup_duration), Int8(natural_peak))
    end
end

"""
    SigmoidalWaning(halflife, hill, floor, vaccine_buildup_duration)

Positional constructor with the default `natural_peak`.
"""
SigmoidalWaning(halflife, hill, floor, vaccine_buildup_duration) =
    SigmoidalWaning(halflife, hill, floor, vaccine_buildup_duration, 100)

@inline function _sigmoidal_level(profile::SigmoidalWaning, acquired_tick::Int16, tick::Int16, buildup_duration::Int16, peak::Int8)::Int8
    tick < acquired_tick && return Int8(0)
    elapsed = tick - acquired_tick
    if elapsed < buildup_duration
        return Int8(clamp(round(Int, Float32(peak) * elapsed / buildup_duration), 0, 100))
    end
    waning_elapsed = Float32(elapsed - buildup_duration)
    hl_n = profile.halflife ^ profile.hill
    level = Float32(peak) * hl_n / (hl_n + waning_elapsed ^ profile.hill)
    return Int8(max(min(Int(profile.floor), Int(peak)), clamp(round(Int, level), 0, 100)))
end

# during a dose's buildup, the vaccine level is at least what the previous dose still gives
@inline function _sigmoidal_vaccine_level(profile::SigmoidalWaning, state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16)::Int8
    buildup = vaccine_protection.buildup_duration < 0 ? profile.vaccine_buildup_duration : vaccine_protection.buildup_duration
    peak = vaccine_protection.peak
    current = _sigmoidal_level(profile, state.vaccine_acquired_tick, tick, buildup, peak)
    elapsed = tick - state.vaccine_acquired_tick
    (0 <= elapsed < buildup && state.prev_dose_interval != 0x00) || return current
    prev_tick = Int(state.vaccine_acquired_tick) - Int(previous_dose_interval(state))
    prev_tick > typemin(Int16) || return current
    return max(current, _sigmoidal_level(profile, Int16(prev_tick), tick, buildup, peak))
end

@inline function calculate_immunity(profile::SigmoidalWaning, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    nat_level = natural_immunity_recorded(state) ?
        _sigmoidal_level(profile, state.natural_acquired_tick, tick, Int16(0), profile.natural_peak) : Int8(0)
    vac_level = vaccine_immunity_recorded(state) ?
        _sigmoidal_vaccine_level(profile, state, vaccine_protection, tick) : Int8(0)
    return Int8(clamp(round(Int, Int(nat_level) + Int(vac_level) - (Int(nat_level) * Int(vac_level)) / 100.0f0), 0, 100))
end

@inline calculate_immunity(profile::SigmoidalWaning, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_immunity(profile, state, VaccineProtection(), individual, tick, rng)
