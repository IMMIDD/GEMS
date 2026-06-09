export ConstantTransmissionRate

"""
    ConstantTransmissionRate <: TransmissionFunction

A `TransmissionFunction` type that uses a constant transmission rate.

"""
mutable struct ConstantTransmissionRate <: TransmissionFunction
    transmission_rate::Float64

    function ConstantTransmissionRate(;transmission_rate::Float64 = .5)
        transmission_rate < 0 && throw(ArgumentError("Transmission rate must be non-negative."))
        transmission_rate > 1 && throw(ArgumentError("Transmission rate must be at most 1."))
       
        return new(transmission_rate)
    end
end

Base.show(io::IO, ctr::ConstantTransmissionRate) = write(io, "ConstantTranmissionRate(β=$(ctr.transmission_rate))")


"""
    transmission_probability(transFunc::ConstantTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation, rng::Xoshiro)::Float64

Calculates the base transmission rate for the `ConstantTransmissionRate`. Returns the
`transmission_rate`; infectiousness and immunity scaling are applied automatically by
the framework via `effective_transmission_probability`.

# Parameters

- `transFunc::ConstantTransmissionRate`: Transmission function struct
- `pathogen_id::Int8`: ID of the current pathogen
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `sim::Simulation`: Simulation object
- `rng::Xoshiro`: RNG used for probability

# Returns

- `Float64`: Base transmission rate (`0 <= p <= 1`)

"""
function transmission_probability(
        transFunc::ConstantTransmissionRate,
        pathogen_id::Int8,
        infecter::Individual,
        infectee::Individual,
        setting::Setting,
        tick::Int16,
        sim::Simulation,
        rng::Xoshiro)::Float64
    return transFunc.transmission_rate
end

# if no RNG was passed, use default RNG
transmission_probability(transFunc::ConstantTransmissionRate, pathogen_id::Int8, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, sim::Simulation) =
    transmission_probability(transFunc, pathogen_id, infecter, infectee, setting, tick, sim, default_gems_rng())
