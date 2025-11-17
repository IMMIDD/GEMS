export AgeDependentTransmissionRate

"""
    AgeDependentTransmissionRate <: TransmissionFunction

A `TransmissionFunction` type that allows to define transmission probabilities for specific age groups.
The age group corresponds to the infectee, i.e., the individual who may become infected, not the infecter.

# Fields
- `age_groups::Vector{AgeGroup}`: A vector of age groups.
- `age_transmission_rates::Vector{Real}`: A vector of transmission rates corresponding to each age group.

# Example
The code below instantiates an `AgeDependentTransmissionRate` with specific age groups and transmission rates.
```julia
adtr = AgeDependentTransmissionRate(
    age_groups = ["0-9", "10-19", "20-64", "65-"],
    transmission_rates = [0.1, 0.2, 0.3, 0.4]
)
```
"""
mutable struct AgeDependentTransmissionRate <: TransmissionFunction
    age_groups::Vector{AgeGroup}
    age_transmission_rates::Vector{Real}

    function AgeDependentTransmissionRate(;age_groups::Vector{String}, transmission_rates::Vector{<:Real})
        # both vectors must be of same length
        length(age_groups) != length(transmission_rates) &&
            throw(ArgumentError("Number of age groups and age transmission rates must be the same (input vector lengths: $(length(age_groups)) and $(length(transmission_rates)))."))
        # check that all transmission rates are between 0 and 1
        any(x -> x < 0.0 || x > 1.0, transmission_rates) &&
            throw(ArgumentError("All transmission rates must be between 0 and 1."))
        
        # convert age group strings to AgeGroup structs
        gprs = AgeGroup.(age_groups)
        # check continuity of age groups
        check_continuity(gprs, 0, 100) # throw error if not continuous

        return new(
            gprs,
            transmission_rates
        )
    end
end
Base.show(io::IO, transFunc::AgeDependentTransmissionRate) = begin
    items = []
    for (i, ag) in enumerate(transFunc.age_groups)
        push!(items, "$(ag): $(100 * transFunc.age_transmission_rates[i])%")
    end
    print(io, "AgeDependentTransmissionRate(", join(items, ", "), ")")
end


"""
    transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, rng::AbstractRNG)::Float64

Calculates the transmission probability based on the age of the infectee using age-dependent transmission rates.


# Parameters

- `transFunc::AgeDependentTransmissionRate`: Transmission function struct
- `infecter::Individual`: Infecting individual
- `infectee::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `rng::AbstractRNG = Random.default_rng()` *(optional)*: RNG used for probability. Uses Random's default RNG as default.

# Returns

- `Float64`: Transmission probability p (`0 <= p <= 1`)
"""
function transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infectee::Individual, setting::Setting, tick::Int16, rng::AbstractRNG)::Float64
    # error handling
    !infected(infecter) && throw(ArgumentError("Infecting individual must be infected to calculate transmission probability."))
    
    if  -1 < recovery(infectee) <= tick # if the agent has already recovered (natural immunity)
        return 0.0
    end
    
    for (i, ag) in enumerate(transFunc.age_groups)
        if in_group(infectee.age, ag)
            return gems_rand(rng, transFunc.age_transmission_rates[i])
        end
    end

    throw(ArgumentError("Infectee's age $(infectee.age) does not fall into any defined age group."))
end

# if no RNG was passed, use default RNG
transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16) = 
    transmission_probability(transFunc, infecter, infected, setting, tick, Random.default_rng())