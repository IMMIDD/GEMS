export sample_contacts
export create_contact_sampling_method

"""
    sample_contacts(contact_sampling_method::ContactSamplingMethod, setting::Setting, individual::Individual, tick::Int16)::ErrorException

Abstract function as Fallback if no specific method is available.
"""
function sample_contacts(contact_sampling_method::ContactSamplingMethod, setting::Setting, individual::Individual, present_inds::Vector{Individual}, tick::Int16)::ErrorException
    error("Currently, no specific implementation of this function is known. Please provide a method for type: $(typeof(contact_sampling_method))")
end

"""
    sample_contacts(random_sampling_method::RandomSampling, setting::Setting, individual::Individual, tick::Int16)::Vector{Individual}

Sample exactly 1 random contact from the individuals in `setting`.
"""
function sample_contacts(random_sampling_method::RandomSampling, setting::Setting, individual::Individual, present_inds::Vector{Individual}, tick::Int16)::Vector{Individual}

    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    return sample(present_inds, 1; replace=true)
end


"""
    sample_contacts(contactparameter_sampling::ContactparameterSampling, setting::Setting, individual::Individual, tick::Int16)::Vector{Individual}

Sample random contacts based on a Poisson-Distribution spread around `contactparameter_sampling.contactparameter`.
"""
function sample_contacts(contactparameter_sampling::ContactparameterSampling, setting::Setting, individual::Individual, present_inds::Vector{Individual}, tick::Int16)::Vector{Individual}

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

    cnt = 0
    # Draw until contact list is filled, skip whenever the index individual was selected
    while cnt < number_of_contacts
        contact = rand(present_inds)
        # if contact is NOT index individual, add them to contact list
        if Ref(contact) .!== Ref(individual)
            res[cnt + 1] = contact
            cnt += 1
        end
    end
    
    return res
end

"""
    sample_contacts(contactparameter_sampling::ContactAgeBasedparameterSampling, setting::Setting, individual::Individual, tick::Int16)::Vector{Individual}

Sample random contacts based on a spread around `contactparameter_sampling.contactparameter` with weighted sampling based on age distance.
We sample according to formula
pi = e * wi * qi * mi / N
where e - expected number of contacts, wi - normalization factor, qi - age group probability based on the age pyramid,
mi - mixing factor between age groups, N - number of agents
Normalization factor is required to normalize the sampling ditribution in order to
get expected number of contacts in the end.
We use two fold approach.
Firstly, we sample uniformly with probability pi = e * wi * qi * m_max / N
m_max - maximal mixing factor between age groups
Secondly, we sample with adapted probability mi = mi / m_max
"""
function sample_contacts(contactparameter_sampling::ContactAgeBasedparameterSampling, setting::Setting, individual::Individual, present_inds::Vector{Individual}, tick::Int16)::Vector{Individual}

    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    if length(present_inds) == 1
        return Individual[]
    end

    # get sampling parameters
    expected_number_of_contacts = contactparameter_sampling.contactparameter
    if expected_number_of_contacts == 0.0
        return Individual[]
    end
    interval = contactparameter_sampling.contact_matrix.interval_steps
    max_age = contactparameter_sampling.contact_matrix.aggregation_bound
    orig_bin = (individual.age ÷ interval) + 1
    contact_matrix::Matrix{Float64} = contactparameter_sampling.contact_matrix.data
    age_pyramid = contactparameter_sampling.age_pyramid
    # if age_pyramid is not ready compute it
    if size(age_pyramid)[1] == 0
        age_pyramid = zeros(size(contact_matrix)[1])
        for ind in present_inds
            interval_id = ind.age ÷ interval + 1
            age_pyramid[interval_id] += 1
        end
        age_pyramid = age_pyramid ./ sum(age_pyramid)
        contactparameter_sampling.age_pyramid = age_pyramid
    end
    # get uniform sampling parameters
    # i.e. maximal probability from contact matrix and compute normalization factor
    w = age_pyramid' * contact_matrix[orig_bin, :]
    w = 1 / w
    m_max = maximum(contact_matrix[orig_bin, :])
    # first order sampling (i.e. uniform), qi is missing since we sample from population according to age distribution
    number_of_contacts = rand(Poisson(expected_number_of_contacts * w * m_max))
    if number_of_contacts < 1
        return Individual[]
    end
    res = Vector{Individual}(undef, number_of_contacts)
    sample!(present_inds, res; replace=false)
    for i = 1:length(res)
        if Ref(individual) == Ref(res[i])
            while Ref(individual) == Ref(res[i])
                res[i] = rand(present_inds)
            end
            break
        end
    end
    # Second order sampling (i.e. structural one)
    out = Individual[]
    for i = 1:number_of_contacts
        dest_bin = (res[i].age ÷ interval) + 1
        m = contact_matrix[orig_bin, dest_bin]
        if m > 0.0
            m = m / m_max # since we multiplied by m_max in line no. 113
            r = rand()
            if r < m
                push!(out, res[i])
            end
        end
    end
    return out
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

