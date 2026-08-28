###
### SETTING POOL (MEMBER STORAGE FOR HIERARCHIES WITH CONTAINERS)
###
### Leaves under containers keep their members in one pool, in DFS order over `contains`,
### so a container's members are a range of it rather than a list it rebuilds each tick.
### Which types those are is read from the `contained_type` trait, not listed here, so a
### setting type with no parent - Household, Municipality, GlobalSetting - is simply not
### pooled and keeps its own member vector.
###
### `SettingPool`, `MemberSlice` and `MemberStorage` live in settings.jl - the setting types
### there use them as field types.
###
export build_pools!, repack_dirty_pools!, present_members

###
### HIERARCHY TRAITS
###

# Both traits below are derived from `contained_type`, which already encodes the hierarchy,
# rather than restating it. A setting type joins a pooled hierarchy purely by defining that
# trait, so adding a level - or a user-defined type - needs no change here. `contained_type`
# is deliberately undefined for root containers, so `hasmethod` is the terminator.
# Neither is used by `present_members`; both run at pool construction only.

"""
    is_pooled_leaf(::Type{T}) where {T<:Setting}

Whether settings of type `T` hold their members in a pool: true for an `IndividualSetting`
that sits under a container.
"""
is_pooled_leaf(::Type{T}) where {T<:Setting} =
    T <: IndividualSetting && hasmethod(contained_type, Tuple{Type{T}})

"""
    container_chain(::Type{T}) where {T<:Setting}

The containers above `T`, leaf to root, empty when `T` has no parent.
"""
function container_chain(::Type{T}) where {T<:Setting}
    chain = DataType[]
    S::DataType = T
    while hasmethod(contained_type, Tuple{Type{S}})
        S = contained_type(S)
        push!(chain, S)
    end
    return chain
end

# The setting's pool, or `nothing` when unpooled. `hasfield` folds on a concrete type, so
# this compiles to a field load or a constant.
@inline _pool(s::T) where {T<:Setting} = hasfield(T, :pool) ? s.pool : nothing

###
### POOL CONSTRUCTION
###

"""
    build_pools!(cntnr::SettingsContainer)

Move each pooled hierarchy's leaf members into one `SettingPool` and repoint the leaves at
their slices. Relocates storage rather than duplicating it. Idempotent per container.
"""
function build_pools!(cntnr::SettingsContainer)
    _check_contiguous_ids(cntnr)
    for L in settingtypes_sorted(cntnr)
        (is_pooled_leaf(L) && !isempty(get(cntnr.settings, L, ()))) || continue
        cntnr.pools[L] = _build_pool!(cntnr, L)
    end
    return cntnr
end

# Settings are addressed by id throughout GEMS (`settings(cntnr, T)[id]`), so a sparse id
# range fails deep inside a lookup. Say so here instead.
function _check_contiguous_ids(cntnr::SettingsContainer)
    for T in settingtypes_sorted(cntnr)
        (is_pooled_leaf(T) || !isempty(container_chain(T))) || continue
        stngs = get(cntnr.settings, T, ())
        isempty(stngs) && continue
        for (i, s) in enumerate(stngs)
            id(s) == i || error("$T ids must be 1..$(length(stngs)) to build a setting pool; " *
                                "entry $i has id $(id(s)). Run `new_setting_ids!` first.")
        end
    end
    return nothing
end

function _build_pool!(cntnr::SettingsContainer, ::Type{L}) where {L<:IndividualSetting}
    leaves = _dfs_leaves(cntnr, L)

    # a container's leaves are consecutive in DFS order, so its span is one index range.
    # ids are contiguous 1..n by now, so a leaf's position is an array index
    pos = Vector{Int32}(undef, length(leaves))
    for (i, l) in enumerate(leaves)
        pos[id(l)] = Int32(i)
    end
    groups = Any[]
    for C in container_chain(L)
        cs = settings(cntnr, C)
        rs = Vector{UnitRange{Int}}(undef, length(cs))
        for (i, c) in enumerate(cs)
            lo, hi = _leaf_span(pos, cntnr, c)
            rs[i] = hi == 0 ? (1:0) : (lo:hi)
        end
        push!(groups, (cs, rs))
    end

    pool = SettingPool(Individual[], 0, false, leaves, Tuple(groups))
    for l in leaves; l.pool = pool; end
    for (cs, _) in pool.container_groups, c in cs; c.pool = pool; end
    _repack!(pool)

    # settings may already be closed when the population is loaded
    pool.closed = count(!is_open, leaves)
    for (cs, _) in pool.container_groups
        pool.closed += count(!is_open, cs)
    end
    return pool
end

# Lowest and highest layout position `s` covers, `(typemax(Int), 0)` for none. Min/max, not
# first/last reached, so a leaf under two parents still spans both.
function _leaf_span(pos, ::SettingsContainer, s::IndividualSetting)
    p = Int(pos[id(s)])
    return (p, p)
end

function _leaf_span(pos, cntnr::SettingsContainer, s::ContainerSetting)
    kids = settings(cntnr, contains_type(typeof(s)))
    lo, hi = typemax(Int), 0
    for cid in s.contains
        l, h = _leaf_span(pos, cntnr, kids[cid])
        lo = min(lo, l)
        hi = max(hi, h)
    end
    return (lo, hi)
end

"""
    repack_dirty_pools!(cntnr::SettingsContainer)

Repack every pool left stale by a member edit. Must run between a membership change and the
next read of `present_members`. `step!` calls it ahead of the transmission phase, which is
the only reader inside a tick, so edits made anywhere in the previous tick are covered.
Cheap when nothing changed.
"""
function repack_dirty_pools!(cntnr::SettingsContainer)
    for pool in values(cntnr.pools)
        pool.dirty || continue
        _repack!(pool)
        pool.dirty = false
    end
    return cntnr
end

"""
    _repack!(pool::SettingPool)

Lay every leaf's members out back to back and refresh all offsets, lengths and views. Run
after a member edit, so the pool never accumulates gaps and a container's range always
covers exactly its members. O(members in the hierarchy).

Invalidates any previously handed-out member view, which is safe because member edits are
forbidden inside the threaded transmission phase.
"""
function _repack!(pool::SettingPool)
    pool.members = _repack_leaves!(pool.leaves)
    _repack_groups!(pool.leaves, pool.container_groups...)
    return nothing
end

function _repack_leaves!(leaves::Vector{T}) where {T<:IndividualSetting}
    total = 0
    for l in leaves
        total += length(l.individuals)
    end
    # a repack cannot pack in place: a leaf that grew would overwrite the next leaf before
    # it was copied
    members = Vector{Individual}(undef, total)

    off = 1
    for l in leaves
        n = length(l.individuals)
        copyto!(members, off, l.individuals, 1, n)
        l.pool_offset = Int32(off)
        l.pool_length = Int32(n)
        off += n
    end

    # repoint only after all copying, so no leaf is read after its storage was replaced
    for l in leaves
        lo = Int(l.pool_offset)
        l.individuals = view(members, lo:(lo + Int(l.pool_length) - 1))
    end
    return members
end

# recursive, so each call specialises on that group's concrete vector type
@inline _repack_groups!(leaves) = nothing
@inline function _repack_groups!(leaves, group, rest...)
    _repack_group!(group[1], group[2], leaves)
    _repack_groups!(leaves, rest...)
end

function _repack_group!(cs::Vector{C}, ranges::Vector{UnitRange{Int}},
                        leaves::Vector{T}) where {C<:ContainerSetting, T<:IndividualSetting}
    @inbounds for i in eachindex(cs)
        c = cs[i]
        r = ranges[i]
        if isempty(r)
            c.pool_offset = Int32(0)
            c.pool_length = Int32(0)
            continue
        end
        # the leaf pass left no gaps, so the span runs from the first leaf's start to the
        # end of the last one
        lo = leaves[first(r)]
        hi = leaves[last(r)]
        len = hi.pool_offset + hi.pool_length - lo.pool_offset
        c.pool_offset = len == 0 ? Int32(0) : lo.pool_offset # 0 means "no members here"
        c.pool_length = len
    end
    return nothing
end

# Leaves in DFS order over `contains` - the order `present_individuals!` produces, which is
# what makes a container's members contiguous. Roots first, then lower container types to
# catch subtrees orphaned partway down, then leaves under no container at all.
function _dfs_leaves(cntnr::SettingsContainer, ::Type{L}) where {L<:IndividualSetting}
    leaves = settings(cntnr, L)
    order = Vector{L}()
    taken = falses(length(leaves)) # ids are contiguous 1..n by now

    for C in reverse(container_chain(L)), s in settings(cntnr, C)
        _take_leaf!(order, taken, cntnr, s)
    end
    for leaf in leaves
        _take_leaf!(order, taken, cntnr, leaf)
    end
    return order
end

_take_leaf!(order, taken, ::SettingsContainer, s::IndividualSetting) = begin
    taken[s.id] && return nothing
    taken[s.id] = true
    push!(order, s)
    return nothing
end

function _take_leaf!(order, taken, cntnr::SettingsContainer, s::ContainerSetting)
    kids = settings(cntnr, contains_type(typeof(s)))
    for cid in s.contains
        _take_leaf!(order, taken, cntnr, kids[cid])
    end
    return nothing
end

###
### PRESENT MEMBERS
###

# Shared by every contiguous view, so the common case allocates no run vectors.
const NO_RUNS = Int32[]

"""
    MemberView

A setting's present members, as a window onto its hierarchy's pool. Usually one unbroken span,
described by `offset` and `len`. A container with closed descendants needs several runs, and
then `starts`/`prefix` describe them and indexing binary-searches `prefix`.

The result aliases real member storage, so writing to it edits membership.
"""
struct MemberView <: AbstractVector{Individual}
    members::Vector{Individual}
    offset::Int32
    len::Int32
    starts::Vector{Int32}
    prefix::Vector{Int32}
end

MemberView(members::Vector{Individual}, offset::Int32, len::Int32) =
    MemberView(members, offset, len, NO_RUNS, NO_RUNS)
MemberView(members::Vector{Individual}, starts::Vector{Int32}, prefix::Vector{Int32}, len::Int32) =
    MemberView(members, Int32(0), len, starts, prefix)

Base.size(v::MemberView) = (Int(v.len),)
Base.IndexStyle(::Type{MemberView}) = IndexLinear()

Base.@propagate_inbounds function Base.getindex(v::MemberView, k::Int)
    isempty(v.starts) && return @inbounds v.members[v.offset + k - 1]
    r = searchsortedlast(v.prefix, k - 1)
    @inbounds v.members[v.starts[r] + (k - 1 - v.prefix[r])]
end


"""
    present_members(setting::Setting, cntnr::SettingsContainer)

The setting's present members, as an indexable view. Nothing is copied and nothing is built
per tick: an open leaf and an all-open container are both a contiguous slice of the
hierarchy pool, and only a container with closed descendants needs run indexing.

Equal element for element to `present_individuals(setting, sim)`.

The result aliases real member storage, so writing to it edits membership - see the note on
`ContactSamplingMethod`.
"""
function present_members(s::IndividualSetting, ::SettingsContainer)::MemberView
    pool = _pool(s)
    if pool === nothing
        # standalone leaf: its own vector already holds exactly the members
        v = s.individuals::Vector{Individual}
        return is_open(s) ? MemberView(v, Int32(1), Int32(length(v))) : MemberView(v, Int32(1), Int32(0))
    end
    _check_clean(s, pool)
    return is_open(s) ? MemberView(pool.members, s.pool_offset, s.pool_length) :
                        MemberView(pool.members, Int32(1), Int32(0))
end

function present_members(s::ContainerSetting, cntnr::SettingsContainer)::MemberView
    pool = _pool(s)::SettingPool
    _check_clean(s, pool)
    is_open(s) || return MemberView(pool.members, Int32(1), Int32(0))

    # the pool is repacked after every edit, so a container's range covers exactly its
    # members; only a closure below it can break that
    if pool.closed == 0 || _subtree_open(cntnr, s)
        return MemberView(pool.members, s.pool_offset, s.pool_length)
    end

    starts = Int32[]; prefix = Int32[]
    total = _collect_runs!(starts, prefix, 0, cntnr, s)
    length(starts) == 1 && return MemberView(pool.members, @inbounds(starts[1]), Int32(total))
    return MemberView(pool.members, starts, prefix, Int32(total))
end

# A member edit leaves every offset and length in the hierarchy stale until the pool is
# repacked. Reading in that window would silently return the wrong members, so refuse
# instead. `present_individuals` reads the member vectors directly and stays usable.
@inline function _check_clean(s::Setting, pool::SettingPool)
    pool.dirty && error(
        "$(typeof(s)) belongs to a setting pool with pending member edits. Call " *
        "`repack_dirty_pools!` after editing membership and before reading members.")
    return nothing
end

# `open!` and `close!` keep this in step; they only call it on a real state change.
_count_closed!(s::Setting, delta::Int) = begin
    pool = _pool(s)
    pool === nothing || (pool.closed += delta)
    return nothing
end

_subtree_open(::SettingsContainer, s::IndividualSetting) = is_open(s)
function _subtree_open(cntnr::SettingsContainer, s::ContainerSetting)
    is_open(s) || return false
    kids = settings(cntnr, contains_type(typeof(s)))
    for cid in s.contains
        _subtree_open(cntnr, kids[cid]) || return false
    end
    return true
end

function _collect_runs!(starts, prefix, total, ::SettingsContainer, s::IndividualSetting)
    (is_open(s) && s.pool_length > 0) || return total
    lo = Int(s.pool_offset)
    # merge with the previous run when the leaves stayed adjacent in the pool
    if !isempty(starts) && Int(starts[end]) + (total - Int(prefix[end])) == lo
        return total + Int(s.pool_length)
    end
    push!(starts, Int32(lo))
    push!(prefix, Int32(total))
    return total + Int(s.pool_length)
end

function _collect_runs!(starts, prefix, total, cntnr::SettingsContainer, s::ContainerSetting)
    is_open(s) || return total
    kids = settings(cntnr, contains_type(typeof(s)))
    for cid in s.contains
        total = _collect_runs!(starts, prefix, total, cntnr, kids[cid])
    end
    return total
end

###
### MEMBER EDITS
###
### Called by `add_member!` / `remove_member!` in settings.jl when the leaf is pooled.
###

# Both primitives detach the leaf's members into a vector it owns and edit that, leaving the
# pool stale. `repack_dirty_pools!` restores it, so a batch of edits costs one repack rather
# than one each.

# The leaf's members as a vector it owns. Already detached by an earlier edit in the same
# batch, it is returned as is - copying again would make k edits on one leaf O(k^2).
_detached(s::IndividualSetting)::Vector{Individual} =
    s.individuals isa MemberSlice ? collect(s.individuals) : s.individuals

function _pool_add_member!(s::IndividualSetting, individual::Individual)
    v = _detached(s)
    push!(v, individual)
    s.individuals = v
    (_pool(s)::SettingPool).dirty = true
    return nothing
end

# Swap with last, as before: removal reorders a leaf, which is RNG-visible and unavoidable.
function _pool_remove_member!(s::IndividualSetting, individual::Individual)
    idx = findfirst(i -> i === individual, s.individuals)
    isnothing(idx) && return false

    v = _detached(s)
    @inbounds v[idx] = v[end]
    pop!(v)
    s.individuals = v
    (_pool(s)::SettingPool).dirty = true
    return true
end
