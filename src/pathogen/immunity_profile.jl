export FullImmunity, NoImmunity, ExponentialWaning
export calculate_immunity


"""
    FullImmunity <: ImmunityProfile

The default `ImmunityProfile`. Grants full sterilising immunity (level 100)
as soon as either natural recovery or vaccination has occurred (i.e. the
respective acquired tick is in the past). Never wanes.
"""
struct FullImmunity <: ImmunityProfile end

@inline function calculate_immunity(::FullImmunity, state::ImmunityState, tick::Int16)::Int8
    has_natural = state.natural_acquired_tick != DEFAULT_TICK && tick >= state.natural_acquired_tick
    has_vaccine = state.vaccine_acquired_tick != DEFAULT_TICK && tick >= state.vaccine_acquired_tick
    return (has_natural || has_vaccine) ? Int8(100) : Int8(0)
end

@inline immunity_is_stable(::FullImmunity, state::ImmunityState, tick::Int16) =
    (state.natural_acquired_tick != DEFAULT_TICK && tick >= state.natural_acquired_tick) ||
    (state.vaccine_acquired_tick != DEFAULT_TICK && tick >= state.vaccine_acquired_tick)

"""
    NoImmunity <: ImmunityProfile

An `ImmunityProfile` that grants no protection regardless of acquisition
history.
"""
struct NoImmunity <: ImmunityProfile end

@inline function calculate_immunity(::NoImmunity, ::ImmunityState, ::Int16)::Int8
    return Int8(0)
end

@inline immunity_is_stable(::NoImmunity, ::ImmunityState, ::Int16) = true

"""
    ExponentialWaning <: ImmunityProfile

An `ImmunityProfile` that starts at full protection (100) at acquisition
and decays exponentially toward `floor` with the given `halflife` (in ticks).
When both natural and vaccine immunity exist, the level from each source is
computed independently and the max is returned.

Level at elapsed ticks e:  `max(floor, 100 × 0.5^(e / halflife))`

# Fields
- `halflife::Float32`: Ticks for immunity to halve (default: 180).
- `floor::Int8`: Minimum immunity level after full waning (default: 0).
"""
@with_kw struct ExponentialWaning <: ImmunityProfile
    halflife::Float32 = 180.0f0
    floor::Int8 = Int8(0)

    function ExponentialWaning(halflife, floor)
        halflife > 0 || throw(ArgumentError("halflife must be positive (got $halflife)."))
        0 <= floor <= 100 || throw(ArgumentError("floor must be in [0, 100] (got $floor)."))
        return new(Float32(halflife), Int8(floor))
    end
end

@inline function _waning_level(p::ExponentialWaning, acquired_tick::Int16, tick::Int16)::Int8
    tick < acquired_tick && return Int8(0)
    elapsed = Float32(tick - acquired_tick)
    level = 100.0f0 * 0.5f0^(elapsed / p.halflife)
    return Int8(max(Int(p.floor), clamp(round(Int, level), 0, 100)))
end

@inline function calculate_immunity(p::ExponentialWaning, state::ImmunityState, tick::Int16)::Int8
    nat_level = state.natural_acquired_tick != DEFAULT_TICK ?
        _waning_level(p, state.natural_acquired_tick, tick) : Int8(0)
    vac_level = state.vaccine_acquired_tick != DEFAULT_TICK ?
        _waning_level(p, state.vaccine_acquired_tick, tick) : Int8(0)
    return max(nat_level, vac_level)
end

@inline function immunity_is_stable(p::ExponentialWaning, state::ImmunityState, tick::Int16)
    nat_pending = state.natural_acquired_tick != DEFAULT_TICK && tick < state.natural_acquired_tick
    vac_pending = state.vaccine_acquired_tick != DEFAULT_TICK && tick < state.vaccine_acquired_tick
    (nat_pending || vac_pending) && return false
    return calculate_immunity(p, state, tick) <= p.floor
end