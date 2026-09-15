###
### CONTACT SCALING
### Scales a setting's contacts by both parties' scales there. A host draws `s_host * bound` times
### its sampler's contacts and keeps each with the contact's scale over `bound`, so every pair
### meets at `s_host * s_contact` times the unscaled rate.
###

# Samples the host's contacts in `setting` into `contacts`, drawing into `draws` when the sampler
# has to be called more than once. Draws nothing extra while every scale involved is 1.
function sample_scaled_contacts!(contacts::Vector{Individual}, draws::Vector{Individual},
        csm::ContactSamplingMethod, setting::Setting, idx::Int, present::AbstractVector{Individual},
        tick::Int16, rng::Xoshiro, plans::ActivityPlanStore, cntnr::SettingsContainer,
        s_host::Float32, bound::Float32)
    r = s_host * bound
    empty!(contacts)
    # a lone member could only meet itself
    (r == 0 || length(present) <= 1) && return contacts

    if r <= 1
        # one draw, thinned in place
        sample_contacts!(contacts, csm, setting, idx, present, tick, true, rng)
        kept = 0
        for c in contacts
            _keep_contact(c, r, bound, plans, setting, cntnr, rng) && (contacts[kept += 1] = c)
        end
        return resize!(contacts, kept)
    end

    # samplers fill their buffer from the start, so each call draws into `draws`
    calls = floor(Int, r)
    frac = r - calls
    for call in 1:(calls + (frac > 0))
        # the last draw stands for the fraction beyond the whole ones
        f = call > calls ? frac : 1.0f0
        empty!(draws)
        sample_contacts!(draws, csm, setting, idx, present, tick, true, rng)
        for c in draws
            _keep_contact(c, f, bound, plans, setting, cntnr, rng) && push!(contacts, c)
        end
    end
    return contacts
end

@inline function _keep_contact(c::Individual, f::Float32, bound::Float32, plans::ActivityPlanStore,
        setting::Setting, cntnr::SettingsContainer, rng::Xoshiro)
    p = f * _membership_scale(plans, c, setting, cntnr) / bound
    return p >= 1 || gems_rand(rng) < p
end

###
### MEMBERSHIP SCALE
### An individual's scale in a setting, from its own plan entries.
###

# nobody holds an entry for the GlobalSetting
@inline _membership_scale(::ActivityPlanStore, ::Individual, ::GlobalSetting, ::SettingsContainer) = 1.0f0

@inline function _membership_scale(plans::ActivityPlanStore, individual::Individual, s::T,
                                   ::SettingsContainer) where {T<:IndividualSetting}
    individual.plan_scaled || return 1.0f0
    # Float16 arithmetic is emulated in software
    return Float32(entry_scale(plans.entries[plan_slot(plans, individual, T, id(s))]))
end

# A container holds no entry: the scales of the individual's open leaves below it, summed but
# capped at the larger of 1 and the largest, so presence there is normal unless its leaves say more.
function _membership_scale(plans::ActivityPlanStore, individual::Individual, c::C,
                           cntnr::SettingsContainer) where {C<:ContainerSetting}
    individual.plan_scaled || return 1.0f0
    L = _leaf_type(C)
    slots = plan_slots(plans, individual, L)
    # in c's frame, so a lone leaf entry is the one that put it there
    length(slots) == 1 && return Float32(entry_scale(@inbounds plans.entries[first(slots)]))
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
        s = Float32(entry_scale(e))
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
    for m in individuals(s)
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
