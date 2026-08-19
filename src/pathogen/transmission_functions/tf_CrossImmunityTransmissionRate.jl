export CrossImmunityModifier
export CrossImmunityTransmissionRate

###
### CrossImmunityModifier
###

"""
    CrossImmunityModifier <: TransmissionModifier

A `TransmissionModifier` that models cross-immunity between pathogens. Returns a
dimensionless susceptibility factor via `transmission_factor`; does not encode a base
transmission rate. Use inside a `CompositeTransmissionRate` together with a base-rate
function such as `ConstantTransmissionRate`.

The effective susceptibility of the infectee is computed multiplicatively over all
pathogens for which the individual has a cached immunity level: the current pathogen's
immunity is excluded (it is applied by the framework), while immunity from any other
pathogen is scaled by a cross-immunity factor (0 ≤ factor ≤ 1). Each prior immunity
independently reduces the remaining susceptibility, so the combined protection is
1 − ∏(1 − factor_i × immunity_i).

Cross-immunity factors are given per pathogen by name: `cross_immunities` maps a prior
pathogen's name to the factor applied to immunity acquired against it. Any pathogen not
listed uses `default_cross_factor` (default: 0.0, i.e. no cross-protection).

# Fields
- `cross_immunities::Dict{String,Float64}`: Maps a prior pathogen's name to its
  cross-immunity factor (0–1).
- `default_cross_factor::Float64`: Fallback factor for pathogens not listed in
  `cross_immunities` (0–1).

# Example

```julia
# Immunity to Influenza protects at 50%, immunity to RSV at 30%, anything else at 10%.
modifier = CrossImmunityModifier(
    cross_immunities = [("Influenza", 0.5), ("RSV", 0.3)],
    default_cross_factor = 0.1
)
tf = CompositeTransmissionRate(ConstantTransmissionRate(transmission_rate = 0.3), modifier)
```
"""
struct CrossImmunityModifier <: TransmissionModifier
    cross_immunities::Dict{String, Float64}
    default_cross_factor::Float64

    function CrossImmunityModifier(;
            cross_immunities = Tuple{String, Float64}[],
            default_cross_factor::Float64 = 0.0)

        (default_cross_factor < 0.0 || default_cross_factor > 1.0) &&
            throw(ArgumentError("default_cross_factor must be between 0 and 1."))

        # accepts a list of (name, factor) pairs, incl. TOML's [name, factor] vectors
        factors = Dict{String, Float64}()
        for entry in cross_immunities
            name = String(entry[1])
            factor = Float64(entry[2])
            isempty(name) &&
                throw(ArgumentError("cross_immunities pathogen names must be non-empty."))
            (factor < 0.0 || factor > 1.0) &&
                throw(ArgumentError("cross_immunities factors must be between 0 and 1."))
            haskey(factors, name) &&
                throw(ArgumentError("Duplicate pathogen name '$name' in cross_immunities."))
            factors[name] = factor
        end

        return new(factors, default_cross_factor)
    end
end

Base.show(io::IO, m::CrossImmunityModifier) = print(io,
    "CrossImmunityModifier(" *
    "cross_immunities=$(m.cross_immunities), " *
    "default_cross_factor=$(m.default_cross_factor))")


"""
    transmission_factor(modifier::CrossImmunityModifier, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64

Returns the cross-immunity susceptibility factor for the infectee. Values are in [0, 1]:
1.0 means no cross-immunity reduction, 0.0 means complete protection.

The infectee's own immunity to `pathogen_id` is excluded here; it is applied automatically
by the framework via `effective_transmission_probability`.

# Parameters

- `modifier::CrossImmunityModifier`: Modifier struct
- `pathogen_id::Int8`: ID of the current pathogen
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `sim::Simulation`: Simulation object
- `rng::Xoshiro`: RNG used for probability

# Returns

- `Float64`: Susceptibility factor (`0 <= f <= 1`)
"""
function transmission_factor(
        modifier::CrossImmunityModifier,
        pathogen_id::Int8,
        infecter::Individual,
        infectee::Individual,
        setting::Setting,
        tick::Int16,
        sim::Simulation,
        rng::Xoshiro)::Float64

    remaining_susceptibility = 1.0

    for s in each_immunity(infectee, sim)
        s.pathogen_id == pathogen_id && continue
        name = get_pathogen(sim, s.pathogen_id).name
        factor = get(modifier.cross_immunities, name, modifier.default_cross_factor)
        remaining_susceptibility *= (1.0 - s.immunity_level / 100.0 * factor)
    end

    return remaining_susceptibility
end

transmission_factor(modifier::CrossImmunityModifier, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_factor(modifier, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())


###
### CrossImmunityTransmissionRate
###

"""
    CrossImmunityTransmissionRate <: TransmissionFunction

Convenience wrapper combining a constant base transmission rate with a
`CrossImmunityModifier`. Accepts the same keyword arguments as
`CrossImmunityModifier` plus `transmission_rate`. The modifier fields are
accessible via `.modifier.*`.

# Fields
- `transmission_rate::Float64`: Base per-contact transmission probability (0–1).
- `modifier::CrossImmunityModifier`: The cross-immunity modifier.

# Example

```julia
tf = CrossImmunityTransmissionRate(
    transmission_rate = 0.3,
    cross_immunities = [("Influenza", 0.5), ("RSV", 0.3)],
    default_cross_factor = 0.1
)
```
"""
mutable struct CrossImmunityTransmissionRate <: TransmissionFunction
    transmission_rate::Float64
    modifier::CrossImmunityModifier

    function CrossImmunityTransmissionRate(;
            transmission_rate::Float64 = 0.5,
            cross_immunities = Tuple{String, Float64}[],
            default_cross_factor::Float64 = 0.0)

        (transmission_rate < 0.0 || transmission_rate > 1.0) &&
            throw(ArgumentError("transmission_rate must be between 0 and 1."))

        modifier = CrossImmunityModifier(
            cross_immunities = cross_immunities,
            default_cross_factor = default_cross_factor
        )

        return new(transmission_rate, modifier)
    end
end

Base.show(io::IO, tf::CrossImmunityTransmissionRate) = print(io,
    "CrossImmunityTransmissionRate(β=$(tf.transmission_rate), " *
    "cross_immunities=$(tf.modifier.cross_immunities), " *
    "default_cross_factor=$(tf.modifier.default_cross_factor))")


"""
    transmission_probability(transFunc::CrossImmunityTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)

Calculates the base transmission rate using a constant base rate modulated by an
effective cross-immunity of the infectee that accounts for cross-immunity across
pathogens. The infectee's own immunity to `pathogen_id` is excluded here; it is
applied automatically by the framework via `effective_transmission_probability`.

# Parameters

- `transFunc::CrossImmunityTransmissionRate`: Transmission function struct
- `pathogen_id::Int8`: ID of the current pathogen
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `sim::Simulation'`: Simulation object
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
        sim::Simulation,
        rng::Xoshiro)::Float64
    return transFunc.transmission_rate *
           transmission_factor(transFunc.modifier, pathogen_id, infecter, infectee, setting, tick, sim, rng)
end

# Convenience wrapper without explicit RNG — uses the thread-local default
transmission_probability(transFunc::CrossImmunityTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())
