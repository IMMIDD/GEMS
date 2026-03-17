export sample_contacts!, sample_contacts
export create_contact_sampling_method

"""
    sample_contacts!(indivs::Vector{Individual}, contact_sampling_method::ContactSamplingMethod, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)::ErrorException

Abstract function as Fallback if no specific method is available.
"""
function sample_contacts!(indivs::Vector{Individual}, contact_sampling_method::ContactSamplingMethod, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)::ErrorException
    error("Currently, no specific implementation of this function is known. Please provide a method for type: $(typeof(contact_sampling_method))")
end

"""
    sample_contacts!(indivs::Vector{Individual}, random_sampling_method::RandomSampling, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)::Vector{Individual}

Sample exactly 1 random contact from the individuals in `setting`.
"""
function sample_contacts!(indivs::Vector{Individual}, random_sampling_method::RandomSampling, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)::Vector{Individual}
    empty!(indivs)

    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    offset = gems_rand(rng, 1:length(present_inds)-1)
    contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
    push!(indivs, present_inds[contact_index])
    
    return indivs
end


"""
    sample_contacts!(indivs::Vector{Individual}, contactparameter_sampling::ContactparameterSampling, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)::Vector{Individual}

Sample random contacts based on a Poisson-Distribution spread around `contactparameter_sampling.contactparameter`.
The `replace` parameter determines whether contacts are sampled with replacement (`true`) or without replacement (`false`).
"""
function sample_contacts!(indivs::Vector{Individual}, contactparameter_sampling::ContactparameterSampling, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)::Vector{Individual}
    empty!(indivs)

    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    if length(present_inds) == 1
        return indivs
    end

    # get number of contacts
    number_of_contacts = gems_rand(rng, Poisson(contactparameter_sampling.contactparameter))

    if replace
        # sample contacts 
        for i in 1:number_of_contacts
            offset = gems_rand(rng, 1:length(present_inds)-1)
            contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
            push!(indivs, present_inds[contact_index])
        end
    else
        number_of_contacts = min(number_of_contacts, length(present_inds) - 1)
        resize!(indivs, number_of_contacts)

        gems_sample!(rng, present_inds[1:end-1], indivs; replace=false)
        for i = 1:length(indivs)
            if indivs[i] === present_inds[individual_index]
                indivs[i] = present_inds[end]
                break
            end
        end
    end
    
    return indivs
end

"""
    sample_contacts!(indivs::Vector{Individual}, contactparameter_sampling::AgeBasedContactSampling, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)::Vector{Individual}

Sample random contacts based on a spread around `contactparameter_sampling.contactparameter` with weighted sampling based on age distance.
"""
function sample_contacts!(indivs::Vector{Individual}, contactparameter_sampling::AgeBasedContactSampling, setting::Setting, individual_index::Int, present_inds::Vector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)::Vector{Individual}
    empty!(indivs)

    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    if length(present_inds) == 1
        return indivs
    end

    individual = present_inds[individual_index]

    # get sampling parameters
    expected_number_of_contacts = contactparameter_sampling.contactparameter
    if expected_number_of_contacts == 0.0
        return indivs
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
    number_of_contacts = gems_rand(rng, Poisson(expected_number_of_contacts * w * m_max))
    if number_of_contacts < 1
        return indivs
    end

    if replace
        # sample contacts 
        for i in 1:number_of_contacts
            offset = gems_rand(rng, 1:length(present_inds)-1)
            contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
            push!(indivs, present_inds[contact_index])
        end
    else
        number_of_contacts = min(number_of_contacts, length(present_inds) - 1)
        resize!(indivs, number_of_contacts)

        # Added rng to this call!
        gems_sample!(rng, present_inds[1:end-1], indivs; replace=false)
        for i = 1:length(indivs)
            if indivs[i] === present_inds[individual_index]
                indivs[i] = present_inds[end]
                break
            end
        end
    end

    # Second order sampling (i.e. structural one)
    keep_count = 0
    for i = 1:length(indivs)
        candidate = indivs[i]
        dest_bin = (candidate.age ÷ interval) + 1
        m = contact_matrix[orig_bin, dest_bin]
        
        if m > 0.0
            m = m / m_max # since we multiplied by m_max earlier
            r = gems_rand(rng)
            if r < m
                keep_count += 1
                indivs[keep_count] = candidate
            end
        end
    end
    
    # Shrink the indivs down to only the individuals that passed the probability check
    resize!(indivs, keep_count)
    
    return indivs
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

"""
    sample_contacts!(
        indivs::Vector{Individual},
        csm::ContactSamplingMethod, 
        setting::Setting, 
        individual_index::Int, 
        present_inds::Vector{Individual}, 
        tick::Int16; 
        replace::Bool = true, 
        rng::Xoshiro = DEFAULT_GEMS_RNG
    )

Wrapper for optional keyword arguments.
"""
function sample_contacts!(
    indivs::Vector{Individual},
    csm::ContactSamplingMethod, 
    setting::Setting, 
    individual_index::Int, 
    present_inds::Vector{Individual}, 
    tick::Int16; 
    replace::Bool = true, 
    rng::Xoshiro = DEFAULT_GEMS_RNG
)
    return sample_contacts!(indivs, csm, setting, individual_index, present_inds, tick, replace, rng)
end


"""
    sample_contacts(
        csm::ContactSamplingMethod, 
        setting::Setting, 
        individual_index::Int, 
        present_inds::Vector{Individual}, 
        tick::Int16,
        replace::Bool, 
        rng::Xoshiro
    )

Wrapper without buffer
"""
function sample_contacts(
    csm::ContactSamplingMethod, 
    setting::Setting, 
    individual_index::Int, 
    present_inds::Vector{Individual}, 
    tick::Int16,
    replace::Bool, 
    rng::Xoshiro
)
    indivs = Vector{Individual}()
    sample_contacts!(indivs, csm, setting, individual_index, present_inds, tick, replace, rng)
    return indivs
end


"""
    sample_contacts(
        csm::ContactSamplingMethod, 
        setting::Setting, 
        individual_index::Int, 
        present_inds::Vector{Individual}, 
        tick::Int16; 
        replace::Bool = true, 
        rng::Xoshiro = DEFAULT_GEMS_RNG
    )

Wrapper without buffer and optional keyword arguments
"""
function sample_contacts(
    csm::ContactSamplingMethod, 
    setting::Setting, 
    individual_index::Int, 
    present_inds::Vector{Individual}, 
    tick::Int16; 
    replace::Bool = true, 
    rng::Xoshiro = DEFAULT_GEMS_RNG
)
    indivs = Vector{Individual}()
    sample_contacts!(indivs, csm, setting, individual_index, present_inds, tick, replace, rng)
    return indivs
end