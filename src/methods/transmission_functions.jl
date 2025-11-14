export transmission_probability
export create_transmission_function

###
### ABSTRACT INTERFACE
###

# fallback
function transmission_probability(transFunc::TransmissionFunction, infecter::Individual, infected::Individual, setting::Setting, tick::Int16)::Float64
    @error "The transmission_probability function is not defined for the provided TransmissionFunction struct $(typeof(transFunc))."
end

"""
    transmission_probability(transFunc::TransmissionFunction, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())

General function for TransmissionFunction struct. Should be overwritten for newly created structs, as it only serves
to catch undefined `transmission_probability` functions.
"""
function transmission_probability(transFunc::TransmissionFunction, infecter::Individual, infected::Individual, setting::Setting, tick::Int16, rng::AbstractRNG)::Float64
    # this is the fallback function that is called if no of the specific transmission_proability
    # functions has already fired. In that case, we try finding a transmission_probability
    # function without a dedicated RNG passed. If that doesn't work, the default 
    # TF-function (above) will trigger an error
    return transmission_probability(transFunc, infecter, infected, setting, tick)
end

###
### IMPLEMENTATIONS
###


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

"""
    transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16; rng::AbstractRNG = Random.default_rng())

Calculates the transmission probability for the `AgeDependentTransmissionRate`. Selects the correct distribution 
dependent on the age of the potentially infected agent from the `AgeDependentTransmissionRate`, draws from it and
returns the value. If no age group is found for the individual the transmission rate is drawn from the transmission_rate distribution.
If the individual has already recovered, the function returns `0.0`, assuming full indefinite natural immunity.

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
    
    for (i,ageGroup) in enumerate(transFunc.ageGroups)
        if ageGroup[1] <= infectee.age <= ageGroup[2]
            return gems_rand(rng, transFunc.ageTransmissions[i])
        end
    end
    return gems_rand(rng, transFunc.transmission_rate)
end
# if no RNG was passed, use default RNG
transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16) = 
    transmission_probability(transFunc, infecter, infected, setting, tick, Random.default_rng())

"""
    create_transmission_function(config::Dict)

Creates a transmission function struct using the details specified in the provided dictionary. 
The dictionary must contain the keys type and parameters where type corresponds to the 
name of the `TransmissionFunction` struct to be used and parameters holds the keyword
arguments for the constructer of this `TransmissionFunction`. If the provided type does not 
correspond to the name of a `TransmissionFunction` an error is thrown.

# Returns

- `<:TransmissionFunction`: New instance of a `TransmissionFunction` struct.
"""
function create_transmission_function(config::Dict)

    # Parse the type provided as a string
    type_string = get(config, "type", "")
    # get subtype so it can be instantiated
    type = get_subtype(type_string, TransmissionFunction)

    # Convert the parameter keys to symbols for the use as keyword arguments
    parameters = Dict(Symbol(k) => v for (k, v) in get(config, "parameters", Dict()))

    return type(;parameters...)
end