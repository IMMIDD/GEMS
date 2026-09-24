export sample_contacts!, sample_contacts, sample_thinned_contacts!
export create_contact_sampling_method
export membership_changed!

###
### INTERFACE
###

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


###
### SCALED SAMPLING
### Scales a setting's contacts by both parties' scales there. A host draws `s_host * bound` times
### its sampler's contacts and keeps each with the contact's scale over `bound`, so every pair
### meets at `s_host * s_contact` times the unscaled rate. The part of the keep that is the same
### for every contact goes to the sampler, see `sample_thinned_contacts!`.
###

# Samples the host's contacts in `setting` into `contacts`, drawing into `draws` when the sampler
# has to be called more than once. Draws nothing extra while every scale involved is 1.
# `oversample` only acts without replacement, see `_sample_unique_scaled!`.
# `thin` keeps each contact with that probability on top of its scales.
# The sampler applies `thin` and the host's draw fraction, skipping those draws where it can.
function sample_scaled_contacts!(contacts::Vector{Individual}, draws::Vector{Individual},
        csm::ContactSamplingMethod, setting::Setting, idx::Int, present::AbstractVector{Individual},
        tick::Int16, replace::Bool, rng::Xoshiro, plans::ActivityPlanStore, cntnr::SettingsContainer,
        s_host::Float32, bound::Float32; oversample::Float32 = 1.0f0, thin::Float32 = 1.0f0)
    r = s_host * bound
    empty!(contacts)
    # a lone member could only meet itself
    (r == 0 || length(present) <= 1) && return contacts

    if r <= 1
        # one draw, the sampler thinning by `r * thin`, then by each contact's scale in place
        sample_thinned_contacts!(contacts, csm, setting, idx, present, tick, replace, rng, r * thin)
        kept = 0
        for c in contacts
            _keep_contact(c, bound, plans, setting, cntnr, rng) && (contacts[kept += 1] = c)
        end
        return resize!(contacts, kept)
    end

    replace ||
        return _sample_unique_scaled!(contacts, draws, csm, setting, idx, present, tick, rng, plans, cntnr, r, oversample, bound, thin)

    calls = floor(Int, r)
    frac = r - calls
    # samplers fill their buffer from the start, so each call draws into `draws`
    for call in 1:(calls + (frac > 0))
        # the last draw stands for the fraction beyond the whole ones
        f = call > calls ? frac : 1.0f0
        empty!(draws)
        sample_thinned_contacts!(draws, csm, setting, idx, present, tick, true, rng, f * thin)
        for c in draws
            _keep_contact(c, bound, plans, setting, cntnr, rng) && push!(contacts, c)
        end
    end
    return contacts
end

# Without replacement a contact drawn by several calls is kept once, with the weights of the calls
# that drew it summed. Exact while `s_host * s_contact <= 1`; above that the keep probability caps
# at 1, so a contact drawn often is met too rarely. `oversample` times the calls, each weighted down
# by it, shrink that bias at `oversample` times the sampler calls.
# The whole calls collect in `contacts`, the fractional last call stays in `draws`.
function _sample_unique_scaled!(contacts::Vector{Individual}, draws::Vector{Individual},
        csm::ContactSamplingMethod, setting::Setting, idx::Int, present::AbstractVector{Individual},
        tick::Int16, rng::Xoshiro, plans::ActivityPlanStore, cntnr::SettingsContainer,
        r::Float32, oversample::Float32, bound::Float32, thin::Float32)
    total = r * oversample
    calls = floor(Int, total)
    frac = total - calls
    unit = 1.0f0 / oversample
    for _ in 1:calls
        empty!(draws)
        sample_contacts!(draws, csm, setting, idx, present, tick, false, rng)
        append!(contacts, draws)
    end
    empty!(draws)
    frac > 0 && sample_contacts!(draws, csm, setting, idx, present, tick, false, rng)
    # QuickSort needs no scratch buffer
    sort!(contacts; by = id, alg = QuickSort)
    sort!(draws; by = id, alg = QuickSort)

    # merge both sorted lists; kept contacts and unmatched draws compact in place
    kept = 0
    unmatched = 0
    j = 1
    i = 1
    while i <= length(contacts)
        c = contacts[i]
        w = unit
        while i < length(contacts) && contacts[i + 1] === c
            w += unit
            i += 1
        end
        while j <= length(draws) && id(draws[j]) < id(c)
            draws[unmatched += 1] = draws[j]
            j += 1
        end
        if j <= length(draws) && draws[j] === c
            w += frac * unit
            j += 1
        end
        _keep_unique_contact(c, w, thin, bound, plans, setting, cntnr, rng) && (contacts[kept += 1] = c)
        i += 1
    end
    resize!(contacts, kept)
    for k in j:length(draws)
        draws[unmatched += 1] = draws[k]
    end
    for k in 1:unmatched
        _keep_unique_contact(draws[k], frac * unit, thin, bound, plans, setting, cntnr, rng) && push!(contacts, draws[k])
    end
    return contacts
end

# Keeps a drawn contact with its scale over `bound`, if it can be contacted here
@inline function _keep_contact(c::Individual, bound::Float32,
        plans::ActivityPlanStore, setting::Setting, cntnr::SettingsContainer, rng::Xoshiro)
    p = _membership_scale(plans, c, setting, cntnr) / bound
    kept = p >= 1 || gems_rand(rng) < p
    return kept && can_be_contacted(c, setting)
end

# Keeps a contact drawn without replacement with `thin` times its capped keep probability
@inline function _keep_unique_contact(c::Individual, w::Float32, thin::Float32, bound::Float32,
        plans::ActivityPlanStore, setting::Setting, cntnr::SettingsContainer, rng::Xoshiro)
    p = w * _membership_scale(plans, c, setting, cntnr) / bound
    kept = p >= 1 ? (thin >= 1 || gems_rand(rng) < thin) : gems_rand(rng) < p * thin
    return kept && can_be_contacted(c, setting)
end

###
### MEMBERSHIP SCALE
### An individual's scale in a setting, from its own plan entries. An entry that does not apply
### this tick contributes 0.
###

# nobody holds an entry for the GlobalSetting
@inline _membership_scale(::ActivityPlanStore, ::Individual, ::GlobalSetting, ::SettingsContainer) = 1.0f0

@inline function _membership_scale(plans::ActivityPlanStore, individual::Individual, s::T,
                                   ::SettingsContainer) where {T<:IndividualSetting}
    individual.plan_scaled || return 1.0f0
    # Float16 arithmetic is emulated in software
    return Float32(_effective_scale(plans, plan_slot(plans, individual, T, id(s))))
end

# A container holds no entry: the scales of the individual's open leaves below it, summed but
# capped at the larger of 1 and the largest, so presence there is normal unless its leaves say more.
function _membership_scale(plans::ActivityPlanStore, individual::Individual, c::C,
                           cntnr::SettingsContainer) where {C<:ContainerSetting}
    individual.plan_scaled || return 1.0f0
    L = _leaf_type(C)
    slots = plan_slots(plans, individual, L)
    # in c's frame, so a lone leaf entry is the one that put it there
    length(slots) == 1 && return Float32(_effective_scale(plans, first(slots)))
    leaves = settings(cntnr, L)
    below = _leaf_range(c)
    closed = (_pool(c)::HierarchicalSettingPool).closed != 0
    total = 0.0f0
    largest = 0.0f0
    for k in slots
        e = @inbounds plans.entries[k]
        leaf = leaves[setting_id(e)]
        Int(leaf.pool_leaf) in below || continue
        (!closed || _open_below(cntnr, leaf, c)) || continue
        _is_deceased(leaf, member_index(e)) && continue
        s = Float32(_effective_scale(plans, k))
        total += s
        largest = max(largest, s)
    end
    return min(total, max(1.0f0, largest))
end


###
### INCLUDE SAMPLING METHODS
###

# The src/contacts/sampling_methods folder contains a dedicated file for each built-in
# contact sampling method. Files starting with "csm_" define a `ContactSamplingMethod`
# with its `sample_contacts!` and `sample_thinned_contacts!` methods.

# include all Julia files from the "sampling_methods"-folder
include.(
    filter(
        contains(r".jl$"),
        readdir(_basefolder() * "/src/contacts/sampling_methods"; join=true)
    )
)


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
