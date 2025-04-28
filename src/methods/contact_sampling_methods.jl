export sample_contacts
export create_contact_sampling_method

"""
    sample_contacts(contact_sampling_method::ContactSamplingMethod, setting::Setting, individual::Individual, tick::Int16)::ErrorException

Abstract function as Fallback if no specific method is available.
"""
function sample_contacts(contact_sampling_method::ContactSamplingMethod, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16)::ErrorException
    error("Currently, no specific implementation of this function is known. Please provide a method for type: $(typeof(contact_sampling_method))")
end

"""
    sample_contacts(random_sampling_method::RandomSampling, setting::Setting, individual::Individual, tick::Int16)::Vector{Individual}

Sample exactly 1 random contact from the individuals in `setting`.
"""
function sample_contacts(random_sampling_method::RandomSampling, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16)::Vector{Individual}

    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    offset = rand(1:length(present_inds)-1)
    contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
    return [present_inds[contact_index]]
end


"""
    sample_contacts(contactparameter_sampling::ContactparameterSampling, setting::Setting, individual::Individual, tick::Int16)::Vector{Individual}

Sample random contacts based on a Poisson-Distribution spread around `contactparameter_sampling.contactparameter`.
"""
function sample_contacts(contactparameter_sampling::ContactparameterSampling, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16)::Vector{Individual}

    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    if length(present_inds) == 1
        return Individual[]
    end

    # get number of contacts
    number_of_contacts = rand(Poisson(contactparameter_sampling.contactparameter))
    # number_of_contacts = Int64(contactparameter_sampling.contactparameter)
    res = Vector{Individual}(undef, number_of_contacts)
    
    # sample contacts (excluding last individual in present_inds)
    for i in 1:number_of_contacts
        offset = rand(1:length(present_inds)-1)
        contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
        res[i] = present_inds[contact_index]
    end
    
    return res
end


"""
    create_contact_sampling_method(config::Dict)

Creates a ContactSamplingMethod (CSM) struct using the details specified in the provided dictionary. 
The dictionary must contain the keys "type" where type corresponds to the 
name of the `ContactSamplingMethod` struct to be used.
Optionaly the Dict can have the key "parameters". These will be used, to construct the CSM defined by "type". When "type" doesn't have attributes, "parameters" can be ommited.
"""
function create_contact_sampling_method(config::Dict)       
    
    # find id of the concrete subtype matching "type" from `config`
    id = findfirst(x -> x == get(config, "type", ""), string.(subtypes(ContactSamplingMethod)))
    if isnothing(id)
        error("The provided type is not a valid subtype of $ContactSamplingMethod use '$(join(string.(subtypes(ContactSamplingMethod)), "', '", "' or '"))'!")
    end
    CSM_constructor = subtypes(ContactSamplingMethod)[id]

    # Convert the parameter keys to symbols for the use as keyword arguments
    # if no parameters are given, this evals to an empty Dict
    parameters = Dict(Symbol(k) => v for (k, v) in get(config, "parameters", Dict()))

    # when no parameters are given, the default constructor will be called
    return CSM_constructor(;parameters...)

end

