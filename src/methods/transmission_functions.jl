export transmission_probability
export create_transmission_function

"""
    transmission_probability(transFunc::TransmissionFunction, infecter::Individual, infected::Individual, setting::Setting, tick::Int16)

General function for TransmissionFunction struct. Should be overwritten for newly created structs, as it only serves
to catch undefined `transmission_probability` functions.
"""
function transmission_probability(transFunc::TransmissionFunction, infecter::Individual, infected::Individual, setting::Setting, tick::Int16)::Float64
    @error "The transmission_probability function is not defined for the provided TransmissionFunction struct!"
end

"""
    transmission_probability(transFunc::ConstantTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16)

Calculates the transmission probability for the `ConstantTransmissionRate`. Returns the `transmission_rate`
for all individuals who have not been infected in the past. If the individual has already recovered,
the function returns `0.0`, assuming full indefinite natural immunity.

# Parameters

- `transFunc::ConstantTransmissionRate`: Transmission function struct
- `infecter::Individual`: Infecting individual
- `infected::Individual`: Individual to infect
- `setting::Setting`: Setting in which the infection happens
- `tick::Int16`: Current tick

# Returns

- `Float64`: Transmission probability p (`0 <= p <= 1`)

"""
function transmission_probability(transFunc::ConstantTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16)::Float64
    if  -1 < removed_tick(infected) <= tick # if the agent has already recovered (natural immunity)
        return 0.0
    end
    
    return transFunc.transmission_rate
end

"""
    transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16)

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

# Returns

- `Float64`: Transmission probability p (`0 <= p <= 1`)
"""
function transmission_probability(transFunc::AgeDependentTransmissionRate, infecter::Individual, infected::Individual, setting::Setting, tick::Int16)::Float64
    if  -1 < removed_tick(infected) <= tick # if the agent has already recovered (natural immunity)
        return 0.0
    end
    
    for (i,ageGroup) in enumerate(transFunc.ageGroups)
        if ageGroup[1] <= infected.age <= ageGroup[2]
            return rand(transFunc.ageTransmissions[i])
        end
    end
    return rand(transFunc.transmission_rate)
end

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
    gems_string = string(nameof(@__MODULE__))
    # we need to check the TF-name with and without the "GEMS.xxx" namespace
    # qualifier as the module name will be present if GEMS is imported as
    # a depenedncy into another module
    id = findfirst(x -> x == type_string || x == "$gems_string.$type_string", string.(subtypes(TransmissionFunction)))
    if isnothing(id)
        error("The provided type is not a valid subtype of $TransmissionFunction use '$(join(string.(subtypes(TransmissionFunction)), "', '", "' or '"))'!")
    end
    type = subtypes(TransmissionFunction)[id]

    

    # Convert the parameter keys to symbols for the use as keyword arguments
    parameters = Dict(Symbol(k) => v for (k, v) in get(config, "parameters", Dict()))

    return type(;parameters...)
end