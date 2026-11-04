export SettingModifier
export SettingTransmissionRate

###
### SettingModifier
###

"""
    SettingModifier <: TransmissionModifier

A `TransmissionModifier` that scales per-contact transmission risk by the type of the
setting (contact pool) the contact was drawn in. Setting types without an entry in
`factors` use `default_factor`. Use inside a `CompositeTransmissionRate`.

# Fields
- `factors::Dict{DataType, Float64}`: Factor (≥ 0) per concrete setting type.
- `default_factor::Float64`: Factor (≥ 0) for setting types not listed in `factors`.

# Example

```julia
modifier = SettingModifier(factors = Dict("Household" => 3.0, "SchoolClass" => 1.5), default_factor = 1.0)
tf = CompositeTransmissionRate(ConstantTransmissionRate(transmission_rate = 0.1), modifier)
```
"""
struct SettingModifier <: TransmissionModifier
    factors::Dict{DataType, Float64}
    default_factor::Float64

    function SettingModifier(; factors::AbstractDict, default_factor::Real)
        any(v -> !(isfinite(v) && v >= 0), values(factors)) &&
            throw(ArgumentError("All setting factors must be finite and non-negative."))
        !(isfinite(default_factor) && default_factor >= 0) &&
            throw(ArgumentError("default_factor must be finite and non-negative."))
        return new(
            Dict{DataType, Float64}(_factor_setting_type(string(k)) => Float64(v) for (k, v) in factors),
            Float64(default_factor))
    end
end

# The setting type called `name`, a struct or a declared one; it must exist when the modifier is built.
function _factor_setting_type(name::AbstractString)
    T = _resolve_setting_type(name)
    isnothing(T) && throw(ArgumentError("Unknown setting type \"$name\"; declare it before using it in a SettingModifier."))
    return T
end

Base.show(io::IO, m::SettingModifier) = print(io,
    "SettingModifier(" *
    join(sort!(["$(setting_type_name(k))=$v" for (k, v) in m.factors]), ", ") *
    (isempty(m.factors) ? "" : ", ") *
    "default=$(m.default_factor))")


"""
    transmission_factor(modifier::SettingModifier, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64

Returns the factor for the type of `setting`, or `default_factor` if the type has no entry.
"""
function transmission_factor(
        modifier::SettingModifier,
        pathogen_id::Int8,
        infecter::Individual,
        infectee::Individual,
        setting::Setting,
        tick::Int16,
        sim::Simulation,
        rng::Xoshiro)::Float64
    return _setting_factor(modifier, typeof(setting))
end

transmission_factor(modifier::SettingModifier, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_factor(modifier, pathogen_id, infecter, infectee, setting, tick, sim, Xoshiro())

"""
    max_transmission_factor_in_type(modifier::SettingModifier, pathogen_id::Int8, infecter::Individual, ::Type{S}, tick::Int16, sim::Simulation) where {S<:Setting}

Returns the factor for type `S`, which every infectee in such a setting gets.
"""
max_transmission_factor_in_type(modifier::SettingModifier, pathogen_id::Int8, infecter::Individual, ::Type{S}, tick::Int16, sim::Simulation) where {S<:Setting} =
    _setting_factor(modifier, S)

# The factor for setting type `S`, or the default if the type has no entry.
_setting_factor(modifier::SettingModifier, ::Type{S}) where {S<:Setting} =
    get(modifier.factors, S, modifier.default_factor)::Float64


###
### SettingTransmissionRate
###

"""
    SettingTransmissionRate <: TransmissionFunction

Convenience wrapper combining a constant base transmission rate with a `SettingModifier`.
Accepts the keyword arguments of `SettingModifier` plus `transmission_rate`; `effective_transmission_probability` caps the product at 1.

# Fields
- `transmission_rate::Float64`: Base per-contact transmission probability (0–1).
- `modifier::SettingModifier`: The setting modifier.

# Example

```julia
tf = SettingTransmissionRate(
    transmission_rate = 0.1,
    factors = Dict("Household" => 3.0, "SchoolClass" => 1.5),
    default_factor = 1.0
)
```
"""
mutable struct SettingTransmissionRate <: TransmissionFunction
    transmission_rate::Float64
    modifier::SettingModifier

    function SettingTransmissionRate(;
            transmission_rate::Float64 = 0.5,
            factors::AbstractDict,
            default_factor::Real)

        !(0.0 <= transmission_rate <= 1.0) &&
            throw(ArgumentError("transmission_rate must be between 0 and 1."))

        return new(transmission_rate, SettingModifier(factors = factors, default_factor = default_factor))
    end
end

Base.show(io::IO, tf::SettingTransmissionRate) = print(io,
    "SettingTransmissionRate(β=$(tf.transmission_rate), $(tf.modifier))")


"""
    transmission_probability(transFunc::SettingTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)

Returns the base rate scaled by the setting factor. Infectiousness and immunity scaling are
applied automatically by the framework via `effective_transmission_probability`.
"""
function transmission_probability(
        transFunc::SettingTransmissionRate,
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

transmission_probability(transFunc::SettingTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, Xoshiro())

"""
    max_transmission_probability_in_type(transFunc::SettingTransmissionRate, pathogen_id::Int8, infecter::Individual, ::Type{S}, tick::Int16, sim::Simulation) where {S<:Setting}

Returns the `transmission_rate` times the modifier's `max_transmission_factor_in_type`.
"""
max_transmission_probability_in_type(transFunc::SettingTransmissionRate, pathogen_id::Int8, infecter::Individual, ::Type{S}, tick::Int16, sim::Simulation) where {S<:Setting} =
    transFunc.transmission_rate * max_transmission_factor_in_type(transFunc.modifier, pathogen_id, infecter, S, tick, sim)
