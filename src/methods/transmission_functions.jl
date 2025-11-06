export transmission_probability

"""
    transmission_probability(transFunc::TransmissionFunction, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())

General function for TransmissionFunction struct. Should be overwritten for newly created structs, as it only serves
to catch undefined `transmission_probability` functions.
"""
function transmission_probability(transFunc::TransmissionFunction, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())::Float64
    @error "The transmission_probability function is not defined for the provided TransmissionFunction struct!"
end

"""
    transmission_probability(transFunc::ConstantTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())

Calculates the transmission probability for the `ConstantTransmissionRate`. Returns the `transmission_rate`
for all individuals who have not been infected in the past. If the individual has already recovered,
the function returns `0.0`, assuming full indefinite natural immunity.

# Parameters

- `transFunc::ConstantTransmissionRate`: Transmission function struct
- `infecter::Individual`: Infecting individual
- `infected::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `rng::AbstractRNG`: RNG used for probability. Uses Random's default RNG as default.

# Returns

- `Float64`: Transmission probability p (`0 <= p <= 1`)

"""
function transmission_probability(transFunc::ConstantTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())::Float64
    if  -1 < recovery(infected) <= tick # if the agent has already recovered (natural immunity)
        return 0.0
    end
    
    return transFunc.transmission_rate
end

"""
    transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())

Calculates the transmission probability for the `AgeDependentTransmissionRate`. Selects the correct distribution 
dependent on the age of the potentially infected agent from the `AgeDependentTransmissionRate`, draws from it and
returns the value. If no age group is found for the individual the transmission rate is drawn from the transmission_rate distribution.
If the individual has already recovered, the function returns `0.0`, assuming full indefinite natural immunity.

# Parameters

- `transFunc::AgeDependentTransmissionRate`: Transmission function struct
- `infecter::Individual`: Infecting individual
- `infected::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick
- `rng::AbstractRNG`: RNG used for probability. Uses Random's default RNG as default.

# Returns

- `Float64`: Transmission probability p (`0 <= p <= 1`)
"""
function transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())::Float64
    if  -1 < recovery(infected) <= tick # if the agent has already recovered (natural immunity)
        return 0.0
    end
    
    for (i,ageGroup) in enumerate(transFunc.ageGroups)
        if ageGroup[1] <= infected.age <= ageGroup[2]
            return gems_rand(rng, transFunc.ageTransmissions[i])
        end
    end
    return rand(transFunc.transmission_rate)
end