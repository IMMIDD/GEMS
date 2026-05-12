export FullImmunity, NoImmunity, ExponentialWaning, SigmoidalWaning


"""
    FullImmunity <: ImmunityProfile

The default `ImmunityProfile`. Grants full sterilising immunity (level 100)
as soon as either natural recovery or vaccination has occurred (i.e. the
respective acquired tick is in the past). Never wanes.
"""
struct FullImmunity <: ImmunityProfile end

@inline function calculate_immunity(profile::FullImmunity, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    has_natural = state.natural_acquired_tick != DEFAULT_TICK && tick >= state.natural_acquired_tick
    has_vaccine = state.vaccine_acquired_tick != DEFAULT_TICK && tick >= state.vaccine_acquired_tick
    return (has_natural || has_vaccine) ? Int8(100) : Int8(0)
end

@inline immunity_is_stable(profile::FullImmunity, state::ImmunityState, individual::Individual, tick::Int16) =
    (state.natural_acquired_tick != DEFAULT_TICK && tick >= state.natural_acquired_tick) ||
    (state.vaccine_acquired_tick != DEFAULT_TICK && tick >= state.vaccine_acquired_tick)

"""
    NoImmunity <: ImmunityProfile

An `ImmunityProfile` that grants no protection regardless of acquisition
history.
"""
struct NoImmunity <: ImmunityProfile end

@inline function calculate_immunity(profile::NoImmunity, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    return Int8(0)
end

@inline immunity_is_stable(profile::NoImmunity, state::ImmunityState, individual::Individual, tick::Int16) = true

"""
    ExponentialWaning <: ImmunityProfile

An `ImmunityProfile` that starts at full protection (100) at acquisition
and decays exponentially toward `floor` with the given `halflife` (in ticks).
When both natural and vaccine immunity exist, each source is treated as an
independent protective barrier and the levels are combined as 1 − (1−p)(1−q).

Vaccine-induced immunity optionally ramps from 0 to 100 over
`vaccine_buildup_duration` ticks before waning begins. Natural immunity
(post-recovery) always starts at full strength immediately.

Level at elapsed ticks e (after buildup):  `max(floor, 100 × 0.5^(e / halflife))`

# Fields
- `halflife::Float32`: Ticks for immunity to halve (default: 180).
- `floor::Int8`: Minimum immunity level after full waning (default: 0).
- `vaccine_buildup_duration::Int16`: Ticks from vaccination to peak immunity.
  During this window immunity rises linearly from 0 to 100. Default 0 (instant peak).
"""
@with_kw struct ExponentialWaning <: ImmunityProfile
    halflife::Float32 = 180.0f0
    floor::Int8 = Int8(0)
    vaccine_buildup_duration::Int16 = Int16(0)

    function ExponentialWaning(halflife, floor, vaccine_buildup_duration)
        halflife > 0 || throw(ArgumentError("halflife must be positive (got $halflife)."))
        0 <= floor <= 100 || throw(ArgumentError("floor must be in [0, 100] (got $floor)."))
        vaccine_buildup_duration >= 0 || throw(ArgumentError("vaccine_buildup_duration must be non-negative."))
        return new(Float32(halflife), Int8(floor), Int16(vaccine_buildup_duration))
    end
end

@inline function _exponential_level(profile::ExponentialWaning, acquired_tick::Int16, tick::Int16, buildup_duration::Int16 = Int16(0))::Int8
    tick < acquired_tick && return Int8(0)
    elapsed = tick - acquired_tick
    if elapsed < buildup_duration
        return Int8(clamp(round(Int, 100.0f0 * elapsed / buildup_duration), 0, 100))
    end
    waning_elapsed = Float32(elapsed - buildup_duration)
    level = 100.0f0 * 0.5f0^(waning_elapsed / profile.halflife)
    return Int8(max(Int(profile.floor), clamp(round(Int, level), 0, 100)))
end

@inline function calculate_immunity(profile::ExponentialWaning, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    nat_level = state.natural_acquired_tick != DEFAULT_TICK ?
        _exponential_level(profile, state.natural_acquired_tick, tick) : Int8(0)
    vac_level = state.vaccine_acquired_tick != DEFAULT_TICK ?
        _exponential_level(profile, state.vaccine_acquired_tick, tick, profile.vaccine_buildup_duration) : Int8(0)
    return Int8(clamp(round(Int, nat_level + vac_level - (Int(nat_level) * Int(vac_level)) / 100.0f0), 0, 100))
end


@inline function immunity_is_stable(profile::ExponentialWaning, state::ImmunityState, individual::Individual, tick::Int16)
    nat_pending = state.natural_acquired_tick != DEFAULT_TICK && tick < state.natural_acquired_tick
    vac_pending = state.vaccine_acquired_tick != DEFAULT_TICK && tick < state.vaccine_acquired_tick
    (nat_pending || vac_pending) && return false
    if state.vaccine_acquired_tick != DEFAULT_TICK
        vac_elapsed = tick - state.vaccine_acquired_tick
        vac_elapsed >= 0 && vac_elapsed < profile.vaccine_buildup_duration && return false
    end
    nat_level = state.natural_acquired_tick != DEFAULT_TICK ? _exponential_level(profile, state.natural_acquired_tick, tick) : Int8(0)
    vac_level = state.vaccine_acquired_tick != DEFAULT_TICK ? _exponential_level(profile, state.vaccine_acquired_tick, tick, profile.vaccine_buildup_duration) : Int8(0)
    return nat_level <= profile.floor && vac_level <= profile.floor
end





"""
    SigmoidalWaning <: ImmunityProfile
 
An `ImmunityProfile` based on the Hill (sigmoidal) equation. Immunity starts
at full protection (100) at acquisition and falls with a characteristic
S-shaped curve toward `floor`.  The `hill` coefficient controls the sharpness
of the drop: at `hill = 1` the decay is hyperbolic; larger
values produce an increasingly steep sigmoidal shoulder before the rapid fall.
When both natural and vaccine immunity exist, each source is treated as an
independent protective barrier and the levels are combined as 1 − (1−p)(1−q).

Vaccine-induced immunity optionally ramps from 0 to 100 over
`vaccine_buildup_duration` ticks before waning begins. Natural immunity
(post-recovery) always starts at full strength immediately.

Level at elapsed ticks e (after buildup):  `max(floor, 100 × halflife^n / (halflife^n + e^n))`

# Fields
- `halflife::Float32`: Ticks at which immunity reaches 50 (default: 180).
- `hill::Float32`: Hill coefficient controlling sigmoidal steepness (default: 3).
- `floor::Int8`: Minimum immunity level after full waning (default: 0).
- `vaccine_buildup_duration::Int16`: Ticks from vaccination to peak immunity.
  During this window immunity rises linearly from 0 to 100. Default 0 (instant peak).
"""
@with_kw struct SigmoidalWaning <: ImmunityProfile
    halflife::Float32 = 180.0f0
    hill::Float32 = 3.0f0
    floor::Int8 = Int8(0)
    vaccine_buildup_duration::Int16 = Int16(0)

    function SigmoidalWaning(halflife, hill, floor, vaccine_buildup_duration)
        halflife > 0 || throw(ArgumentError("halflife must be positive (got $halflife)."))
        hill > 0 || throw(ArgumentError("hill must be positive (got $hill)."))
        0 <= floor <= 100 || throw(ArgumentError("floor must be in [0, 100] (got $floor)."))
        vaccine_buildup_duration >= 0 || throw(ArgumentError("vaccine_buildup_duration must be non-negative."))
        return new(Float32(halflife), Float32(hill), Int8(floor), Int16(vaccine_buildup_duration))
    end
end
 
@inline function _sigmoidal_level(profile::SigmoidalWaning, acquired_tick::Int16, tick::Int16, buildup_duration::Int16 = Int16(0))::Int8
    tick < acquired_tick && return Int8(0)
    elapsed = tick - acquired_tick
    if elapsed < buildup_duration
        return Int8(clamp(round(Int, 100.0f0 * elapsed / buildup_duration), 0, 100))
    end
    waning_elapsed = Float32(elapsed - buildup_duration)
    hl_n = profile.halflife ^ profile.hill
    level = 100.0f0 * hl_n / (hl_n + waning_elapsed ^ profile.hill)
    return Int8(max(Int(profile.floor), clamp(round(Int, level), 0, 100)))
end
 
@inline function calculate_immunity(profile::SigmoidalWaning, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    nat_level = state.natural_acquired_tick != DEFAULT_TICK ?
        _sigmoidal_level(profile, state.natural_acquired_tick, tick) : Int8(0)
    vac_level = state.vaccine_acquired_tick != DEFAULT_TICK ?
        _sigmoidal_level(profile, state.vaccine_acquired_tick, tick, profile.vaccine_buildup_duration) : Int8(0)
    return Int8(clamp(round(Int, nat_level + vac_level - (Int(nat_level) * Int(vac_level)) / 100.0f0), 0, 100))
end
 
@inline function immunity_is_stable(profile::SigmoidalWaning, state::ImmunityState, individual::Individual, tick::Int16)
    nat_pending = state.natural_acquired_tick != DEFAULT_TICK && tick < state.natural_acquired_tick
    vac_pending = state.vaccine_acquired_tick != DEFAULT_TICK && tick < state.vaccine_acquired_tick
    (nat_pending || vac_pending) && return false
    if state.vaccine_acquired_tick != DEFAULT_TICK
        vac_elapsed = tick - state.vaccine_acquired_tick
        vac_elapsed >= 0 && vac_elapsed < profile.vaccine_buildup_duration && return false
    end
    nat_level = state.natural_acquired_tick != DEFAULT_TICK ? _sigmoidal_level(profile, state.natural_acquired_tick, tick) : Int8(0)
    vac_level = state.vaccine_acquired_tick != DEFAULT_TICK ? _sigmoidal_level(profile, state.vaccine_acquired_tick, tick, profile.vaccine_buildup_duration) : Int8(0)
    return nat_level <= profile.floor && vac_level <= profile.floor
end
