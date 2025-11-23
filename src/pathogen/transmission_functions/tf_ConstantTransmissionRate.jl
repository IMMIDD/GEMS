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
    transmission_probability(transFunc::ConstantTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())

Calculates the transmission probability for the `ConstantTransmissionRate`. Returns the `transmission_rate`
for all individuals who have not been infected in the past. If the individual has already recovered,
the function returns `0.0`, assuming full indefinite natural immunity.

# Parameters

- `transFunc::ConstantTransmissionRate`: Transmission function struct
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `rng::AbstractRNG = Random.default_rng()` *(optional)*: RNG used for probability. Uses Random's default RNG as default.

# Returns

- `Float64`: Transmission probability p (`0 <= p <= 1`)

"""
function transmission_probability(transFunc::ConstantTransmissionRate, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, rng::AbstractRNG)::Float64
    # error handling
    !infected(infecter) && throw(ArgumentError("Infecting individual must be infected to calculate transmission probability."))
    
    if  -1 < recovery(infectee) <= tick # if the agent has already recovered (natural immunity)
        return 0.0
    end
    
    return transFunc.transmission_rate
end
# if no RNG was passed, use default RNG
transmission_probability(transFunc::ConstantTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16) = 
    transmission_probability(transFunc, infecter, infected, setting, tick, Random.default_rng())