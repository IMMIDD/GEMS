###
### SETTING LAYER ASSIGNMENTS
### How layers put participants into settings: the contract an assignment type implements, then
### the new-settings and join algorithms of the built-in types.
###

###
### ASSIGNMENT CONTRACT
### An assignment type plugs in through these: a new-settings type defines `_partition`, a join
### type `_join_state` and `_choose`; either may add `_check_assignment` and `_needs_coordinates`.
### A new-settings type that needs all rows at once overrides `_assign!` instead, as
### `RandomSettings` does; the general `_assign!` methods open NEW SETTINGS and JOINING EXISTING SETTINGS.
###

"""
    _LayerContext{C}

What an assignment reads while placing a layer's participants: the plans (`store`), the
individuals (`inds`), the layer's setting type index (`tidx`), home coordinates (`coords`,
`nothing` without), and the stream setting sizes are drawn from (`size_rng`).
"""
struct _LayerContext{C}
    store::ActivityPlanStore
    inds::Vector{Individual}
    tidx::UInt8
    coords::C
    size_rng::Xoshiro
end

"""
    _partition(a::NewSettingsAssignment, members::Vector{Int32}, ctx::_LayerContext, rng::Xoshiro)

Returns a label ≥ 1 per member, by position in `members`, which are positions in `ctx.inds`;
members with one label share a new setting. Sizes come from `_draw_size(ctx.size_rng, size)`;
`_cut_labels` and `_shuffled_positions` do the common cuts.
"""
function _partition end

"""
    _join_state(a::JoinAssignment, ctx::_LayerContext)

Builds the lookup `_choose` draws from, once per layer; `_JoinCandidates` holds every setting of
the layer's type with members.
"""
function _join_state end

"""
    _choose(a::JoinAssignment, i::Int, held::Vector{Int32}, state, ctx::_LayerContext, rng::Xoshiro)

Returns the id of an existing setting for the individual at position `i` to join, never one in
`held`, or 0 if there is none. `state` is what `_join_state(a, ctx)` built once for the layer.
"""
function _choose end

###
### NEW SETTINGS
###

"""
    _assign!(additions::_PlanAdditions, a::NewSettingsAssignment, ctx::_LayerContext, rng::Xoshiro)

Puts round `r`'s members, those with at least `r` rows, into new settings by `_partition`, so
nobody gets one setting twice. Returns the number of rows left without a setting, here 0.
"""
function _assign!(additions::_PlanAdditions, a::NewSettingsAssignment, ctx::_LayerContext, rng::Xoshiro)
    next_id = _first_new_id(ctx)
    for r in 1:_rounds(additions)
        members = _members_in_round(additions, r)
        rows = (_addition_row(additions, Int(i), r) for i in members)
        next_id = _write_labels!(additions, _partition(a, members, ctx, rng), rows, next_id)
    end
    return 0
end

# The most rows any individual has.
_rounds(additions::_PlanAdditions) =
    maximum(i -> length(_addition_rows(additions, i)), _addition_individuals(additions); init = 0)

# The positions of the individuals with at least `r` rows.
function _members_in_round(additions::_PlanAdditions, r::Int)
    members = Vector{Int32}(undef, count(i -> length(_addition_rows(additions, i)) >= r, _addition_individuals(additions)))
    k = 0
    for i in _addition_individuals(additions)
        length(_addition_rows(additions, i)) >= r && (members[k += 1] = Int32(i))
    end
    return members
end

# The first id after every setting of the layer's type in the plans.
_first_new_id(ctx::_LayerContext) = Int(_max_setting_id(ctx.store, ctx.inds, ctx.tidx)) + 1

"""
    _write_labels!(additions::_PlanAdditions, labels::Vector{Int32}, rows, first_id::Int)

Gives row `rows[k]` the setting label `labels[k]` names, numbering the labels in use in sorted
order from `first_id`; returns the next free id. The only place rows get new ids.
"""
function _write_labels!(additions::_PlanAdditions, labels::Vector{Int32}, rows, first_id::Int)
    length(labels) == length(rows) || error("got $(length(labels)) labels for $(length(rows)) rows")
    ids, next_id = _label_ids(labels, first_id)
    @inbounds for (k, row) in enumerate(rows)
        additions.sids[row] = ids[labels[k]]
    end
    return next_id
end

# The setting id of each label in use, numbered in sorted order from `first_id`, and the next free id.
function _label_ids(labels::Vector{Int32}, first_id::Int)
    isempty(labels) && return Int32[], first_id
    minimum(labels) >= 1 || error("setting labels must be at least 1; got $(minimum(labels))")
    used = falses(maximum(labels))
    used[labels] .= true
    first_id + count(used) - 1 <= typemax(Int32) || throw(ArgumentError(
        "new settings would need ids past $(typemax(Int32))"))
    ids = zeros(Int32, length(used))
    # an Int, so the id after the last one allowed does not wrap
    next_id = first_id
    for l in eachindex(used)
        used[l] || continue
        ids[l] = Int32(next_id)
        next_id += 1
    end
    return ids, next_id
end

"""
    _assign!(additions::_PlanAdditions, a::RandomSettings, ctx::_LayerContext, rng::Xoshiro)

Puts every row into one pool of `rows / size` new settings, each participant into distinct,
uniformly drawn ones. Throws if someone has more rows than the pool has settings; returns 0.
"""
function _assign!(additions::_PlanAdditions, a::RandomSettings, ctx::_LayerContext, rng::Xoshiro)
    n = max(1, round(Int, length(additions.sids) / mean(a.size)))
    rounds = _rounds(additions)
    rounds <= n || throw(ArgumentError(
        "an individual has $rounds entries but the pool has $n settings; lower `size` or `entries`"))
    _write_labels!(additions, _pool_labels(additions, n, rng), eachindex(additions.sids), _first_new_id(ctx))
    return 0
end

# One label in 1..n per row, drawn uniformly and redrawn while the individual already has it.
function _pool_labels(additions::_PlanAdditions, n::Int, rng::Xoshiro)
    labels = Vector{Int32}(undef, length(additions.sids))
    for i in _addition_individuals(additions)
        rows = _addition_rows(additions, i)
        for k in rows
            l = Int32(gems_rand(rng, 1:n))
            while l in view(labels, first(rows):(k - 1))
                l = Int32(gems_rand(rng, 1:n))
            end
            labels[k] = l
        end
    end
    return labels
end

_shuffled_positions(rng::Xoshiro, n::Int) = gems_shuffle!(rng, collect(Int32(1):Int32(n)))

# Labels the positions in `order` setting by setting along it, each setting's size drawn from
# `size_rng`; the last one may be smaller than drawn.
function _cut_labels(order::Vector{Int32}, size, size_rng::Xoshiro)
    labels = Vector{Int32}(undef, length(order))
    _cut_labels!(labels, order, size, size_rng, Int32(0))
    return labels
end

# As `_cut_labels`, into `labels` with labels after `last`; returns the last label used.
function _cut_labels!(labels::Vector{Int32}, order::Vector{Int32}, size, size_rng::Xoshiro, last::Int32)
    label, left = last, 0
    for p in order
        if left == 0
            label += Int32(1)
            left = _draw_size(size_rng, size)
        end
        @inbounds labels[p] = label
        left -= 1
    end
    return label
end

# `SpatialSettings`' method is in setting_layers_spatial.jl.

function _partition(a::PackedSettings, members::Vector{Int32}, ctx::_LayerContext, rng::Xoshiro)
    return _cut_labels(_shuffled_positions(rng, length(members)), a.size, ctx.size_rng)
end

function _partition(a::AgeSortedSettings, members::Vector{Int32}, ctx::_LayerContext, rng::Xoshiro)
    order = _sort_by_age(_shuffled_positions(rng, length(members)), members, ctx.inds)
    return _cut_labels(order, a.size, ctx.size_rng)
end

# `order` sorted by the age of the member at each position, keeping its order within one age.
function _sort_by_age(order::Vector{Int32}, members::Vector{Int32}, inds::Vector{Individual})
    ages = Int8[age(inds[members[p]]) for p in order]
    # counting sort: firsts[a + 1] counts the members younger than a
    firsts = zeros(Int32, typemax(Int8) + 2)
    foreach(a -> firsts[Int(a) + 2] += 1, ages)
    cumsum!(firsts, firsts)
    sorted = similar(order)
    for (k, p) in enumerate(order)
        a = Int(ages[k]) + 1
        firsts[a] += 1
        sorted[firsts[a]] = p
    end
    return sorted
end

function _partition(a::GroupedSettings, members::Vector{Int32}, ctx::_LayerContext, rng::Xoshiro)
    gids = Int32[_setting_id(ctx.inds[i], a.by, ctx.store) for i in members]
    starts, positions = _group_members(gids)
    order = _shuffled_positions(rng, length(starts) - 1)
    return _fill_groups(starts, positions, order, a.size, ctx.size_rng)
end

# The member positions by group, as group `g`'s `positions[starts[g]:(starts[g + 1] - 1)]`: groups
# in ascending id, then one group per member without a group id, in member order.
function _group_members(gids::Vector{Int32})
    max_gid = Int(maximum(gids; init = Int32(0)))
    # counting sort: firsts[g] counts the members of groups below g
    firsts = zeros(Int32, max_gid + 1)
    foreach(g -> g > 0 && (firsts[g + 1] += 1), gids)
    cumsum!(firsts, firsts)
    positions, next, loner = similar(gids), copy(firsts), firsts[end]
    for (p, g) in enumerate(gids)
        k = g > 0 ? (next[g] += 1) : (loner += Int32(1))
        positions[k] = p
    end
    starts = Int32[firsts[g] + 1 for g in 1:max_gid if firsts[g + 1] > firsts[g]]
    append!(starts, (firsts[end] + 1):Int32(length(gids) + 1))
    return starts, positions
end

# Labels the members group by group in `order`. A group opens a new setting, of a drawn size,
# when it would overfill the current one and that one is not empty.
function _fill_groups(starts::Vector{Int32}, positions::Vector{Int32}, order::Vector{Int32}, size, size_rng::Xoshiro)
    labels = Vector{Int32}(undef, length(positions))
    label, filled, target = Int32(1), 0, _draw_size(size_rng, size)
    for g in order
        group = starts[g]:(starts[g + 1] - 1)
        if filled > 0 && filled + length(group) > target
            label, filled, target = label + Int32(1), 0, _draw_size(size_rng, size)
        end
        for k in group
            @inbounds labels[positions[k]] = label
        end
        filled += length(group)
    end
    return labels
end

###
### JOINING EXISTING SETTINGS
###

"""
    _assign!(additions::_PlanAdditions, a::JoinAssignment, ctx::_LayerContext, rng::Xoshiro)

Gives each row an existing setting of the layer's type by `_choose`, never one the individual
already holds. Returns the number of rows left without one.
"""
function _assign!(additions::_PlanAdditions, a::JoinAssignment, ctx::_LayerContext, rng::Xoshiro)
    state = _join_state(a, ctx)
    held = Int32[]
    shortfall = 0
    for i in _addition_individuals(additions)
        rows = _addition_rows(additions, i)
        isempty(rows) && continue
        _held_ids!(held, ctx, i)
        for k in rows
            sid = _choose(a, i, held, state, ctx, rng)
            if sid == 0
                shortfall += 1
            else
                additions.sids[k] = sid
                push!(held, sid)
            end
        end
    end
    return shortfall
end

# Refills `held` with the ids of the layer's type the individual at position `i` holds.
function _held_ids!(held::Vector{Int32}, ctx::_LayerContext, i::Int)
    empty!(held)
    for k in _type_slots(ctx.store, ctx.inds[i], ctx.tidx)
        push!(held, setting_id(ctx.store.entries[k]))
    end
    return held
end

"""
    _JoinCandidates

The existing settings of one type that have members: their `ids` in ascending order, and the
running total of their member counts, `cumulative`. Fixed while a layer joins them.
"""
struct _JoinCandidates
    ids::Vector{Int32}
    cumulative::Vector{Int}
end

function _JoinCandidates(store::ActivityPlanStore, inds::Vector{Individual}, t::UInt8)
    counts = zeros(Int, _max_setting_id(store, inds, t))
    @inbounds for ind in inds, k in _type_slots(store, ind, t)
        sid = setting_id(store.entries[k])
        sid >= 1 && (counts[sid] += 1)
    end
    ids = Int32.(findall(>(0), counts))
    return _JoinCandidates(ids, cumsum(counts[ids]))
end

# `JoinNearby`'s methods are in setting_layers_spatial.jl.

_join_state(::JoinExisting, ctx::_LayerContext) = _JoinCandidates(ctx.store, ctx.inds, ctx.tidx)

function _choose(::JoinExisting, ::Int, held::Vector{Int32}, c::_JoinCandidates, ::_LayerContext, rng::Xoshiro)
    isempty(c.ids) && return Int32(0)
    # most draws miss the few settings an individual holds
    for _ in 1:64
        sid = c.ids[searchsortedfirst(c.cumulative, gems_rand(rng, 1:c.cumulative[end]))]
        sid in held || return sid
    end
    return _draw_unheld(c, held, rng)
end

# A draw ∝ member count among the candidates not in `held`, or 0 if there are none: a draw over
# the others' total, stepped past each held setting's share.
function _draw_unheld(c::_JoinCandidates, held::Vector{Int32}, rng::Xoshiro)
    # the held settings' positions among the candidates, ascending
    js = Int[]
    for h in held
        j = searchsortedfirst(c.ids, h)
        j <= length(c.ids) && c.ids[j] == h && push!(js, j)
    end
    sort!(js)
    free = c.cumulative[end] - sum(j -> _candidate_weight(c, j), js; init = 0)
    free > 0 || return Int32(0)
    x = gems_rand(rng, 1:free)
    for j in js
        x > c.cumulative[j] - _candidate_weight(c, j) || break
        x += _candidate_weight(c, j)
    end
    return c.ids[searchsortedfirst(c.cumulative, x)]
end

# The member count of the candidate at position `j`.
@inline _candidate_weight(c::_JoinCandidates, j::Int) = c.cumulative[j] - (j == 1 ? 0 : c.cumulative[j - 1])
