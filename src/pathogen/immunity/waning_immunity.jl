###
### WANING IMMUNITY (INTERFACE AND SHARED MECHANICS OF PROFILES THAT REACH A PEAK AND THEN FOLLOW A CURVE)
###
export WaningImmunity
export calculate_waning_immunity, waning_level, natural_peak
export calculate_waning_severity_immunity, severity_waning_level, severity_natural_peak

"""
    WaningImmunity <: ImmunityProfile

Supertype of profiles whose immunity reaches a peak and then follows a curve. A subtype implements
`waning_level(profile, peak, elapsed, state, source, rng)` and, to change natural immunity's peak,
`natural_peak(profile)`; its `calculate_immunity` calls `calculate_waning_immunity`, which does the vaccine buildup
and boosters and combines natural and vaccine immunity as 1 − (1−p)(1−q).
"""
abstract type WaningImmunity <: ImmunityProfile end

"""
    waning_level(profile::WaningImmunity, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8

Returns the level (0-100) `elapsed` ticks after a dose or a recovery reached `peak`. `source` is `:natural`,
`:vaccine` or `:prev_vaccine`; a curve that draws re-keys `rng` with `immunity_rng!(rng, state, source)`, so its
draws stay the same on every read of that acquisition.
"""
function waning_level(profile::WaningImmunity, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8
    error("waning_level is not implemented for WaningImmunity type $(typeof(profile)).")
end

"""
    natural_peak(profile::WaningImmunity)::Int8

Returns the level of natural immunity at recovery. Defaults to 100.
"""
natural_peak(profile::WaningImmunity)::Int8 = Int8(100)

"""
    calculate_waning_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16, rng::Xoshiro)::Int8

Returns the level of `state` at `tick` from the profile's `waning_level` and `natural_peak`: a dose ramps to the
vaccine's peak over its buildup, a booster's buildup keeps what the previous dose still gives, and natural and
vaccine immunity combine as 1 − (1−p)(1−q).
"""
@inline calculate_waning_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16, rng::Xoshiro)::Int8 =
    _waning_immunity(waning_level, profile, state, natural_peak(profile), vaccine_protection, vaccine_protection.peak, tick, rng)

"""
    calculate_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Calls `calculate_waning_immunity`, for `WaningImmunity` subtypes that don't define their own `calculate_immunity`.
"""
@inline calculate_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_immunity(profile, state, vaccine_protection, tick, rng)

@inline calculate_immunity(profile::WaningImmunity, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_immunity(profile, state, VaccineProtection(), individual, tick, rng)

"""
    severity_waning_level(profile::WaningImmunity, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8

Returns the protection against severe disease `elapsed` ticks after a dose or a recovery reached `peak`, with the
arguments of `waning_level`. Defaults to `waning_level`.
"""
@inline severity_waning_level(profile::WaningImmunity, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8 =
    waning_level(profile, peak, elapsed, state, source, rng)

"""
    severity_natural_peak(profile::WaningImmunity)::Int8

Returns the protection against severe disease of natural immunity at recovery. Defaults to `natural_peak`.
"""
severity_natural_peak(profile::WaningImmunity)::Int8 = natural_peak(profile)

"""
    calculate_waning_severity_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16, rng::Xoshiro)::Int8

The counterpart of `calculate_waning_immunity` for protection against severe disease, from `severity_waning_level`,
`severity_natural_peak` and the vaccine's `severity_peak`.
"""
@inline calculate_waning_severity_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, tick::Int16, rng::Xoshiro)::Int8 =
    _waning_immunity(severity_waning_level, profile, state, severity_natural_peak(profile), vaccine_protection, vaccine_protection.severity_peak, tick, rng)

"""
    calculate_severity_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8

Calls `calculate_waning_severity_immunity`, for `WaningImmunity` subtypes that don't define their own
`calculate_severity_immunity`.
"""
@inline calculate_severity_immunity(profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_severity_immunity(profile, state, vaccine_protection, tick, rng)

# the deprecated buildup a profile gives vaccines that set none; remove with the profiles'
# `vaccine_buildup_duration` in the next major release
_profile_vaccine_buildup(profile::ImmunityProfile)::Int16 = Int16(0)

# natural and vaccine immunity of `state` on the curve `curve`, combined as independent barriers
@inline function _waning_immunity(curve::F, profile::WaningImmunity, state::ImmunityState, nat_peak::Int8,
        vaccine_protection::VaccineProtection, vaccine_peak::Int8, tick::Int16, rng::Xoshiro)::Int8 where {F}
    nat_level = natural_immunity_recorded(state) ?
        _dose_level(curve, profile, state, :natural, state.natural_acquired_tick, tick, Int16(0), nat_peak, rng) : Int8(0)
    # full natural immunity combined with any vaccine level is full
    nat_level == 100 && return nat_level
    vac_level = vaccine_immunity_recorded(state) ?
        _vaccine_level(curve, profile, state, vaccine_protection, vaccine_peak, tick, rng) : Int8(0)
    return Int8(clamp(round(Int, Int(nat_level) + Int(vac_level) - (Int(nat_level) * Int(vac_level)) / 100.0f0), 0, 100))
end

# a dose's level: ramps from 0 to `peak` over the buildup, then follows `curve`
@inline function _dose_level(curve::F, profile::WaningImmunity, state::ImmunityState, source::Symbol, acquired_tick::Int16,
        tick::Int16, buildup_duration::Int16, peak::Int8, rng::Xoshiro)::Int8 where {F}
    tick < acquired_tick && return Int8(0)
    elapsed = tick - acquired_tick
    if elapsed < buildup_duration
        return Int8(clamp(round(Int, Float32(peak) * elapsed / buildup_duration), 0, 100))
    end
    return curve(profile, peak, elapsed - buildup_duration, state, source, rng)
end

# during a dose's buildup, the vaccine level is at least what the previous dose still gives
@inline function _vaccine_level(curve::F, profile::WaningImmunity, state::ImmunityState, vaccine_protection::VaccineProtection,
        peak::Int8, tick::Int16, rng::Xoshiro)::Int8 where {F}
    buildup = vaccine_protection.buildup_duration < 0 ? _profile_vaccine_buildup(profile) : vaccine_protection.buildup_duration
    current = _dose_level(curve, profile, state, :vaccine, state.vaccine_acquired_tick, tick, buildup, peak, rng)
    elapsed = tick - state.vaccine_acquired_tick
    (0 <= elapsed < buildup && state.prev_dose_interval != 0x00) || return current
    prev_tick = Int(state.vaccine_acquired_tick) - Int(previous_dose_interval(state))
    prev_tick > typemin(Int16) || return current
    return max(current, _dose_level(curve, profile, state, :prev_vaccine, Int16(prev_tick), tick, buildup, peak, rng))
end
