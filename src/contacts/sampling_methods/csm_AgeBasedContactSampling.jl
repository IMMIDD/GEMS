export AgeBasedContactSampling

# Per host age bin, the contact weight of all present members and of all but the host:
# `weight_with_host[a] = Σ_b c_b m_ab` and `weight_without_host[a] = Σ_b (c_b - δ_ab) m_ab` for bin counts `c`.
struct _AgeRateCache
    weight_with_host::Vector{Float64}
    weight_without_host::Vector{Float64}
end

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
    # each matrix row's largest entry, so a draw need not search its row
    row_max::Vector{Float64}
    # filled by the first `contact_rate`, and emptied with the age pyramid
    rate_cache::Union{Nothing, _AgeRateCache}

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
        return AgeBasedContactSampling(contactparameter, interval, contact_matrix, Float64[])
    end

    function AgeBasedContactSampling(contactparameter::Float64, interval::Int64, contact_matrix::ContactMatrix{Float64}, age_pyramid::Vector{Float64})
        if contactparameter < 0
            throw(ArgumentError("'contactparameter' is $contactparameter, but the 'contactparameter' has to be non-negative!"))
        end
        # a contact's acceptance m / m_max must be a probability
        any(<(0), contact_matrix.data) && throw(ArgumentError("'contact_matrix' has negative entries, but contact weights have to be non-negative!"))
        row_max = vec(maximum(contact_matrix.data, dims = 2))
        return new(contactparameter, interval, contact_matrix, age_pyramid, row_max, nothing)
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
        # sample contacts, each a uniform draw among everyone present but the individual
        n0 = length(indivs)
        resize!(indivs, n0 + number_of_contacts)
        @inbounds for i in 1:number_of_contacts
            offset = gems_rand(rng, 1:length(present_inds) - 1)
            contact_index = mod(individual_index + offset - 1, length(present_inds)) + 1
            indivs[n0 + i] = present_inds[contact_index]
        end
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
    contact_rate(contactparameter_sampling::AgeBasedContactSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16)::Float64

Returns the mean number of contacts left after the age filter, `contactparameter` times the
others' contact weight over everyone's, scaled by `n / (n - 1)`.
"""
function contact_rate(contactparameter_sampling::AgeBasedContactSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16)::Float64
    n = length(present_inds)
    (n <= 1 || contactparameter_sampling.contactparameter == 0) && return 0.0
    cache = _age_rate_cache!(contactparameter_sampling, present_inds)
    a = _age_bin(contactparameter_sampling, present_inds[individual_index])
    others = cache.weight_without_host[a]
    # nobody but the host has weight in its row
    others > 0 || return 0.0
    return contactparameter_sampling.contactparameter * n * others / ((n - 1) * cache.weight_with_host[a])
end

"""
    contact_rate_bound(contactparameter_sampling::AgeBasedContactSampling)::Float64

Returns twice the `contactparameter`, as leaving the host out raises the others' share by at most `n / (n - 1)`.
"""
contact_rate_bound(contactparameter_sampling::AgeBasedContactSampling)::Float64 = 2 * contactparameter_sampling.contactparameter

# the matrix row or column of `individual`'s age
@inline _age_bin(csm::AgeBasedContactSampling, individual::Individual) =
    (min(individual.age, csm.contact_matrix.aggregation_bound - 1) ÷ csm.contact_matrix.interval_steps) + 1

# The rate cache for `present_inds`, built on first use. Threads may build it at once, so it is
# published whole.
function _age_rate_cache!(csm::AgeBasedContactSampling, present_inds::AbstractVector{Individual})
    cache = csm.rate_cache
    cache === nothing || return cache
    m = csm.contact_matrix.data
    counts = zeros(Int, size(m, 1))
    for ind in present_inds
        counts[_age_bin(csm, ind)] += 1
    end
    weight_with_host = [sum(counts[b] * m[a, b] for b in eachindex(counts)) for a in eachindex(counts)]
    # summed per term, so a host alone in its row's support gives exactly 0
    weight_without_host = [sum((counts[b] - (a == b)) * m[a, b] for b in eachindex(counts)) for a in eachindex(counts)]
    cache = _AgeRateCache(weight_with_host, weight_without_host)
    csm.rate_cache = cache
    return cache
end

"""
    sample_k_contacts!(indivs::Vector{Individual}, csm::AgeBasedContactSampling, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, k::Int, rng::Xoshiro)

Appends `k` contacts by rejection: a uniform other, kept with its weight over the row's largest, as
`sample_contacts!` keeps its candidates.
"""
function sample_k_contacts!(indivs::Vector{Individual}, csm::AgeBasedContactSampling, setting::Setting,
        individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, k::Int, rng::Xoshiro)
    k > 0 || return indivs
    n = length(present_inds)
    a = _age_bin(csm, present_inds[individual_index])
    m = csm.contact_matrix.data
    m_max = csm.row_max[a]
    others = _age_rate_cache!(csm, present_inds).weight_without_host[a]
    others > 0 || error("nobody else in this setting has contact weight for age bin $a, so no contact can be drawn")
    # expected candidates per contact are m_max (n - 1) / others
    limit = ceil(Int, 100 * k * m_max * (n - 1) / others) + 100
    tries = 0
    while k > 0
        (tries += 1) > limit && error("drawing contacts by age did not finish; the contact rate cache may be stale")
        offset = gems_rand(rng, 1:(n - 1))
        c = present_inds[mod(individual_index + offset - 1, n) + 1]
        w = m[a, _age_bin(csm, c)]
        if w > 0.0 && gems_rand(rng) < w / m_max
            push!(indivs, c)
            k -= 1
        end
    end
    return indivs
end

"""
    membership_changed!(csm::AgeBasedContactSampling, setting::Setting)

Drops the cached age pyramid and rate cache; both refill lazily.
"""
function membership_changed!(csm::AgeBasedContactSampling, setting::Setting)
    empty!(csm.age_pyramid)
    csm.rate_cache = nothing
    return nothing
end
