export ViralInterferenceModifier
export ViralInterferenceTransmissionRate

###
### ViralInterferenceModifier
###

"""
    ViralInterferenceModifier <: TransmissionModifier

A `TransmissionModifier` that models viral interference between pathogens. Returns a
dimensionless susceptibility factor via `transmission_factor`; does not encode a base
transmission rate. Use inside a `CompositeTransmissionRate` together with a base-rate
function such as `ConstantTransmissionRate`.

The effective susceptibility of the infectee is reduced multiplicatively for each
pathogen the individual is *currently actively infected* with: each concurrent infection
independently scales the remaining susceptibility by the corresponding interference
factor.

This models innate immune activation — e.g. interferon responses triggered by an
active infection — that non-specifically suppresses susceptibility to a second
pathogen. It is distinct from `CrossImmunityModifier`, which acts on
*past-infection or vaccine-derived* immunity, not on concurrently active infections.

Interference factors are given per pathogen by name: `interferences` maps an actively
infecting pathogen's name to the multiplicative factor applied while that infection is
active. Any pathogen not listed uses `default_interference_factor` (default: 1.0, i.e.
no interference).

# Fields
- `interferences::Dict{String,Float64}`: Maps an active pathogen's name to its
  interference factor (0–1); 0.0 = complete suppression, 1.0 = no interference.
- `default_interference_factor::Float64`: Fallback factor for pathogens not listed in
  `interferences` (0–1). Defaults to 1.0 (no interference for unlisted pathogens).

# Example

```julia
# An active Influenza infection reduces susceptibility to the exposed pathogen by 60%.
modifier = ViralInterferenceModifier(
    interferences = [("Influenza", 0.4), ("RSV", 0.6)],
    default_interference_factor = 1.0
)
tf = CompositeTransmissionRate(ConstantTransmissionRate(transmission_rate = 0.3), modifier)
```
"""
struct ViralInterferenceModifier <: TransmissionModifier
    interferences::Dict{String, Float64}
    default_interference_factor::Float64

    function ViralInterferenceModifier(;
            interferences = Tuple{String, Float64}[],
            default_interference_factor::Float64 = 1.0)

        (default_interference_factor < 0.0 || default_interference_factor > 1.0) &&
            throw(ArgumentError("default_interference_factor must be between 0 and 1."))

        # accepts a list of (name, factor) pairs, incl. TOML's [name, factor] vectors
        factors = Dict{String, Float64}()
        for entry in interferences
            name = String(entry[1])
            factor = Float64(entry[2])
            isempty(name) &&
                throw(ArgumentError("interferences pathogen names must be non-empty."))
            (factor < 0.0 || factor > 1.0) &&
                throw(ArgumentError("interferences factors must be between 0 and 1."))
            haskey(factors, name) &&
                throw(ArgumentError("Duplicate pathogen name '$name' in interferences."))
            factors[name] = factor
        end

        return new(factors, default_interference_factor)
    end
end

Base.show(io::IO, m::ViralInterferenceModifier) = print(io,
    "ViralInterferenceModifier(" *
    "interferences=$(m.interferences), " *
    "default_interference_factor=$(m.default_interference_factor))")


"""
    transmission_factor(modifier::ViralInterferenceModifier, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64

Returns the viral interference susceptibility factor for the infectee. Values are in [0, 1]:
1.0 means no interference, 0.0 means complete suppression.

# Parameters

- `modifier::ViralInterferenceModifier`: Modifier struct
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
        modifier::ViralInterferenceModifier,
        pathogen_id::Int8,
        infecter::Individual,
        infectee::Individual,
        setting::Setting,
        tick::Int16,
        sim::Simulation,
        rng::Xoshiro)::Float64

    remaining_susceptibility = 1.0

    for s in each_infection(infectee, sim)
        s.pathogen_id == pathogen_id && continue
        name = get_pathogen(sim, s.pathogen_id).name
        remaining_susceptibility *= get(modifier.interferences, name, modifier.default_interference_factor)
    end

    return remaining_susceptibility
end

transmission_factor(modifier::ViralInterferenceModifier, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_factor(modifier, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())


###
### ViralInterferenceTransmissionRate
###

"""
    ViralInterferenceTransmissionRate <: TransmissionFunction

Convenience wrapper combining a constant base transmission rate with a
`ViralInterferenceModifier`. Accepts the same keyword arguments as
`ViralInterferenceModifier` plus `transmission_rate`. The modifier fields are
accessible via `.modifier.*`.

# Fields
- `transmission_rate::Float64`: Base per-contact transmission probability (0–1).
- `modifier::ViralInterferenceModifier`: The viral interference modifier.

# Example

```julia
tf = ViralInterferenceTransmissionRate(
    transmission_rate = 0.3,
    interferences = [("Influenza", 0.4), ("RSV", 0.6)],
    default_interference_factor = 1.0
)
```
"""
mutable struct ViralInterferenceTransmissionRate <: TransmissionFunction
    transmission_rate::Float64
    modifier::ViralInterferenceModifier

    function ViralInterferenceTransmissionRate(;
            transmission_rate::Float64 = 0.5,
            interferences = Tuple{String, Float64}[],
            default_interference_factor::Float64 = 1.0)

        (transmission_rate < 0.0 || transmission_rate > 1.0) &&
            throw(ArgumentError("transmission_rate must be between 0 and 1."))

        modifier = ViralInterferenceModifier(
            interferences = interferences,
            default_interference_factor = default_interference_factor
        )

        return new(transmission_rate, modifier)
    end
end

Base.show(io::IO, tf::ViralInterferenceTransmissionRate) = print(io,
    "ViralInterferenceTransmissionRate(β=$(tf.transmission_rate), " *
    "interferences=$(tf.modifier.interferences), " *
    "default_interference_factor=$(tf.modifier.default_interference_factor))")


"""
    transmission_probability(transFunc::ViralInterferenceTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)

Calculates the base transmission rate using a constant base rate modulated by a
susceptibility reduction derived from the infectee's currently active concurrent
infections. Infectiousness and immunity scaling are applied automatically by the
framework via `effective_transmission_probability`.

# Parameters

- `transFunc::ViralInterferenceTransmissionRate`: Transmission function struct
- `pathogen_id::Int8`: ID of the current pathogen
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `sim::Simulation`: Simulation object
- `rng::Xoshiro`: RNG used for probability

# Returns

- `Float64`: Transmission probability p (`0 <= p <= 1`)
"""
function transmission_probability(
        transFunc::ViralInterferenceTransmissionRate,
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
transmission_probability(transFunc::ViralInterferenceTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())
