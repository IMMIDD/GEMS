export CompositeTransmissionRate

"""
    CompositeTransmissionRate{B<:TransmissionFunction, M<:Tuple{Vararg{TransmissionModifier}}} <: TransmissionFunction

A `TransmissionFunction` that combines one base `TransmissionFunction` with zero or more
`TransmissionModifier`s multiplicatively. The base function provides the absolute per-contact
transmission probability; each modifier returns a dimensionless factor (via `transmission_factor`)
that scales that probability.

The base and modifiers are stored as concrete typed fields so that Julia can fully specialise
and inline the entire dispatch chain with no heap allocation.

# Fields
- `base::B`: A `TransmissionFunction` that returns an absolute probability.
- `modifiers::M`: Tuple of `TransmissionModifier` instances, each contributing a factor.

# Example

```julia
# Age-dependent base rate, scaled down by viral interference from concurrent infections.
tf = CompositeTransmissionRate(
    AgeDependentTransmissionRate(age_groups = ["0-", "60-"], transmission_rates = [0.2, 0.4]),
    ViralInterferenceModifier(
        pathogen_ids = [1, 2],
        interference_matrix = [1.0 0.4; 0.6 1.0]
    )
)
pathogen = Pathogen(name = "Flu", progressions = [...], transmission_function = tf)
```
"""
struct CompositeTransmissionRate{B<:TransmissionFunction, M<:Tuple{Vararg{TransmissionModifier}}} <: TransmissionFunction
    base::B
    modifiers::M
end

"""
    CompositeTransmissionRate(base::TransmissionFunction, modifiers::TransmissionModifier...) -> CompositeTransmissionRate

Varargs constructor. `base` must be a concrete `TransmissionFunction` (not a `TransmissionModifier`);
the remaining arguments must all be `TransmissionModifier` instances. Preserving concrete types
in the tuple gives a fully type-stable `CompositeTransmissionRate{B, Tuple{M1, M2, ...}}`.
"""
CompositeTransmissionRate(base::TransmissionFunction, modifiers::TransmissionModifier...) = CompositeTransmissionRate(base, modifiers)

Base.show(io::IO, tf::CompositeTransmissionRate) =
    print(io, "CompositeTransmissionRate(base=", tf.base, ", modifiers=(", join(tf.modifiers, ", "), "))")


# recursive helpers
@inline _apply_modifiers(::Tuple{}, pathogen_id, infecter, infectee, setting, tick, sim, rng) = 1.0

@inline function _apply_modifiers(mods::Tuple, pathogen_id, infecter, infectee, setting, tick, sim, rng)
    return transmission_factor(mods[1], pathogen_id, infecter, infectee, setting, tick, sim, rng) *
           _apply_modifiers(Base.tail(mods), pathogen_id, infecter, infectee, setting, tick, sim, rng)
end


"""
    transmission_probability(transFunc::CompositeTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64

Returns the product of the base function's `transmission_probability` and the `transmission_factor`
of each modifier. Infectiousness and standard immunity are applied exactly once by the framework
via `effective_transmission_probability`, avoiding double-counting across sub-functions.

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

- `Float64`: Base probability scaled by all modifier factors (`0 <= p <= 1`)
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
    return transmission_probability(transFunc.base, pathogen_id, infecter, infectee, setting, tick, sim, rng) *
           _apply_modifiers(transFunc.modifiers, pathogen_id, infecter, infectee, setting, tick, sim, rng)
end

transmission_probability(transFunc::CompositeTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())
