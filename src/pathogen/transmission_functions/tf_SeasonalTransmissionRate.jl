export SinusoidalSeasonalModifier
export SinusoidalSeasonalTransmissionRate

###
### SinusoidalSeasonalModifier
###

"""
    SinusoidalSeasonalModifier <: TransmissionModifier

A `TransmissionModifier` that models smooth seasonal variation in per-contact
transmission risk using standard cosine forcing. Returns a dimensionless seasonal factor
via `transmission_factor`; does not encode a base transmission rate. Use inside a
`CompositeTransmissionRate` together with a base-rate function such as `ConstantTransmissionRate`.

The factor oscillates sinusoidally around 1.0 over a 365-day year:

    factor(t) = 1 + amplitude × cos(2π × (doy(t) − peak_day) / 365)

where `doy(t)` is the calendar day-of-year derived from the current tick, the
simulation `startdate`, and the `tickunit`. The mean factor is exactly 1.0, so
the base transmission rate in the `CompositeTransmissionRate` is interpretable
as the annual-average per-contact transmission probability.

Note: the factor exceeds 1.0 in peak season (up to `1 + amplitude`). Ensure that
`base_rate × (1 + amplitude) ≤ 1.0` to keep the effective probability valid.

# Fields
- `amplitude::Float64`: Seasonal forcing strength ∈ [0, 1]. 0.0 = no seasonality
  (flat factor of 1.0 for all ticks); 1.0 = factor oscillates between 0.0 (trough)
  and 2.0 (peak).
- `peak_day::Int`: Day of year (1–365) at which transmission is highest.

# Example

```julia
modifier = SinusoidalSeasonalModifier(amplitude = 0.3, peak_day = 15)
tf = CompositeTransmissionRate(ConstantTransmissionRate(transmission_rate = 0.3), modifier)
```
"""
struct SinusoidalSeasonalModifier <: TransmissionModifier
    amplitude::Float64
    peak_day::Int

    function SinusoidalSeasonalModifier(; amplitude::Float64, peak_day::Int)
        (amplitude < 0.0 || amplitude > 1.0) &&
            throw(ArgumentError("amplitude must be between 0 and 1."))
        (peak_day < 1 || peak_day > 365) &&
            throw(ArgumentError("peak_day must be between 1 and 365."))
        return new(amplitude, peak_day)
    end
end

Base.show(io::IO, m::SinusoidalSeasonalModifier) = print(io,
    "SinusoidalSeasonalModifier(" *
    "amplitude=$(m.amplitude), " *
    "peak_day=$(m.peak_day))")


"""
    transmission_factor(modifier::SinusoidalSeasonalModifier, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64

Returns the sinusoidal seasonal factor for the current tick. The factor is ≥ 0 and
may exceed 1.0 in peak season; the mean over a full year is 1.0.

# Parameters

- `modifier::SinusoidalSeasonalModifier`: Modifier struct
- `pathogen_id::Int8`: ID of the current pathogen
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current simulation tick
- `sim::Simulation`: Simulation object
- `rng::Xoshiro`: RNG used for probability

# Returns

- `Float64`: Seasonal factor (≥ 0; mean = 1.0 over a full year)
"""
function transmission_factor(
        modifier::SinusoidalSeasonalModifier,
        pathogen_id::Int8,
        infecter::Individual,
        infectee::Individual,
        setting::Setting,
        tick::Int16,
        sim::Simulation,
        rng::Xoshiro)::Float64
    days = _seasonal_tick_to_days(tick, sim.tickunit)
    doy = Dates.dayofyear(sim.startdate + Dates.Day(days))
    return 1.0 + modifier.amplitude * cos(2π * (doy - modifier.peak_day) / 365.0)
end

transmission_factor(modifier::SinusoidalSeasonalModifier, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_factor(modifier, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())

# Converts the current tick to whole calendar days based on the simulation tick unit.
function _seasonal_tick_to_days(tick::Int16, tickunit::Char)::Int
    tickunit == 'h' && return div(Int(tick), 24)
    tickunit == 'w' && return Int(tick) * 7
    return Int(tick)
end


###
### SinusoidalSeasonalTransmissionRate
###

"""
    SinusoidalSeasonalTransmissionRate <: TransmissionFunction

Convenience wrapper combining a constant base transmission rate with a
`SinusoidalSeasonalModifier`. Accepts the same keyword arguments as
`SinusoidalSeasonalModifier` plus `transmission_rate`. The modifier fields are
accessible via `.modifier.*`.

# Fields
- `transmission_rate::Float64`: Base per-contact transmission probability (0–1),
  interpreted as the annual-average per-contact risk.
- `modifier::SinusoidalSeasonalModifier`: The seasonal modifier.

# Example

```julia
tf = SinusoidalSeasonalTransmissionRate(
    transmission_rate = 0.3,
    amplitude = 0.4,
    peak_day = 15
)
```
"""
mutable struct SinusoidalSeasonalTransmissionRate <: TransmissionFunction
    transmission_rate::Float64
    modifier::SinusoidalSeasonalModifier

    function SinusoidalSeasonalTransmissionRate(;
            transmission_rate::Float64 = 0.5,
            amplitude::Float64,
            peak_day::Int)

        (transmission_rate < 0.0 || transmission_rate > 1.0) &&
            throw(ArgumentError("transmission_rate must be between 0 and 1."))

        modifier = SinusoidalSeasonalModifier(
            amplitude = amplitude,
            peak_day  = peak_day
        )

        return new(transmission_rate, modifier)
    end
end

Base.show(io::IO, tf::SinusoidalSeasonalTransmissionRate) = print(io,
    "SinusoidalSeasonalTransmissionRate(β=$(tf.transmission_rate), " *
    "amplitude=$(tf.modifier.amplitude), " *
    "peak_day=$(tf.modifier.peak_day))")


"""
    transmission_probability(transFunc::SinusoidalSeasonalTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)

Calculates the base transmission probability using a constant base rate modulated by
the sinusoidal seasonal factor. Infectiousness and immunity scaling are applied
automatically by the framework via `effective_transmission_probability`.

# Parameters

- `transFunc::SinusoidalSeasonalTransmissionRate`: Transmission function struct
- `pathogen_id::Int8`: ID of the current pathogen
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `sim::Simulation`: Simulation object
- `rng::Xoshiro`: RNG used for probability

# Returns

- `Float64`: Transmission probability p (`0 <= p`)
"""
function transmission_probability(
        transFunc::SinusoidalSeasonalTransmissionRate,
        pathogen_id::Int8,
        infecter::Individual,
        infectee::Individual,
        setting::Setting,
        tick::Int16,
        sim::Simulation,
        rng::Xoshiro)::Float64
    return transFunc.transmission_rate *
           transmission_factor(transFunc.modifier, pathogen_id, infecter, infectee, setting, tick, sim, rng)
end

# Convenience wrapper without explicit RNG — uses the thread-local default
transmission_probability(transFunc::SinusoidalSeasonalTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())
