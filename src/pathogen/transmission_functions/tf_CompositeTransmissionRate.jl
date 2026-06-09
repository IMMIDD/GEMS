export CompositeTransmissionRate

"""
    CompositeTransmissionRate{T<:Tuple} <: TransmissionFunction

A `TransmissionFunction` that composes multiple transmission functions multiplicatively.
Each sub-function contributes a base rate via `transmission_probability`; infectiousness
and standard immunity are applied exactly once by the framework via
`effective_transmission_probability`, avoiding double-counting.

The sub-functions are stored as a typed tuple so that Julia can fully specialise and inline
the dispatch chain with no heap allocation.

# Fields
- `functions::T`: Tuple of `TransmissionFunction` instances to combine.

# Example

```julia
# Age-dependent base rate, scaled down by viral interference from concurrent infections.
# Set transmission_rate = 1.0 on the interference function so it acts as a pure modifier.
tf = CompositeTransmissionRate(
    AgeDependentTransmissionRate(age_groups = ["0-", "60-"], transmission_rates = [0.2, 0.4]),
    ViralInterferenceTransmissionRate(
        transmission_rate = 1.0,
        pathogen_ids = [1, 2],
        interference_matrix = [1.0 0.4; 0.6 1.0]
    )
)
pathogen = Pathogen(name = "Flu", progressions = [...], transmission_function = tf)
```
"""
struct CompositeTransmissionRate{T<:Tuple} <: TransmissionFunction
    functions::T
end

"""
    CompositeTransmissionRate(fns::TransmissionFunction...) -> CompositeTransmissionRate

Varargs constructor. Passing concrete-typed arguments preserves their types in the tuple,
giving a fully type-stable `CompositeTransmissionRate{Tuple{T1, T2, ...}}`.
"""
CompositeTransmissionRate(fns::TransmissionFunction...) = CompositeTransmissionRate(fns)

Base.show(io::IO, tf::CompositeTransmissionRate) = print(io, "CompositeTransmissionRate(", join(tf.functions, ", "), ")")


# recursive helpers
@inline _product_rates(::Tuple{}, pathogen_id, infecter, infectee, setting, tick, sim, rng) = 1.0

@inline function _product_rates(fns::Tuple, pathogen_id, infecter, infectee, setting, tick, sim, rng)
    return transmission_probability(fns[1], pathogen_id, infecter, infectee, setting, tick, sim, rng) *
           _product_rates(Base.tail(fns), pathogen_id, infecter, infectee, setting, tick, sim, rng)
end


"""
    transmission_probability(transFunc::CompositeTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64

Returns the product of `transmission_probability` values from all composed sub-functions.
Infectiousness and standard immunity are applied exactly once by the framework via
`effective_transmission_probability`, avoiding double-counting across sub-functions.

# Parameters

- `transFunc::CompositeTransmissionRate`: Transmission function struct
- `pathogen_id::Int8`: ID of the current pathogen
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `sim::Simulation`: Simulation object
- `rng::Xoshiro`: RNG used for probability

# Returns

- `Float64`: Product of all sub-function base rates (`0 <= p <= 1`)
"""
function transmission_probability(
        transFunc::CompositeTransmissionRate,
        pathogen_id::Int8,
        infecter::Individual,
        infectee::Individual,
        setting::Setting,
        tick::Int16,
        sim::Simulation,
        rng::Xoshiro)::Float64
    return _product_rates(transFunc.functions, pathogen_id, infecter, infectee, setting, tick, sim, rng)
end

transmission_probability(transFunc::CompositeTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())
