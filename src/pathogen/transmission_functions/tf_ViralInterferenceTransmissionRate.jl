export ViralInterferenceTransmissionRate

"""
    ViralInterferenceTransmissionRate <: TransmissionFunction

A `TransmissionFunction` type that uses a constant base transmission rate and
models viral interference between pathogens. The effective susceptibility of the
infectee is reduced multiplicatively for each pathogen the individual is *currently
actively infected* with: each concurrent infection independently scales the
remaining susceptibility by the corresponding entry in `interference_matrix`.

This models innate immune activation — e.g. interferon responses triggered by an
active infection — that non-specifically suppresses susceptibility to a second
pathogen. It is distinct from `CrossImmunityTransmissionRate`, which acts on
*past-infection or vaccine-derived* immunity, not on concurrently active infections.

Interference factors are looked up from `interference_matrix`, indexed by
`[exposed_pathogen, active_pathogen]` using the ordering defined in `pathogen_ids`.
For any pathogen pair not covered by the matrix, `default_interference_factor` is
used as the fallback (default: 1.0, i.e. no interference).

# Fields
- `transmission_rate::Float64`: Base per-contact transmission probability (0–1).
- `pathogen_ids::Vector{Int8}`: Ordered list of pathogen IDs whose pairwise
  interference factors are defined in `interference_matrix`.
- `interference_matrix::Matrix{Float64}`: Square matrix of size n×n (where
  n = `length(pathogen_ids)`). Entry `[i, j]` is the multiplicative factor applied
  to the infectee's remaining susceptibility when exposed to pathogen `pathogen_ids[i]`
  while actively infected with pathogen `pathogen_ids[j]`. Values in [0, 1]:
  0.0 = complete suppression, 1.0 = no interference. Diagonal entries are ignored
  (an active infection with the same pathogen precludes re-infection at the
  simulation level).
- `default_interference_factor::Float64`: Fallback factor used when either the
  exposed pathogen or the active pathogen is not found in `pathogen_ids` (0–1).
  Defaults to 1.0 (no interference for unlisted pairs).

# Example

```julia
# 30% base transmission rate; pathogen IDs 1 and 2.
# An active infection with pathogen 2 reduces susceptibility to pathogen 1 by 60%.
# An active infection with pathogen 1 reduces susceptibility to pathogen 2 by 40%.
tf = ViralInterferenceTransmissionRate(
    transmission_rate = 0.3,
    pathogen_ids = [1, 2],
    interference_matrix = [1.0 0.4;
                           0.6 1.0],
    default_interference_factor = 1.0
)
```
"""
mutable struct ViralInterferenceTransmissionRate <: TransmissionFunction
    transmission_rate::Float64
    pathogen_ids::Vector{Int8}
    interference_matrix::Matrix{Float64}
    default_interference_factor::Float64

    function ViralInterferenceTransmissionRate(;
            transmission_rate::Float64 = 0.5,
            pathogen_ids::Vector = Int8[],
            interference_matrix = Matrix{Float64}(undef, 0, 0),
            default_interference_factor::Float64 = 1.0)

        (transmission_rate < 0.0 || transmission_rate > 1.0) &&
            throw(ArgumentError("transmission_rate must be between 0 and 1."))
        (default_interference_factor < 0.0 || default_interference_factor > 1.0) &&
            throw(ArgumentError("default_interference_factor must be between 0 and 1."))

        # convert TOML-parsed Vector{Vector} to Matrix{Float64} if necessary
        if interference_matrix isa AbstractVector
            interference_matrix = Float64.(hcat(interference_matrix...)')
        end

        n = length(pathogen_ids)

        size(interference_matrix) != (n, n) &&
            throw(ArgumentError("interference_matrix must be a square matrix of size n×n where n = length(pathogen_ids) = $n (got $(size(interference_matrix)))."))
        any(x -> x < 0.0 || x > 1.0, interference_matrix) &&
            throw(ArgumentError("All entries in interference_matrix must be between 0 and 1."))
        any(i -> interference_matrix[i, i] != 1.0, 1:n) &&
            @warn "Diagonal entries of interference_matrix are expected to be 1.0 but some are not. Note that diagonal entries are ignored; the same-pathogen case is handled at the active-infection level."

        return new(transmission_rate, Int8.(pathogen_ids), interference_matrix, default_interference_factor)
    end
end

Base.show(io::IO, tf::ViralInterferenceTransmissionRate) = print(io,
    "ViralInterferenceTransmissionRate(β=$(tf.transmission_rate), " *
    "pathogen_ids=$(tf.pathogen_ids), " *
    "interference_matrix=$(tf.interference_matrix), " *
    "default_interference_factor=$(tf.default_interference_factor))")


"""
    transmission_probability(transFunc::ViralInterferenceTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)

Calculates the base transmission rate using a constant base rate modulated by a
susceptibility reduction derived from the infectee's currently active concurrent
infections. Infectiousness and immunity scaling are applied automatically by the
framework via `effective_transmission_probability`.

For each active infection of the infectee with a pathogen other than `pathogen_id`,
the remaining susceptibility is multiplied by the corresponding entry in
`interference_matrix`. Entries are looked up by `[exposed_pathogen, active_pathogen]`
using the index order in `pathogen_ids`; `default_interference_factor` is used for
any pair not covered by the matrix.

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

    exposed_idx = findfirst(==(pathogen_id), transFunc.pathogen_ids)
    remaining_susceptibility = 1.0

    for s in each_infection(infectee, sim)
        s.pathogen_id == pathogen_id && continue
        factor = if exposed_idx !== nothing
            active_idx = findfirst(==(s.pathogen_id), transFunc.pathogen_ids)
            active_idx !== nothing ? transFunc.interference_matrix[exposed_idx, active_idx] : transFunc.default_interference_factor
        else
            transFunc.default_interference_factor
        end
        remaining_susceptibility *= factor
    end

    return transFunc.transmission_rate * remaining_susceptibility
end

# Convenience wrapper without explicit RNG — uses the thread-local default
transmission_probability(transFunc::ViralInterferenceTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())
