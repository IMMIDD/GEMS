export sample_contacts!, sample_contacts
export contact_rate, contact_rate_bound, sample_k_contacts!
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
    contact_rate(csm::ContactSamplingMethod, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16)::Float64

The mean number of contacts `sample_contacts!` returns with `replace = true`. Defining it promises
that number is Poisson and its contacts are independent of each other and of their number, which
lets the simulation draw the number before it touches the setting.
"""
function contact_rate(csm::ContactSamplingMethod, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16)::Float64
    error("$(typeof(csm)) defines no contact_rate. Was it set without `contact_sampling_method!(sim, setting, csm)`?")
end

"""
    contact_rate_bound(csm::ContactSamplingMethod)::Float64

An upper bound on `contact_rate` for any host, setting holding `csm` and tick. Defaults to `Inf`,
meaning `csm` defines no `contact_rate`.
"""
contact_rate_bound(csm::ContactSamplingMethod)::Float64 = Inf

"""
    sample_k_contacts!(indivs::Vector{Individual}, csm::ContactSamplingMethod, setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, k::Int, rng::Xoshiro)

Appends exactly `k` contacts to `indivs`, each drawn as one of `sample_contacts!`'s with `replace = true`.
Defaults to keeping the first `k` of repeated `sample_contacts!` calls, which `contact_rate`'s promise makes
exact; define it to skip the discarded draws.
"""
function sample_k_contacts!(indivs::Vector{Individual}, csm::ContactSamplingMethod, setting::Setting,
        individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16, k::Int, rng::Xoshiro)
    k > 0 || return indivs
    rate = contact_rate(csm, setting, individual_index, present_inds, tick)
    rate > 0 || error("$(typeof(csm)) has contact_rate 0 here, so it cannot draw $k contacts")
    # a method that keeps returning nobody has a wrong contact_rate
    limit = ceil(Int, 100 * k / rate) + 100
    draws = _contact_scratch()
    calls = 0
    while k > 0
        (calls += 1) > limit && error("$(typeof(csm)) returns fewer contacts than its contact_rate")
        sample_contacts!(empty!(draws), csm, setting, individual_index, present_inds, tick, true, rng)
        n = min(k, length(draws))
        append!(indivs, view(draws, 1:n))
        k -= n
    end
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

Frames are rebuilt in parallel, so this can run for several settings at once. A method with
state must keep it per setting, as settings hold their own copy of a mutable method.
"""
membership_changed!(csm::ContactSamplingMethod, setting::Setting) = nothing


###
### SCALED SAMPLING
### Scales a setting's contacts by both parties' scales there, so every pair meets at `s_host * s_contact`
### times the unscaled rate. With `scale_bound` the largest scale there and `thin` the chance to keep a
### contact at all, a host:
### - draws contacts at `rate * s_host * scale_bound * thin`, with `rate` its sampler's (`_visit_rate`)
### - keeps each with the contact's scale over `scale_bound` (`_keep_contact`)
### A method with `contact_rate` draws that count at once, or thins one drawn before the setting was
### loaded at bounds on each factor. Any other is called `s_host * scale_bound` times, each thinned.
###

"""
    sample_scaled_contacts!(contacts, draws, csm, setting, idx, present, tick, replace, rng, plans, cntnr,
        s_host, scale_bound; oversample = 1.0f0, thin = 1.0f0, drawn = 0, drawn_rate = Inf)

Samples the host's contacts in `setting` into `contacts`, scaled by the host's and each contact's
scale there. Draws nothing extra while every scale involved is 1.

# Parameters

- `contacts::Vector{Individual}`: Buffer the sampled contacts are written to, emptied first
- `draws::Vector{Individual}`: Scratch buffer for when the sampler has to be called more than once
- `csm::ContactSamplingMethod`: The setting's sampling method
- `setting::Setting`: Setting the host meets its contacts in
- `idx::Int`: The host's position in `present`
- `present::AbstractVector{Individual}`: Everyone present in `setting`, the host included
- `tick::Int16`: Current tick
- `replace::Bool`: Whether contacts are drawn with replacement
- `rng::Xoshiro`: Random number generator
- `plans::ActivityPlanStore`: Activity plans the contacts' scales are read from
- `cntnr::SettingsContainer`: Settings container, for scales in container settings
- `s_host::Float32`: The host's scale in `setting`
- `scale_bound::Float32`: Upper bound on any member's scale in `setting`, see `_scale_bound`
- `oversample::Float32`: Without replacement, calls the sampler this many times more to shrink the
  bias above scale 1, see `_sample_unique_scaled!`
- `thin::Float32`: Probability to keep each contact, on top of its scales
- `drawn::Int`: Number of contacts drawn before the visit at rate `drawn_rate`, which are thinned to
  the visit's rate. Needs a method with `contact_rate` and `replace`
- `drawn_rate::Float64`: Rate `drawn` was drawn at, at least the visit's rate; `Inf` if nothing was drawn
"""
function sample_scaled_contacts!(contacts::Vector{Individual}, draws::Vector{Individual},
        csm::ContactSamplingMethod, setting::Setting, idx::Int, present::AbstractVector{Individual},
        tick::Int16, replace::Bool, rng::Xoshiro, plans::ActivityPlanStore, cntnr::SettingsContainer,
        s_host::Float32, scale_bound::Float32; oversample::Float32 = 1.0f0, thin::Float32 = 1.0f0,
        drawn::Int = 0, drawn_rate::Float64 = Inf)
    r = s_host * scale_bound
    empty!(contacts)
    # a lone member could only meet itself
    (r == 0 || length(present) <= 1) && return contacts

    # a method with a contact rate: one count for the whole visit, at the visit's rate
    if replace && _has_contact_rate(csm)
        # a Poisson count, or the contacts drawn before the visit thinned to it
        rate = _visit_rate(contact_rate(csm, setting, idx, present, tick), s_host, scale_bound, thin)
        k = isinf(drawn_rate) ? gems_rand(rng, Poisson(rate)) : _thinned_count(drawn, rate / drawn_rate, rng)
        sample_k_contacts!(contacts, csm, setting, idx, present, tick, k, rng)
        # each kept by its contact's scale
        return _keep_contacts!(contacts, scale_bound, plans, setting, cntnr, rng)
    end
    # any other method is called as often as the scales say, so nothing can have been drawn ahead
    isinf(drawn_rate) || error("contacts were drawn before the visit for a $(typeof(csm)), which has no `contact_rate`; " *
        "set sampling methods during a simulation with `contact_sampling_method!(sim, setting, csm)`")

    # scales up to 1: one call, thinned by `r * thin`, then by each contact's scale
    if r <= 1
        _sample_thinned!(contacts, csm, setting, idx, present, tick, replace, rng, r * thin)
        return _keep_contacts!(contacts, scale_bound, plans, setting, cntnr, rng)
    end

    # above 1 without replacement: calls merged so a contact is met once, see `_sample_unique_scaled!`
    replace ||
        return _sample_unique_scaled!(contacts, draws, csm, setting, idx, present, tick, rng, plans, cntnr, r, oversample, scale_bound, thin)

    # above 1 with replacement: `r` calls, the last for the fraction beyond the whole ones
    calls = floor(Int, r)
    frac = r - calls
    # samplers fill their buffer from the start, so each call draws into `draws`
    for call in 1:(calls + (frac > 0))
        f = call > calls ? frac : 1.0f0
        empty!(draws)
        _sample_thinned!(draws, csm, setting, idx, present, tick, true, rng, f * thin)
        append!(contacts, _keep_contacts!(draws, scale_bound, plans, setting, cntnr, rng))
    end
    return contacts
end

# A visit's contact rate, see the section header. Monotone in each factor, also after rounding, so
# bounds on the factors give a bound on the rate.
@inline _visit_rate(rate::Float64, s_host::Float32, scale_bound::Float32, thin::Float32) = rate * ((s_host * scale_bound) * thin)

# How many of `n` contacts are kept, each with probability `p`: the visit's rate over the one they were drawn at.
@inline function _thinned_count(n::Int, p::Float64, rng::Xoshiro)::Int
    p <= 1 || error("a visit's contact rate exceeds the bound its contacts were drawn at; change sampling methods " *
        "and scales during a simulation with `contact_sampling_method!(sim, ...)` and `set_scale!(sim, ...)`")
    # equal rates are common and need no draw
    p == 1 && return n
    return gems_rand(rng, Binomial(n, p))
end

# Without replacement a contact drawn by several calls is kept once, with the weights of the calls
# that drew it summed. Exact while `s_host * s_contact <= 1`; above that the keep probability caps
# at 1, so a contact drawn often is met too rarely. `oversample` times the calls, each weighted down
# by it, shrink that bias at `oversample` times the sampler calls.
# The whole calls collect in `contacts`, the fractional last call stays in `draws`.
function _sample_unique_scaled!(contacts::Vector{Individual}, draws::Vector{Individual},
        csm::ContactSamplingMethod, setting::Setting, idx::Int, present::AbstractVector{Individual},
        tick::Int16, rng::Xoshiro, plans::ActivityPlanStore, cntnr::SettingsContainer,
        r::Float32, oversample::Float32, scale_bound::Float32, thin::Float32)
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
        _keep_unique_contact(c, w, thin, scale_bound, plans, setting, cntnr, rng) && (contacts[kept += 1] = c)
        i += 1
    end
    resize!(contacts, kept)
    for k in j:length(draws)
        draws[unmatched += 1] = draws[k]
    end
    for k in 1:unmatched
        _keep_unique_contact(draws[k], frac * unit, thin, scale_bound, plans, setting, cntnr, rng) && push!(contacts, draws[k])
    end
    return contacts
end

# Keeps a drawn contact with its scale over `scale_bound`, if it can be contacted here
@inline function _keep_contact(c::Individual, scale_bound::Float32,
        plans::ActivityPlanStore, setting::Setting, cntnr::SettingsContainer, rng::Xoshiro)
    p = _membership_scale(plans, c, setting, cntnr) / scale_bound
    kept = p >= 1 || gems_rand(rng) < p
    return kept && can_be_contacted(c, setting)
end

# Keeps each of `contacts` with `_keep_contact`, compacting them in place
@inline function _keep_contacts!(contacts::Vector{Individual}, scale_bound::Float32,
        plans::ActivityPlanStore, setting::Setting, cntnr::SettingsContainer, rng::Xoshiro)
    kept = 0
    for c in contacts
        _keep_contact(c, scale_bound, plans, setting, cntnr, rng) && (contacts[kept += 1] = c)
    end
    return resize!(contacts, kept)
end

# Keeps a contact drawn without replacement with `thin` times its capped keep probability
@inline function _keep_unique_contact(c::Individual, w::Float32, thin::Float32, scale_bound::Float32,
        plans::ActivityPlanStore, setting::Setting, cntnr::SettingsContainer, rng::Xoshiro)
    p = w * _membership_scale(plans, c, setting, cntnr) / scale_bound
    kept = p >= 1 ? (thin >= 1 || gems_rand(rng) < thin) : gems_rand(rng) < p * thin
    return kept && can_be_contacted(c, setting)
end

###
### MEMBERSHIP SCALE
### An individual's scale in a setting, from its own plan entries. An entry that does not apply
### this tick contributes 0. Also upper bounds on it per setting type, for draws before a setting is loaded.
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
    pool = _pool(c)::HierarchicalSettingPool
    closed = pool.closed != 0
    # a closed container frames none of its leaves
    closed && !is_open(c) && return 0.0f0
    return _capped_scale_sum(plans, slots) do k
        e = @inbounds plans.entries[k]
        leaf = leaves[setting_id(e)]
        Int(leaf.pool_leaf) in below && (!closed || _open_up_to(pool, leaf, C)) && !_is_deceased(leaf, member_index(e))
    end
end

# At least `_membership_scale` in any setting of type `S` the individual reaches from its entry at `slot`:
# the entry's own scale for a leaf, and for a container the capped sum over all its leaf entries, not just those below it.
@inline _membership_scale_bound(::ActivityPlanStore, ::Individual, ::Type{GlobalSetting}, ::Int) = 1.0f0

@inline function _membership_scale_bound(plans::ActivityPlanStore, individual::Individual, ::Type{T},
                                         slot::Int) where {T<:IndividualSetting}
    individual.plan_scaled || return 1.0f0
    return Float32(_effective_scale(plans, slot))
end

function _membership_scale_bound(plans::ActivityPlanStore, individual::Individual, ::Type{C},
                                 ::Int) where {C<:ContainerSetting}
    individual.plan_scaled || return 1.0f0
    # more slots only raise the sum and the cap
    return _capped_scale_sum(_ -> true, plans, plan_slots(plans, individual, _leaf_type(C)))
end

# The scales of the slots `include` accepts, summed but capped at the larger of 1 and the largest
@inline function _capped_scale_sum(include::F, plans::ActivityPlanStore, slots) where {F}
    total = 0.0f0
    largest = 0.0f0
    for k in slots
        include(k) || continue
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
# with its `sample_contacts!` method, and with `contact_rate` and `sample_k_contacts!` if its count is Poisson.

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

# A buffer the generic `sample_k_contacts!` reuses within each task, so it allocates once per task
_contact_scratch() = get!(() -> Individual[], task_local_storage(), :gems_contact_scratch)::Vector{Individual}

# Whether `csm` defines `contact_rate`, which a finite `contact_rate_bound` says
@inline _has_contact_rate(csm::ContactSamplingMethod) = isfinite(contact_rate_bound(csm))

# Samples as `sample_contacts!` does, then keeps each contact with probability `p`
function _sample_thinned!(indivs::Vector{Individual}, csm::ContactSamplingMethod, setting::Setting, individual_index::Int,
        present_inds::AbstractVector{Individual}, tick::Int16, replace::Bool, rng::Xoshiro, p::Float32)
    sample_contacts!(indivs, csm, setting, individual_index, present_inds, tick, replace, rng)
    return _keep_each!(indivs, p, rng)
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
