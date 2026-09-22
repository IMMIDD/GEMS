export sample_contacts!, sample_contacts, sample_thinned_contacts!
export create_contact_sampling_method
export membership_changed!

"""
    sample_contacts!(indivs::Vector{Individual}, contact_sampling_method::ContactSamplingMethod, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)

    Fallback: determine which keyword-based method  a user defined (mutating or non-mutating) and routes the internal positional call accordingly.

A sampler written against `Vector{Individual}` still works, via a deprecated path that copies.
"""
function sample_contacts!(
    indivs::Vector{Individual},
    csm::ContactSamplingMethod,
    setting::Setting,
    individual_index::Int,
    present_inds::AbstractVector{Individual},
    tick::Int16,
    replace::Bool,
    rng::Xoshiro
)
    # probe with what the setting supplied, not a hardcoded Vector
    P = typeof(present_inds)

    # mutating keyword method
    if _user_method(sample_contacts!, Tuple{Vector{Individual}, typeof(csm), Setting, Int, P, Int16}, 2)
        return sample_contacts!(indivs, csm, setting, individual_index, present_inds, tick; replace=replace, rng=rng)

    # non-mutating keyword method
    elseif _user_method(sample_contacts, Tuple{typeof(csm), Setting, Int, P, Int16}, 1)
        new_contacts = sample_contacts(csm, setting, individual_index, present_inds, tick; replace=replace, rng=rng)
        append!(indivs, new_contacts)
        return indivs

    # deprecated: sampler wants a Vector but we hold a view. Materialise and re-enter.
    elseif P !== Vector{Individual} && (
            _user_method(sample_contacts!, Tuple{Vector{Individual}, typeof(csm), Setting, Int, Vector{Individual}, Int16}, 2) ||
            _user_method(sample_contacts, Tuple{typeof(csm), Setting, Int, Vector{Individual}, Int16}, 1))
        @warn "$(typeof(csm)) types present_inds as Vector{Individual}. Widen it to AbstractVector{Individual} to avoid a copy per call." maxlog=1
        return sample_contacts!(indivs, csm, setting, individual_index, collect(present_inds), tick, replace, rng)

    # if they defined neither, throw error
    else
        error("Currently, no specific implementation of this function is known. Please provide a method for type: $(typeof(csm))")
    end
end

"""
    sample_thinned_contacts!(indivs::Vector{Individual}, csm::ContactSamplingMethod, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro, p::Float32)

Like `sample_contacts!`, but keeps each sampled contact independently with the same probability `p`.
Returns `indivs`, which is expected to be empty on entry.

Implement it for a sampling method that can skip the dropped contacts before drawing them.
At `p = 1` it must return exactly what `sample_contacts!` returns.
"""
function sample_thinned_contacts!(indivs::Vector{Individual}, csm::ContactSamplingMethod, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro, p::Float32)
    sample_contacts!(indivs, csm, setting, individual_index, present_inds, tick, replace, rng)
    return _keep_each!(indivs, p, rng)
end

"""
    sample_contacts!(indivs::Vector{Individual}, random_sampling_method::RandomSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)

Sample exactly 1 random contact from the individuals in `setting`. 
The `indivs` buffer is expected to be empty on entry and will be filled with the sampled contacts in-place.
"""
sample_contacts!(indivs::Vector{Individual}, random_sampling_method::RandomSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro) =
    sample_thinned_contacts!(indivs, random_sampling_method, setting, individual_index, present_inds, tick, replace, rng, 1.0f0)

"""
    sample_thinned_contacts!(indivs::Vector{Individual}, random_sampling_method::RandomSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro, p::Float32)

Sample 1 random contact from the individuals in `setting` with probability `p`, and none otherwise.
"""
function sample_thinned_contacts!(indivs::Vector{Individual}, random_sampling_method::RandomSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro, p::Float32)
    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    # decide whether the one contact is kept before drawing it
    p < 1 && gems_rand(rng) >= p && return indivs

    offset = gems_rand(rng, 1:length(present_inds) -1 )
    contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
    push!(indivs, present_inds[contact_index])
end


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
        return _draw_others!(indivs, present_inds, individual_index, number_of_contacts, rng)
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
    id = findfirst(x -> x == type_string || x == "$gems_string.$type_string", string.(_cached_subtypes(ContactSamplingMethod)))
    if isnothing(id)
        error("The provided type is not a valid subtype of $ContactSamplingMethod use '$(join(string.(_cached_subtypes(ContactSamplingMethod)), "', '", "' or '"))'!")
    end
    CSM_constructor = _cached_subtypes(ContactSamplingMethod)[id]

    # Convert the parameter keys to symbols for the use as keyword arguments
    # if no parameters are given, this evals to an empty Dict
    parameters = Dict(Symbol(k) => v for (k, v) in get(config, "parameters", Dict()))

    # when no parameters are given, the default constructor will be called
    return CSM_constructor(;parameters...)

end




"""
    sample_contacts(
        csm::ContactSamplingMethod, 
        setting::Setting, 
        individual_index::Int, 
        present_inds::AbstractVector{Individual}, 
        tick::Int16,
        replace::Bool, 
        rng::Xoshiro
    )

Wrapper for non-mutating function
"""
function sample_contacts(
    csm::ContactSamplingMethod, 
    setting::Setting, 
    individual_index::Int, 
    present_inds::AbstractVector{Individual}, 
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
        present_inds::AbstractVector{Individual}, 
        tick::Int16; 
        replace::Bool = true, 
        rng::Xoshiro = default_gems_rng()
    )

Wrapper for non-mutating function and keyword arguments
"""
function sample_contacts(
    csm::ContactSamplingMethod, 
    setting::Setting, 
    individual_index::Int, 
    present_inds::AbstractVector{Individual}, 
    tick::Int16; 
    replace::Bool = true, 
    rng::Xoshiro = default_gems_rng()
)
    indivs = Vector{Individual}()
    sample_contacts!(indivs, csm, setting, individual_index, present_inds, tick, replace, rng)
    return indivs
end

"""
    membership_changed!(csm::ContactSamplingMethod, setting::Setting)

Signals that `setting`'s members or frame changed, so a sampling method can drop state derived
from them. Called on member edits and deaths, and when a container's frame is rebuilt. No-op by default.
"""
membership_changed!(csm::ContactSamplingMethod, setting::Setting) = nothing

"""
    membership_changed!(csm::AgeBasedContactSampling, setting::Setting)

Drops the cached age pyramid; `sample_contacts!` refills it lazily.
"""
function membership_changed!(csm::AgeBasedContactSampling, setting::Setting)
    empty!(csm.age_pyramid)
    return nothing
end


###
### INTERNALS
###

# Does `f` have a method for `argtypes` defined against a *concrete* sampler type?
# `hasmethod` alone also matches our own generic wrapper, which would recurse back here.
# Used by the `sample_contacts!` fallback to tell a user-supplied method from one of ours.
function _user_method(f, argtypes::Type{<:Tuple}, csm_pos::Int)
    hasmethod(f, argtypes) || return false
    sig = Base.unwrap_unionall(which(f, argtypes).sig)
    return sig.parameters[csm_pos + 1] !== ContactSamplingMethod
end

# Appends `n` members drawn with replacement from everyone present but the one at `individual_index`
function _draw_others!(indivs::Vector{Individual}, present_inds::AbstractVector{Individual}, individual_index::Int, n::Int, rng::Xoshiro)
    n0 = length(indivs)
    resize!(indivs, n0 + n)
    @inbounds for i in 1:n
        offset = gems_rand(rng, 1:length(present_inds) - 1)
        contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
        indivs[n0 + i] = present_inds[contact_index]
    end
    return indivs
end

# Keeps each of `indivs` independently with probability `p`, drawing nothing when `p >= 1`
function _keep_each!(indivs::Vector{Individual}, p::Float32, rng::Xoshiro)
    p >= 1 && return indivs
    kept = 0
    for c in indivs
        gems_rand(rng) < p && (indivs[kept += 1] = c)
    end
    return resize!(indivs, kept)
end
