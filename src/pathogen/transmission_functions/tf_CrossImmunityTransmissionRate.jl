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
immunity is taken at full weight (scale 1.0), while immunity from any other pathogen is
scaled by a cross-immunity factor (0 ≤ factor ≤ 1). Each prior immunity independently
reduces the remaining susceptibility, so the combined protection is
1 − ∏(1 − scale_i × immunity_i).

Cross-immunity factors are looked up from `cross_immunity_matrix`, indexed by
`[exposed_pathogen, prior_pathogen]` using the ordering defined in `pathogen_names`.
For any pathogen pair not covered by the matrix, `default_cross_factor` is used
as the fallback scale (default: 0.0, i.e. no cross-protection).

# Fields
- `pathogen_names::Vector{String}`: Ordered list of pathogen names whose pairwise
  cross-immunity factors are defined in `cross_immunity_matrix`.
- `name_to_idx::Dict{String,Int}`: Maps each pathogen name to its row/column index in
  `cross_immunity_matrix`. Derived from `pathogen_names` at construction; not set directly.
- `cross_immunity_matrix::Matrix{Float64}`: Square matrix of size n×n (where
  n = `length(pathogen_names)`). Entry `[i, j]` is the scale applied to immunity
  from pathogen `pathogen_names[j]` when the infectee is exposed to pathogen
  `pathogen_names[i]`. Diagonal entries should be 1.0 (full self-immunity).
- `default_cross_factor::Float64`: Fallback scale used when either the exposed
  pathogen or the prior-immunity pathogen is not found in `pathogen_names` (0–1).

# Example

```julia
modifier = CrossImmunityModifier(
    pathogen_names = ["Covid19", "Influenza", "RSV"],
    cross_immunity_matrix = [1.0 0.5 0.3;
                             0.5 1.0 0.4;
                             0.3 0.4 1.0],
    default_cross_factor = 0.1
)
tf = CompositeTransmissionRate(ConstantTransmissionRate(transmission_rate = 0.3), modifier)
```
"""
struct CrossImmunityModifier <: TransmissionModifier
    pathogen_names::Vector{String}
    name_to_idx::Dict{String, Int}
    cross_immunity_matrix::Matrix{Float64}
    default_cross_factor::Float64

    function CrossImmunityModifier(;
            pathogen_names::Vector{String} = String[],
            cross_immunity_matrix = Matrix{Float64}(undef, 0, 0),
            default_cross_factor::Float64 = 0.0)

        (default_cross_factor < 0.0 || default_cross_factor > 1.0) &&
            throw(ArgumentError("default_cross_factor must be between 0 and 1."))

        if cross_immunity_matrix isa AbstractVector
            cross_immunity_matrix = Float64.(hcat(cross_immunity_matrix...)')
        end

        n = length(pathogen_names)
        name_to_idx = Dict(name => i for (i, name) in enumerate(pathogen_names))

        size(cross_immunity_matrix) != (n, n) &&
            throw(ArgumentError("cross_immunity_matrix must be a square matrix of size n×n where n = length(pathogen_names) = $n (got $(size(cross_immunity_matrix)))."))
        any(x -> x < 0.0 || x > 1.0, cross_immunity_matrix) &&
            throw(ArgumentError("All entries in cross_immunity_matrix must be between 0 and 1."))
        any(i -> cross_immunity_matrix[i, i] != 1.0, 1:n) &&
            @warn "Diagonal entries of cross_immunity_matrix are expected to be 1.0 but some are not. Note that diagonal entries are ignored; direct self-immunity always applies at full weight."

        return new(pathogen_names, name_to_idx, cross_immunity_matrix, default_cross_factor)
    end
end

Base.show(io::IO, m::CrossImmunityModifier) = print(io,
    "CrossImmunityModifier(" *
    "pathogen_names=$(m.pathogen_names), " *
    "cross_immunity_matrix=$(m.cross_immunity_matrix), " *
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

    exposed_idx = get(modifier.name_to_idx, get_pathogen(sim, pathogen_id).name, nothing)
    remaining_susceptibility = 1.0

    for s in each_immunity(infectee, sim)
        s.pathogen_id == pathogen_id && continue
        scale = if exposed_idx !== nothing
            prior_idx = try get(modifier.name_to_idx, get_pathogen(sim, s.pathogen_id).name, nothing) catch; nothing end
            prior_idx !== nothing ? modifier.cross_immunity_matrix[exposed_idx, prior_idx] : modifier.default_cross_factor
        else
            modifier.default_cross_factor
        end
        remaining_susceptibility *= (1.0 - s.immunity_level / 100.0 * scale)
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
    pathogen_names = ["Covid19", "Influenza", "RSV"],
    cross_immunity_matrix = [1.0 0.5 0.3;
                             0.5 1.0 0.4;
                             0.3 0.4 1.0],
    default_cross_factor = 0.1
)
```
"""
mutable struct CrossImmunityTransmissionRate <: TransmissionFunction
    transmission_rate::Float64
    modifier::CrossImmunityModifier

    function CrossImmunityTransmissionRate(;
            transmission_rate::Float64 = 0.5,
            pathogen_names::Vector{String} = String[],
            cross_immunity_matrix = Matrix{Float64}(undef, 0, 0),
            default_cross_factor::Float64 = 0.0)

        (transmission_rate < 0.0 || transmission_rate > 1.0) &&
            throw(ArgumentError("transmission_rate must be between 0 and 1."))

        modifier = CrossImmunityModifier(
            pathogen_names = pathogen_names,
            cross_immunity_matrix = cross_immunity_matrix,
            default_cross_factor = default_cross_factor
        )

        return new(transmission_rate, modifier)
    end
end

Base.show(io::IO, tf::CrossImmunityTransmissionRate) = print(io,
    "CrossImmunityTransmissionRate(β=$(tf.transmission_rate), " *
    "pathogen_names=$(tf.modifier.pathogen_names), " *
    "cross_immunity_matrix=$(tf.modifier.cross_immunity_matrix), " *
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
