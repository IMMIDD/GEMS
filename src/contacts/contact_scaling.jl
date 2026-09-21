###
### CONTACT SCALING
### Scales a setting's contacts by both parties' scales there. A host draws `s_host * bound` times
### its sampler's contacts and keeps each with the contact's scale over `bound`, so every pair
### meets at `s_host * s_contact` times the unscaled rate.
###

# Samples the host's contacts in `setting` into `contacts`, drawing into `draws` when the sampler
# has to be called more than once. Draws nothing extra while every scale involved is 1.
# `oversample` only acts without replacement, see `_sample_unique_scaled!`.
# `thin` keeps each contact with that probability on top of its scales.
function sample_scaled_contacts!(contacts::Vector{Individual}, draws::Vector{Individual},
        csm::ContactSamplingMethod, setting::Setting, idx::Int, present::AbstractVector{Individual},
        tick::Int16, replace::Bool, rng::Xoshiro, plans::ActivityPlanStore, cntnr::SettingsContainer,
        s_host::Float32, bound::Float32; oversample::Float32 = 1.0f0, thin::Float32 = 1.0f0)
    r = s_host * bound
    empty!(contacts)
    # a lone member could only meet itself
    (r == 0 || length(present) <= 1) && return contacts

    if r <= 1
        # one draw, thinned in place
        sample_contacts!(contacts, csm, setting, idx, present, tick, replace, rng)
        kept = 0
        for c in contacts
            _keep_contact(c, r, thin, bound, plans, setting, cntnr, rng) && (contacts[kept += 1] = c)
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
        sample_contacts!(draws, csm, setting, idx, present, tick, true, rng)
        for c in draws
            _keep_contact(c, f, thin, bound, plans, setting, cntnr, rng) && push!(contacts, c)
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

# Keeps a drawn contact with `f * thin` times its scale over `bound`, if it can be contacted here.
# A contact's scale is at most `bound`, so a draw above `f * thin` rejects it without reading the contact.
@inline function _keep_contact(c::Individual, f::Float32, thin::Float32, bound::Float32,
        plans::ActivityPlanStore, setting::Setting, cntnr::SettingsContainer, rng::Xoshiro)
    ft = f * thin
    # headroom for rounding in the scale over the bound
    reach = ft * 1.000001f0
    if reach < 1
        x = gems_rand(rng)
        x < reach || return false
        kept = x < ft * _membership_scale(plans, c, setting, cntnr) / bound
    else
        p = ft * _membership_scale(plans, c, setting, cntnr) / bound
        kept = p >= 1 || gems_rand(rng) < p
    end
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
    closed = (_pool(c)::SettingPool).closed != 0
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
### SCALE BOUNDS
### Each setting keeps an upper bound on its members' scales: a leaf the largest among its
### members, a container the largest among its leaves, refreshed with its span.
###

@inline _scale_bound(s::T) where {T<:Setting} = hasfield(T, :scale_bound) ? s.scale_bound : 1.0f0

# recounts a leaf's bound from its members
function _refresh_scale_bound!(plans::ActivityPlanStore, s::T) where {T<:IndividualSetting}
    hasfield(T, :scale_bound) || return nothing
    b = 1.0f0
    # deceased members draw no contacts, so their scales do not count
    for m in view(individuals(s), 1:_alive(s))
        m.plan_scaled || continue
        slot = plan_slot(plans, m, T, id(s))
        slot == 0 || (b = max(b, Float32(entry_scale(@inbounds plans.entries[slot]))))
    end
    return _set_scale_bound!(s, b)
end

# a pooled leaf's containers pick up its new bound when its block is repacked
function _set_scale_bound!(s::T, b::Float32) where {T<:IndividualSetting}
    (hasfield(T, :scale_bound) && s.scale_bound != b) || return nothing
    s.scale_bound = b
    pool = _pool(s)
    pool === nothing || _mark_dirty!(pool, s)
    return nothing
end

###
### HIERARCHY
###

# c's leaves, as the range of its pool's leaves `_build_pool!` recorded for it
@inline function _leaf_range(c::C) where {C<:ContainerSetting}
    level = (_pool(c)::SettingPool).container_groups[_container_depth(C)]::ContainerLevel{C}
    return @inbounds level.ranges[id(c)]
end

# levels above the leaf type, which is C's position in `container_groups`
_container_depth(::Type{T}) where {T<:IndividualSetting} = 0
_container_depth(::Type{C}) where {C<:ContainerSetting} = 1 + _container_depth(contains_type(C))

# whether `s` and every container between it and `c` are open
function _open_below(cntnr::SettingsContainer, s::Setting, c::ContainerSetting)
    is_open(s) || return false
    typeof(s) === typeof(c) && return true
    return _open_below(cntnr, settings(cntnr, contained_type(typeof(s)))[s.contained], c)
end
