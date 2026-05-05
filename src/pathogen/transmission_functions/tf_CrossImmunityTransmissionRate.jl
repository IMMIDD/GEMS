export CrossImmunityTransmissionRate

"""
    CrossImmunityTransmissionRate <: TransmissionFunction

A `TransmissionFunction` type that uses a constant base transmission rate and
models cross-immunity between pathogens. The effective susceptibility of the infectee
is computed multiplicatively over all pathogens for which the individual has a
cached immunity level: the current pathogen's immunity is taken at full weight
(scale 1.0), while immunity from any other pathogen is scaled by a cross-immunity
factor (0 ≤ factor ≤ 1). Each prior immunity independently reduces the remaining
susceptibility, so the combined protection is 1 − ∏(1 − scale_i × immunity_i).

Cross-immunity factors are looked up from `cross_immunity_matrix`, indexed by
`[exposed_pathogen, prior_pathogen]` using the ordering defined in `pathogen_ids`.
For any pathogen pair not covered by the matrix, `default_cross_factor` is used
as the fallback scale (default: 0.0, i.e. no cross-protection).

# Fields
- `transmission_rate::Float64`: Base per-contact transmission probability (0–1).
- `pathogen_ids::Vector{Int8}`: Ordered list of pathogen IDs whose pairwise
  cross-immunity factors are defined in `cross_immunity_matrix`.
- `cross_immunity_matrix::Matrix{Float64}`: Square matrix of size n×n (where
  n = `length(pathogen_ids)`). Entry `[i, j]` is the scale applied to immunity
  from pathogen `pathogen_ids[j]` when the infectee is exposed to pathogen
  `pathogen_ids[i]`. Diagonal entries should be 1.0 (full self-immunity).
- `default_cross_factor::Float64`: Fallback scale used when either the exposed
  pathogen or the prior-immunity pathogen is not found in `pathogen_ids` (0–1).

# Example

```julia
# 30% base transmission rate; pathogen IDs 1, 2, and 3 with explicit pairwise
# cross-immunity factors. Prior immunity to a pathogen outside the matrix
# counts at 10% of its face value toward cross-protection.
tf = CrossImmunityTransmissionRate(
    transmission_rate = 0.3,
    pathogen_ids = [1, 2, 3],
    cross_immunity_matrix = [1.0 0.5 0.3;
                             0.5 1.0 0.4;
                             0.3 0.4 1.0],
    default_cross_factor = 0.1
)
```
"""
mutable struct CrossImmunityTransmissionRate <: TransmissionFunction
    transmission_rate::Float64
    pathogen_ids::Vector{Int8}
    cross_immunity_matrix::Matrix{Float64}
    default_cross_factor::Float64

    function CrossImmunityTransmissionRate(;
            transmission_rate::Float64 = 0.5,
            pathogen_ids::Vector = Int8[],
            cross_immunity_matrix = Matrix{Float64}(undef, 0, 0),
            default_cross_factor::Float64 = 0.0)

        (transmission_rate < 0.0 || transmission_rate > 1.0) &&
            throw(ArgumentError("transmission_rate must be between 0 and 1."))
        (default_cross_factor < 0.0 || default_cross_factor > 1.0) &&
            throw(ArgumentError("default_cross_factor must be between 0 and 1."))

        # convert TOML-parsed Vector{Vector} to Matrix{Float64} if necessary
        if cross_immunity_matrix isa AbstractVector
            cross_immunity_matrix = Float64.(hcat(cross_immunity_matrix...)')
        end

        n = length(pathogen_ids)

        size(cross_immunity_matrix) != (n, n) &&
            throw(ArgumentError("cross_immunity_matrix must be a square matrix of size n×n where n = length(pathogen_ids) = $n (got $(size(cross_immunity_matrix)))."))
        any(x -> x < 0.0 || x > 1.0, cross_immunity_matrix) &&
            throw(ArgumentError("All entries in cross_immunity_matrix must be between 0 and 1."))
        any(i -> cross_immunity_matrix[i, i] != 1.0, 1:n) &&
            @warn "Diagonal entries of cross_immunity_matrix are expected to be 1.0 but some are not. Note that diagonal entries are ignored; direct self-immunity always applies at full weight."

        return new(transmission_rate, Int8.(pathogen_ids), cross_immunity_matrix, default_cross_factor)
    end
end

Base.show(io::IO, tf::CrossImmunityTransmissionRate) = print(io,
    "CrossImmunityTransmissionRate(β=$(tf.transmission_rate), " *
    "pathogen_ids=$(tf.pathogen_ids), " *
    "cross_immunity_matrix=$(tf.cross_immunity_matrix), " *
    "default_cross_factor=$(tf.default_cross_factor))")


"""
    transmission_probability(transFunc::CrossImmunityTransmissionRate, pathogen_id::Int8,
        infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, rng::Xoshiro)

Calculates the transmission probability using a constant base rate modulated by
the infecter's current shedding level and an effective immunity of the infectee
that accounts for cross-immunity across pathogens.

Each cached immunity level is scaled and combined multiplicatively: the remaining
susceptibility is the product of (1 − scale_i × immunity_i) over all prior immunities,
where:
- immunity against `pathogen_id` itself is always taken at full weight (scale 1.0),
- immunity from another pathogen is scaled by the corresponding entry in
  `cross_immunity_matrix` if both pathogens are covered by the matrix, or by
  `default_cross_factor` otherwise.

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

    # row index of the exposed pathogen in the matrix (nothing if not covered)
    exposed_idx = findfirst(==(pathogen_id), transFunc.pathogen_ids)

    remaining_susceptibility = 1.0
    @inbounds for s in 1:MAX_TRACKED_IMMUNITIES
        pid = infectee.immune_pathogens[s]
        pid == Int8(0) && break

        if pid == pathogen_id
            # direct immunity against the current pathogen always has full weight
            scale = 1.0
        elseif exposed_idx !== nothing
            # look up the cross-immunity factor from the matrix if both pathogens are covered
            prior_idx = findfirst(==(pid), transFunc.pathogen_ids)
            scale = prior_idx !== nothing ?
                transFunc.cross_immunity_matrix[exposed_idx, prior_idx] :
                transFunc.default_cross_factor
        else
            scale = transFunc.default_cross_factor
        end

        remaining_susceptibility *= (1.0 - infectee.immunity_level[s] / 100.0 * scale)
    end

    return transFunc.transmission_rate * (infectiousness(infecter, pathogen_id) / 100.0) * remaining_susceptibility
end

# Convenience wrapper without explicit RNG — uses the thread-local default
transmission_probability(transFunc::CrossImmunityTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16) =
    transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, default_gems_rng())