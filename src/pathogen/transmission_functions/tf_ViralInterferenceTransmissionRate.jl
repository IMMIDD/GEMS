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
independently scales the remaining susceptibility by the corresponding entry in
`interference_matrix`.

This models innate immune activation — e.g. interferon responses triggered by an
active infection — that non-specifically suppresses susceptibility to a second
pathogen. It is distinct from `CrossImmunityModifier`, which acts on
*past-infection or vaccine-derived* immunity, not on concurrently active infections.

Interference factors are looked up from `interference_matrix`, indexed by
`[exposed_pathogen, active_pathogen]` using the ordering defined in `pathogen_names`.
For any pathogen pair not covered by the matrix, `default_interference_factor` is
used as the fallback (default: 1.0, i.e. no interference).

# Fields
- `pathogen_names::Vector{String}`: Ordered list of pathogen names whose pairwise
  interference factors are defined in `interference_matrix`.
- `name_to_idx::Dict{String,Int}`: Maps each pathogen name to its row/column index in
  `interference_matrix`. Derived from `pathogen_names` at construction; not set directly.
- `interference_matrix::Matrix{Float64}`: Square matrix of size n×n (where
  n = `length(pathogen_names)`). Entry `[i, j]` is the multiplicative factor applied
  to the infectee's remaining susceptibility when exposed to pathogen `pathogen_names[i]`
  while actively infected with pathogen `pathogen_names[j]`. Values in [0, 1]:
  0.0 = complete suppression, 1.0 = no interference. Diagonal entries are ignored
  (an active infection with the same pathogen precludes re-infection at the
  simulation level).
- `default_interference_factor::Float64`: Fallback factor used when either the
  exposed pathogen or the active pathogen is not found in `pathogen_names` (0–1).
  Defaults to 1.0 (no interference for unlisted pairs).

# Example

```julia
# An active Influenza infection reduces susceptibility to Covid19 by 60%.
# An active Covid19 infection reduces susceptibility to Influenza by 40%.
modifier = ViralInterferenceModifier(
    pathogen_names = ["Covid19", "Influenza"],
    interference_matrix = [1.0 0.4;
                           0.6 1.0],
    default_interference_factor = 1.0
)
tf = CompositeTransmissionRate(ConstantTransmissionRate(transmission_rate = 0.3), modifier)
```
"""
struct ViralInterferenceModifier <: TransmissionModifier
    pathogen_names::Vector{String}
    name_to_idx::Dict{String, Int}
    interference_matrix::Matrix{Float64}
    default_interference_factor::Float64

    function ViralInterferenceModifier(;
            pathogen_names::Vector{String} = String[],
            interference_matrix = Matrix{Float64}(undef, 0, 0),
            default_interference_factor::Float64 = 1.0)

        (default_interference_factor < 0.0 || default_interference_factor > 1.0) &&
            throw(ArgumentError("default_interference_factor must be between 0 and 1."))

        if interference_matrix isa AbstractVector
            interference_matrix = Float64.(hcat(interference_matrix...)')
        end

        n = length(pathogen_names)
        name_to_idx = Dict(name => i for (i, name) in enumerate(pathogen_names))

        size(interference_matrix) != (n, n) &&
            throw(ArgumentError("interference_matrix must be a square matrix of size n×n where n = length(pathogen_names) = $n (got $(size(interference_matrix)))."))
        any(x -> x < 0.0 || x > 1.0, interference_matrix) &&
            throw(ArgumentError("All entries in interference_matrix must be between 0 and 1."))
        any(i -> interference_matrix[i, i] != 1.0, 1:n) &&
            @warn "Diagonal entries of interference_matrix are expected to be 1.0 but some are not. Note that diagonal entries are ignored; the same-pathogen case is handled at the active-infection level."

        return new(pathogen_names, name_to_idx, interference_matrix, default_interference_factor)
    end
end

Base.show(io::IO, m::ViralInterferenceModifier) = print(io,
    "ViralInterferenceModifier(" *
    "pathogen_names=$(m.pathogen_names), " *
    "interference_matrix=$(m.interference_matrix), " *
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

    exposed_idx = get(modifier.name_to_idx, get_pathogen(sim, pathogen_id).name, nothing)
    remaining_susceptibility = 1.0

    for s in each_infection(infectee, sim)
        s.pathogen_id == pathogen_id && continue
        factor = if exposed_idx !== nothing
            active_idx = try get(modifier.name_to_idx, get_pathogen(sim, s.pathogen_id).name, nothing) catch; nothing end
            active_idx !== nothing ? modifier.interference_matrix[exposed_idx, active_idx] : modifier.default_interference_factor
        else
            modifier.default_interference_factor
        end
        remaining_susceptibility *= factor
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
    pathogen_names = ["Covid19", "Influenza"],
    interference_matrix = [1.0 0.4;
                           0.6 1.0],
    default_interference_factor = 1.0
)
```
"""
mutable struct ViralInterferenceTransmissionRate <: TransmissionFunction
    transmission_rate::Float64
    modifier::ViralInterferenceModifier

    function ViralInterferenceTransmissionRate(;
            transmission_rate::Float64 = 0.5,
            pathogen_names::Vector{String} = String[],
            interference_matrix = Matrix{Float64}(undef, 0, 0),
            default_interference_factor::Float64 = 1.0)

        (transmission_rate < 0.0 || transmission_rate > 1.0) &&
            throw(ArgumentError("transmission_rate must be between 0 and 1."))

        modifier = ViralInterferenceModifier(
            pathogen_names = pathogen_names,
            interference_matrix = interference_matrix,
            default_interference_factor = default_interference_factor
        )

        return new(transmission_rate, modifier)
    end
end

Base.show(io::IO, tf::ViralInterferenceTransmissionRate) = print(io,
    "ViralInterferenceTransmissionRate(β=$(tf.transmission_rate), " *
    "pathogen_names=$(tf.modifier.pathogen_names), " *
    "interference_matrix=$(tf.modifier.interference_matrix), " *
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
