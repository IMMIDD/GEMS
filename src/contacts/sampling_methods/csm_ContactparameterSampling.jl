export ContactparameterSampling

"""
    ContactparameterSampling <: ContactSamplingMethod

Sample random contacts based on a Poisson-Distribution spread around `contactparameter`.
If provided with no parameter, `0` contacts are assumed.
"""
struct ContactparameterSampling <: ContactSamplingMethod
    contactparameter::Float64

    function ContactparameterSampling(contactparameter::Float64)
        if contactparameter < 0
            throw(ArgumentError("'contactparameter' is $contactparameter, but the 'contactparameter' has to be non-negative!"))
        end

        return new(contactparameter)
    end
    function ContactparameterSampling(contactparameter::Int64)
        if contactparameter < 0
            throw(ArgumentError("'contactparameter' is $contactparameter, but the 'contactparameter' has to be non-negative!"))
        end

        return new(contactparameter)
    end

    ContactparameterSampling(; contactparameter = 0) = ContactparameterSampling(contactparameter)
end

# empty constructor calls constructor with 0 contacts
#ContactparameterSampling() = ContactparameterSampling(0)

"""
    sample_contacts!(indivs::Vector{Individual}, contactparameter_sampling::ContactparameterSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)

Sample random contacts based on a Poisson-Distribution spread around `contactparameter_sampling.contactparameter`.
The `replace` parameter determines whether contacts are sampled with replacement (`true`) or without replacement (`false`).
The `indivs` buffer is expected to be empty on entry and will be filled with the sampled contacts in-place.
"""
sample_contacts!(indivs::Vector{Individual}, contactparameter_sampling::ContactparameterSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro) =
    sample_thinned_contacts!(indivs, contactparameter_sampling, setting, individual_index, present_inds, tick, replace, rng, 1.0f0)

"""
    sample_thinned_contacts!(indivs::Vector{Individual}, contactparameter_sampling::ContactparameterSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro, p::Float32)

With replacement, draws only the kept contacts: their number is Poisson with `p` times `contactparameter_sampling.contactparameter`.
Without replacement, samples as `sample_contacts!` does and then keeps each contact with probability `p`.
"""
function sample_thinned_contacts!(indivs::Vector{Individual}, contactparameter_sampling::ContactparameterSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro, p::Float32)
    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    if length(present_inds) == 1
        return indivs
    end

    if replace
        # a Poisson number of contacts, each kept with `p`, is a Poisson number with `p` times the mean
        number_of_contacts = gems_rand(rng, Poisson(contactparameter_sampling.contactparameter * p))
        # each a uniform draw among everyone present but the individual
        n0 = length(indivs)
        resize!(indivs, n0 + number_of_contacts)
        @inbounds for i in 1:number_of_contacts
            offset = gems_rand(rng, 1:length(present_inds) - 1)
            contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
            indivs[n0 + i] = present_inds[contact_index]
        end
        return indivs
    end

    # get number of contacts
    number_of_contacts = gems_rand(rng, Poisson(contactparameter_sampling.contactparameter))
    number_of_contacts = min(number_of_contacts, length(present_inds) - 1)
    resize!(indivs, number_of_contacts)

    gems_sample!(rng, @view(present_inds[1:end-1]), indivs; replace=false)
    for i = 1:length(indivs)
        if indivs[i] === present_inds[individual_index]
            indivs[i] = present_inds[end]
            break
        end
    end
    return _keep_each!(indivs, p, rng)
end

"""
    contact_rate(contactparameter_sampling::ContactparameterSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16)::Float64

Returns `contactparameter`, or 0 when nobody else is present.
"""
contact_rate(contactparameter_sampling::ContactparameterSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16)::Float64 =
    length(present_inds) > 1 ? contactparameter_sampling.contactparameter : 0.0

"""
    contact_rate_bound(contactparameter_sampling::ContactparameterSampling)::Float64

Returns `contactparameter`.
"""
contact_rate_bound(contactparameter_sampling::ContactparameterSampling)::Float64 = contactparameter_sampling.contactparameter

"""
    sample_k_contacts!(indivs::Vector{Individual}, contactparameter_sampling::ContactparameterSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, k::Int, rng::Xoshiro)

Appends `k` contacts, each a uniform draw among everyone present but the individual.
"""
function sample_k_contacts!(indivs::Vector{Individual}, contactparameter_sampling::ContactparameterSampling, setting::Setting,
        individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, k::Int, rng::Xoshiro)
    n0 = length(indivs)
    resize!(indivs, n0 + k)
    @inbounds for i in 1:k
        offset = gems_rand(rng, 1:length(present_inds) - 1)
        contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
        indivs[n0 + i] = present_inds[contact_index]
    end
    return indivs
end
