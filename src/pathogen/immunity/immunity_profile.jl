export FullImmunity, NoImmunity, ExponentialWaning, SigmoidalWaning


"""
    FullImmunity <: WaningImmunity

The default `ImmunityProfile`. Immunity never wanes: natural immunity is full (level 100) from recovery, and a
vaccine dose rises to the vaccine's `peak` over its `buildup_duration` (default 0) and stays there.
"""
struct FullImmunity <: WaningImmunity end

@inline waning_level(profile::FullImmunity, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8 = peak

@inline calculate_immunity(profile::FullImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_immunity(profile, state, vaccine_protection, tick, rng)

@inline calculate_severity_immunity(profile::FullImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_severity_immunity(profile, state, vaccine_protection, tick, rng)

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
    ExponentialWaning <: WaningImmunity

An `ImmunityProfile` that starts at a peak at acquisition and decays
exponentially toward `floor` with the given `halflife` (in ticks): natural
immunity at `natural_peak`, a vaccine dose at the vaccine's `peak`.
When both natural and vaccine immunity exist, each source is treated as an
independent protective barrier and the levels are combined as 1 − (1−p)(1−q).

Vaccine-induced immunity ramps from 0 to its peak over the vaccine's
`buildup_duration`, or `vaccine_buildup_duration` if the vaccine sets none,
before waning begins. Natural immunity (post-recovery) starts at its peak immediately.

Level at elapsed ticks e (after buildup):  `max(min(floor, peak), peak × 0.5^(e / halflife))`

Protection against severe disease follows the same curve with `severity_halflife` and `severity_floor`, starting
at `severity_natural_peak` or the vaccine's `severity_peak`. It counts per exposure against unprotected hosts, so it
includes the severe cases that protection against infection prevents rather than adding to it.

# Fields
- `natural_peak::Int8`: Level of natural immunity at recovery (default: 100).
- `halflife::Float32`: Ticks for immunity to halve (default: 180).
- `floor::Int8`: Minimum immunity level after full waning, at most the source's peak (default: 0).
- `severity_natural_peak::Int8`: Protection against severe disease at recovery, at least `natural_peak` (default: `natural_peak`).
- `severity_halflife::Float32`: Ticks for protection against severe disease to halve (default: `halflife`).
- `severity_floor::Int8`: Minimum protection against severe disease (default: `floor`).
- `vaccine_buildup_duration::Int16`: Deprecated, set `buildup_duration` on the vaccine. Ticks from vaccination to peak
  immunity for vaccines that set none (default: 0).
"""
@with_kw struct ExponentialWaning <: WaningImmunity
    natural_peak::Int8 = Int8(100)
    halflife::Float32 = 180.0f0
    floor::Int8 = Int8(0)
    severity_natural_peak::Int8 = natural_peak
    severity_halflife::Float32 = halflife
    severity_floor::Int8 = floor
    vaccine_buildup_duration::Int16 = Int16(0)

    function ExponentialWaning(natural_peak, halflife, floor, severity_natural_peak, severity_halflife, severity_floor, vaccine_buildup_duration)
        0 <= natural_peak <= 100 || throw(ArgumentError("natural_peak must be in [0, 100] (got $natural_peak)."))
        halflife > 0 || throw(ArgumentError("halflife must be positive (got $halflife)."))
        0 <= floor <= 100 || throw(ArgumentError("floor must be in [0, 100] (got $floor)."))
        natural_peak <= severity_natural_peak <= 100 || throw(ArgumentError("natural_peak ($natural_peak, default 100) must not exceed severity_natural_peak ($severity_natural_peak, default natural_peak), which must be at most 100."))
        severity_halflife > 0 || throw(ArgumentError("severity_halflife must be positive (got $severity_halflife)."))
        0 <= severity_floor <= 100 || throw(ArgumentError("severity_floor must be in [0, 100] (got $severity_floor)."))
        vaccine_buildup_duration >= 0 || throw(ArgumentError("vaccine_buildup_duration must be non-negative."))
        vaccine_buildup_duration == 0 ||
            Base.depwarn("ExponentialWaning(vaccine_buildup_duration) is deprecated; set buildup_duration on the Vaccine.", :ExponentialWaning)
        return new(Int8(natural_peak), Float32(halflife), Int8(floor),
            Int8(severity_natural_peak), Float32(severity_halflife), Int8(severity_floor), Int16(vaccine_buildup_duration))
    end
end

"""
    ExponentialWaning(halflife, floor, vaccine_buildup_duration)

Positional constructor with the default peaks and severity curve.
"""
ExponentialWaning(halflife, floor, vaccine_buildup_duration) =
    ExponentialWaning(100, halflife, floor, 100, halflife, floor, vaccine_buildup_duration)

# the exponential curve shared by both endpoints
@inline function _exponential_curve(peak::Int8, elapsed::Int16, halflife::Float32, floor::Int8)::Int8
    level = Float32(peak) * 0.5f0^(Float32(elapsed) / halflife)
    return Int8(max(min(Int(floor), Int(peak)), clamp(round(Int, level), 0, 100)))
end

@inline waning_level(profile::ExponentialWaning, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8 =
    _exponential_curve(peak, elapsed, profile.halflife, profile.floor)

@inline severity_waning_level(profile::ExponentialWaning, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8 =
    _exponential_curve(peak, elapsed, profile.severity_halflife, profile.severity_floor)

natural_peak(profile::ExponentialWaning)::Int8 = profile.natural_peak

severity_natural_peak(profile::ExponentialWaning)::Int8 = profile.severity_natural_peak

@inline calculate_immunity(profile::ExponentialWaning, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_immunity(profile, state, vaccine_protection, tick, rng)

@inline calculate_severity_immunity(profile::ExponentialWaning, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_severity_immunity(profile, state, vaccine_protection, tick, rng)

# deprecated with `vaccine_buildup_duration`; remove both in the next major release
_profile_vaccine_buildup(profile::ExponentialWaning)::Int16 = profile.vaccine_buildup_duration



"""
    SigmoidalWaning <: WaningImmunity

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

Protection against severe disease follows the same curve with `severity_halflife` and `severity_floor`, starting
at `severity_natural_peak` or the vaccine's `severity_peak`. It counts per exposure against unprotected hosts, so it
includes the severe cases that protection against infection prevents rather than adding to it.

# Fields
- `natural_peak::Int8`: Level of natural immunity at recovery (default: 100).
- `halflife::Float32`: Ticks at which immunity reaches half its peak (default: 180).
- `hill::Float32`: Hill coefficient controlling sigmoidal steepness, for both endpoints (default: 3).
- `floor::Int8`: Minimum immunity level after full waning, at most the source's peak (default: 0).
- `severity_natural_peak::Int8`: Protection against severe disease at recovery, at least `natural_peak` (default: `natural_peak`).
- `severity_halflife::Float32`: Ticks at which protection against severe disease reaches half its peak (default: `halflife`).
- `severity_floor::Int8`: Minimum protection against severe disease (default: `floor`).
- `vaccine_buildup_duration::Int16`: Deprecated, set `buildup_duration` on the vaccine. Ticks from vaccination to peak
  immunity for vaccines that set none (default: 0).
"""
@with_kw struct SigmoidalWaning <: WaningImmunity
    natural_peak::Int8 = Int8(100)
    halflife::Float32 = 180.0f0
    hill::Float32 = 3.0f0
    floor::Int8 = Int8(0)
    severity_natural_peak::Int8 = natural_peak
    severity_halflife::Float32 = halflife
    severity_floor::Int8 = floor
    vaccine_buildup_duration::Int16 = Int16(0)

    function SigmoidalWaning(natural_peak, halflife, hill, floor, severity_natural_peak, severity_halflife, severity_floor, vaccine_buildup_duration)
        0 <= natural_peak <= 100 || throw(ArgumentError("natural_peak must be in [0, 100] (got $natural_peak)."))
        halflife > 0 || throw(ArgumentError("halflife must be positive (got $halflife)."))
        hill > 0 || throw(ArgumentError("hill must be positive (got $hill)."))
        0 <= floor <= 100 || throw(ArgumentError("floor must be in [0, 100] (got $floor)."))
        natural_peak <= severity_natural_peak <= 100 || throw(ArgumentError("natural_peak ($natural_peak, default 100) must not exceed severity_natural_peak ($severity_natural_peak, default natural_peak), which must be at most 100."))
        severity_halflife > 0 || throw(ArgumentError("severity_halflife must be positive (got $severity_halflife)."))
        0 <= severity_floor <= 100 || throw(ArgumentError("severity_floor must be in [0, 100] (got $severity_floor)."))
        vaccine_buildup_duration >= 0 || throw(ArgumentError("vaccine_buildup_duration must be non-negative."))
        vaccine_buildup_duration == 0 ||
            Base.depwarn("SigmoidalWaning(vaccine_buildup_duration) is deprecated; set buildup_duration on the Vaccine.", :SigmoidalWaning)
        return new(Int8(natural_peak), Float32(halflife), Float32(hill), Int8(floor),
            Int8(severity_natural_peak), Float32(severity_halflife), Int8(severity_floor), Int16(vaccine_buildup_duration))
    end
end

"""
    SigmoidalWaning(halflife, hill, floor, vaccine_buildup_duration)

Positional constructor with the default peaks and severity curve.
"""
SigmoidalWaning(halflife, hill, floor, vaccine_buildup_duration) =
    SigmoidalWaning(100, halflife, hill, floor, 100, halflife, floor, vaccine_buildup_duration)

# the Hill curve shared by both endpoints
@inline function _sigmoidal_curve(peak::Int8, elapsed::Int16, halflife::Float32, hill::Float32, floor::Int8)::Int8
    hl_n = halflife ^ hill
    level = Float32(peak) * hl_n / (hl_n + Float32(elapsed) ^ hill)
    return Int8(max(min(Int(floor), Int(peak)), clamp(round(Int, level), 0, 100)))
end

@inline waning_level(profile::SigmoidalWaning, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8 =
    _sigmoidal_curve(peak, elapsed, profile.halflife, profile.hill, profile.floor)

@inline severity_waning_level(profile::SigmoidalWaning, peak::Int8, elapsed::Int16, state::ImmunityState, source::Symbol, rng::Xoshiro)::Int8 =
    _sigmoidal_curve(peak, elapsed, profile.severity_halflife, profile.hill, profile.severity_floor)

natural_peak(profile::SigmoidalWaning)::Int8 = profile.natural_peak

severity_natural_peak(profile::SigmoidalWaning)::Int8 = profile.severity_natural_peak

@inline calculate_immunity(profile::SigmoidalWaning, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_immunity(profile, state, vaccine_protection, tick, rng)

@inline calculate_severity_immunity(profile::SigmoidalWaning, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_severity_immunity(profile, state, vaccine_protection, tick, rng)

# deprecated with `vaccine_buildup_duration`; remove both in the next major release
_profile_vaccine_buildup(profile::SigmoidalWaning)::Int16 = profile.vaccine_buildup_duration
