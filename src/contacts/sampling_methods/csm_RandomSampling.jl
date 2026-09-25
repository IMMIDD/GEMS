export RandomSampling

"""
    RandomSampling <: ContactSamplingMethod

Sample exactly one contact per individual inside a Setting. The sampling will be random.
"""
struct RandomSampling <: ContactSamplingMethod
    
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
