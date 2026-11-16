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
function sample_contacts!(indivs::Vector{Individual}, random_sampling_method::RandomSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro)
    if isempty(present_inds)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    offset = gems_rand(rng, 1:length(present_inds) -1 )
    contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
    push!(indivs, present_inds[contact_index])
end
