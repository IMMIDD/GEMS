export sample_contacts
export create_contact_sampling_method

"""
    sample_contacts(contact_sampling_method::ContactSamplingMethod, setting::Setting, individual::Individual, tick::Int16; rng::AbstractRNG = Random.default_rng())::ErrorException

Abstract function as Fallback if no specific method is available.
"""
function sample_contacts(contact_sampling_method::ContactSamplingMethod, setting::Setting, individual::Individual, present_inds::Vector{Individual}, tick::Int16; rng::AbstractRNG = Random.default_rng())::ErrorException
    error("Currently, no specific implementation of this function is known. Please provide a method for type: $(typeof(contact_sampling_method))")
end

"""
    sample_contacts(random_sampling_method::RandomSampling, setting::Setting, individual::Individual, tick::Int16)::Vector{Individual}

Sample exactly 1 random contact from the individuals in `setting`.
"""
function sample_contacts(random_sampling_method::RandomSampling, setting::Setting, individual::Individual, present_inds::Vector{Individual}, tick::Int16; rng::AbstractRNG = Random.default_rng())::Vector{Individual}

    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    return sample(rng, present_inds, 1; replace=true)
end


"""
    sample_contacts(contactparameter_sampling::ContactparameterSampling, setting::Setting, individual::Individual, tick::Int16)::Vector{Individual}

Sample random contacts based on a Poisson-Distribution spread around `contactparameter_sampling.contactparameter`.
"""
function sample_contacts(contactparameter_sampling::ContactparameterSampling, setting::Setting, individual::Individual, present_inds::Vector{Individual}, tick::Int16; rng::AbstractRNG = Random.default_rng())::Vector{Individual}

    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    if length(present_inds) == 1
        return Individual[]
    end

    # get number of contacts
    number_of_contacts = rand(rng, Poisson(contactparameter_sampling.contactparameter))
    # number_of_contacts = Int64(contactparameter_sampling.contactparameter)
    res = Vector{Individual}(undef, number_of_contacts)

    cnt = 0
    # Draw until contact list is filled, skip whenever the index individual was selected
    while cnt < number_of_contacts
        contact = rand(rng, present_inds)
        # if contact is NOT index individual, add them to contact list
        if Ref(contact) .!== Ref(individual)
            res[cnt + 1] = contact
            cnt += 1
        end
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

    type_string = get(config, "type", "")
    gems_string = string(nameof(@__MODULE__))
    # we need to check the TF-name with and without the "GEMS.xxx" namespace
    # qualifier as the module name will be present if GEMS is imported as
    # a depenedncy into another module
    id = findfirst(x -> x == type_string || x == "$gems_string.$type_string", string.(subtypes(ContactSamplingMethod)))
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

