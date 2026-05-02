
export CrossImmunityTransmissionRate

"""
    CrossImmunityTransmissionRate <: TransmissionFunction

A `TransmissionFunction` type that uses a constant base transmission rate and
models cross-immunity between pathogens. The effective immunity of the infectee
is computed as the maximum over all pathogens for which the individual has a
cached immunity level: the current pathogen's immunity is taken at full weight
(scale 1.0), while immunity from any other pathogen is scaled down by
`cross_factor` (0 ≤ `cross_factor` ≤ 1). The maximum of all scaled values
is used as the effective protection against the current infection attempt.

# Fields
- `transmission_rate::Float64`: Base per-contact transmission probability (0–1).
- `cross_factor::Float64`: Weight applied to immunity from other pathogens (0–1).

# Example

```julia
# 30% base transmission rate; prior immunity to another pathogen
# counts at 50% of its face value toward cross-protection
tf = CrossImmunityTransmissionRate(
    transmission_rate = 0.3,
    cross_factor = 0.5
)
```
"""
mutable struct CrossImmunityTransmissionRate <: TransmissionFunction
    transmission_rate::Float64
    cross_factor::Float64

    function CrossImmunityTransmissionRate(; transmission_rate::Float64 = 0.5, cross_factor::Float64 = 0.5)

        (transmission_rate < 0.0 || transmission_rate > 1.0) &&
            throw(ArgumentError("transmission_rate must be between 0 and 1."))
        (cross_factor < 0.0 || cross_factor > 1.0) &&
            throw(ArgumentError("cross_factor must be between 0 and 1."))

        return new(transmission_rate, cross_factor)
    end
end

Base.show(io::IO, tf::CrossImmunityTransmissionRate) = print(io,
    "CrossImmunityTransmissionRate(β=$(tf.transmission_rate), cross_factor=$(tf.cross_factor))")


"""
    transmission_probability(transFunc::CrossImmunityTransmissionRate, pathogen_id::Int8,
        infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, rng::Xoshiro)

Calculates the transmission probability using a constant base rate modulated by
the infecter's current shedding level and an effective immunity of the infectee
that accounts for cross-immunity across pathogens.

The effective immunity is the maximum of:
- the infectee's direct immunity against `pathogen_id` (weight 1.0), and
- each other cached immunity level scaled by `cross_factor`.

# Parameters

- `transFunc::CrossImmunityTransmissionRate`: Transmission function struct
- `pathogen_id::Int8`: ID of the current pathogen
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `rng::Xoshiro`: RNG used for probability

# Returns

- `Float64`: Transmission probability p (`0 <= p <= 1`)
"""
function transmission_probability(
        transFunc::CrossImmunityTransmissionRate,
        pathogen_id::Int8,
        infecter::Individual,
        infectee::Individual,
        setting::Setting,
        tick::Int16,
        rng::Xoshiro)::Float64

    infectiousness(infecter, pathogen_id) == 0 && throw(ArgumentError("Infecting individual must have nonzero infectiousness to calculate transmission probability."))

    effective_immunity = 0.0
    @inbounds for s in 1:MAX_TRACKED_IMMUNITIES
        pid = infectee.immune_pathogens[s]
        pid == Int8(0) && break
        scale = pid == pathogen_id ? 1.0 : transFunc.cross_factor
        candidate = infectee.immunity_level[s] / 100.0 * scale
        effective_immunity = max(effective_immunity, candidate)
    end

    return transFunc.transmission_rate * (infectiousness(infecter, pathogen_id) / 100.0) * (1.0 - effective_immunity)
end

# Convenience wrapper without explicit RNG — uses the thread-local default
transmission_probability(transFunc::CrossImmunityTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16) =
    transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, default_gems_rng())
