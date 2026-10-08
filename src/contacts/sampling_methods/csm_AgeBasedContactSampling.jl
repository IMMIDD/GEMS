export AgeBasedContactSampling

"""
    AgeBasedContactSampling <: ContactSamplingMethod

Sample random contacts based on a Poissoin-Distribution spread around `contactparameter_sampling.contactparameter` with weighted sampling based on age distance.
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

# Parameters

- `contactparameter::Float64`: Expected value of a Poisson-Distribution used to draw the number of contacts
- `contact_matrix_file::String`: String path to a file with an `NxN` contact probability matrix
- `interval::Int64`: Year-intervals of contact matrix (e.g., 5 means, the data contains age-age-couplings for 5-year age groups)
"""
mutable struct AgeBasedContactSampling <: ContactSamplingMethod
    contactparameter::Float64
    interval::Int64
    contact_matrix::ContactMatrix{Float64}
    age_pyramid::Vector{Float64} #it will be computed in sample_contacts method

    function AgeBasedContactSampling(; contactparameter::Float64, contact_matrix_file::String, interval::Int64)
        if contactparameter < 0
            throw(ArgumentError("'contactparameter' is $contactparameter, but the 'contactparameter' has to be non-negative!"))
        end
        matrix = readdlm(contact_matrix_file)
        for i in 1:size(matrix)[1]
            s = sum(matrix[i, :])
            if abs(s - 1.0) > 1e-10
                throw(ArgumentError("Sum of row $i in 'contact_matrix' is $s, but the sum has to be equal to 1.0!"))
            end
        end
        aggregation_bound = size(matrix)[1] * interval
        contact_matrix = ContactMatrix{Float64}(matrix, interval, aggregation_bound)
        return new(contactparameter, interval, contact_matrix, Float64[])
    end

    function AgeBasedContactSampling(contactparameter::Float64, interval::Int64, contact_matrix::ContactMatrix{Float64}, age_pyramid::Vector{Float64})
        if contactparameter < 0
            throw(ArgumentError("'contactparameter' is $contactparameter, but the 'contactparameter' has to be non-negative!"))
        end
        return new(contactparameter, interval, contact_matrix, age_pyramid)
    end
end

"""
    sample_contacts!(indivs::Vector{Individual}, contactparameter_sampling::AgeBasedContactSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)

Sample random contacts based on a spread around `contactparameter_sampling.contactparameter` with weighted sampling based on age distance.
The `indivs` buffer is expected to be empty on entry and will be filled with the sampled contacts in-place.
"""
sample_contacts!(indivs::Vector{Individual}, contactparameter_sampling::AgeBasedContactSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro) =
    sample_thinned_contacts!(indivs, contactparameter_sampling, setting, individual_index, present_inds, tick, replace, rng, 1.0f0)

"""
    sample_thinned_contacts!(indivs::Vector{Individual}, contactparameter_sampling::AgeBasedContactSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro, p::Float32)

With replacement, draws only the first-order contacts that are kept: their number is Poisson with `p` times the mean.
Without replacement, samples as `sample_contacts!` does and then keeps each contact with probability `p`.
"""
function sample_thinned_contacts!(indivs::Vector{Individual}, contactparameter_sampling::AgeBasedContactSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro, p::Float32)
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
    max_age = contactparameter_sampling.contact_matrix.aggregation_bound - 1
    orig_bin = (min(individual.age, max_age) ÷ interval) + 1
    contact_matrix::Matrix{Float64} = contactparameter_sampling.contact_matrix.data
    age_pyramid = contactparameter_sampling.age_pyramid
    
    # if age_pyramid is not ready compute it
    if size(age_pyramid)[1] == 0
        age_pyramid = zeros(size(contact_matrix)[1])
        for ind in present_inds
            interval_id = min(ind.age, max_age) ÷ interval + 1
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
    # with replacement, only the contacts `p` keeps are drawn
    mean_contacts = expected_number_of_contacts * w * m_max
    number_of_contacts = gems_rand(rng, Poisson(replace ? mean_contacts * p : mean_contacts))
    if number_of_contacts < 1
        return indivs
    end

    if replace
        # sample contacts 
        _draw_others!(indivs, present_inds, individual_index, number_of_contacts, rng)
    else
        number_of_contacts = min(number_of_contacts, length(present_inds) - 1)
        resize!(indivs, number_of_contacts)

        # Added rng to this call!
        gems_sample!(rng, @view(present_inds[1:end-1]), indivs; replace=false)
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
        dest_bin = (min(candidate.age, max_age) ÷ interval) + 1
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

    # without replacement, the kept contacts are thinned after sampling
    return replace ? indivs : _keep_each!(indivs, p, rng)
end

"""
    membership_changed!(csm::AgeBasedContactSampling, setting::Setting)

Drops the cached age pyramid; `sample_contacts!` refills it lazily.
"""
function membership_changed!(csm::AgeBasedContactSampling, setting::Setting)
    empty!(csm.age_pyramid)
    return nothing
end
