export FullImmunity, NoImmunity, ExponentialWaning, SigmoidalWaning


"""
    FullImmunity <: WaningImmunity

The default `ImmunityProfile`. Immunity never wanes: natural immunity is full (level 100) from recovery, and a
vaccine dose rises to the vaccine's `peak` over its `buildup_duration` (default 0) and stays there.
"""
struct FullImmunity <: WaningImmunity end

@inline waning_level(profile::FullImmunity, peak::Int8, elapsed::Int16)::Int8 = peak

@inline calculate_immunity(profile::FullImmunity, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_immunity(profile, state, vaccine_protection, tick)

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

# Fields
- `halflife::Float32`: Ticks for immunity to halve (default: 180).
- `floor::Int8`: Minimum immunity level after full waning, at most the source's peak (default: 0).
- `vaccine_buildup_duration::Int16`: Deprecated, set `buildup_duration` on the vaccine. Ticks from vaccination to peak
  immunity for vaccines that set none (default: 0).
- `natural_peak::Int8`: Level of natural immunity at recovery (default: 100).
"""
@with_kw struct ExponentialWaning <: WaningImmunity
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

@inline function waning_level(profile::ExponentialWaning, peak::Int8, elapsed::Int16)::Int8
    level = Float32(peak) * 0.5f0^(Float32(elapsed) / profile.halflife)
    return Int8(max(min(Int(profile.floor), Int(peak)), clamp(round(Int, level), 0, 100)))
end

natural_peak(profile::ExponentialWaning)::Int8 = profile.natural_peak

@inline calculate_immunity(profile::ExponentialWaning, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_immunity(profile, state, vaccine_protection, tick)

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

# Fields
- `halflife::Float32`: Ticks at which immunity reaches half its peak (default: 180).
- `hill::Float32`: Hill coefficient controlling sigmoidal steepness (default: 3).
- `floor::Int8`: Minimum immunity level after full waning, at most the source's peak (default: 0).
- `vaccine_buildup_duration::Int16`: Deprecated, set `buildup_duration` on the vaccine. Ticks from vaccination to peak
  immunity for vaccines that set none (default: 0).
- `natural_peak::Int8`: Level of natural immunity at recovery (default: 100).
"""
@with_kw struct SigmoidalWaning <: WaningImmunity
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

@inline function waning_level(profile::SigmoidalWaning, peak::Int8, elapsed::Int16)::Int8
    hl_n = profile.halflife ^ profile.hill
    level = Float32(peak) * hl_n / (hl_n + Float32(elapsed) ^ profile.hill)
    return Int8(max(min(Int(profile.floor), Int(peak)), clamp(round(Int, level), 0, 100)))
end

natural_peak(profile::SigmoidalWaning)::Int8 = profile.natural_peak

@inline calculate_immunity(profile::SigmoidalWaning, state::ImmunityState, vaccine_protection::VaccineProtection, individual::Individual, tick::Int16, rng::Xoshiro)::Int8 =
    calculate_waning_immunity(profile, state, vaccine_protection, tick)

# deprecated with `vaccine_buildup_duration`; remove both in the next major release
_profile_vaccine_buildup(profile::SigmoidalWaning)::Int16 = profile.vaccine_buildup_duration
