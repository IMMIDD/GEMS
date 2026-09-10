###
### SETTING POOL METHODS
###
export build_pools!, repack_dirty_pools!, present_members

###
### PRESENT MEMBERS
###

"""
    present_members(setting::Setting, cntnr::SettingsContainer)

The setting's present members, as an indexable view. Nothing is copied and nothing is built
per tick: an open leaf and an all-open container are both a contiguous slice of the
hierarchy pool, and only a container with closed descendants or a repeated member needs run
indexing.

Equal element for element to `present_individuals(setting, sim)`, except that a member in two
leaves of one container appears once here and twice there.

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
        r = s.pool_runs
        # a repeat at the edge of the span leaves one run, which is a plain slice again
        (r === nothing || length(r.starts) == 1) &&
            return MemberView(pool.members, s.pool_offset, s.pool_length)
        return MemberView(pool.members, r.starts, r.prefix, s.pool_length)
    end

    starts, prefix, total = _open_runs(cntnr, s)
    length(starts) == 1 && return MemberView(pool.members, @inbounds(starts[1]), Int32(total))
    return MemberView(pool.members, starts, prefix, Int32(total))
end

# A member edit leaves every offset and length in the hierarchy stale until the pool is
# repacked. Reading in that window would silently return the wrong members, so refuse
# instead. `present_individuals` reads the member vectors directly and stays usable.
@inline function _check_clean(s::Setting, pool::SettingPool)
    isempty(pool.blocks.dirty) || error(
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
### MEMBER RUNS
### Run arithmetic shared by the closed case and the repeated-member case, both of which turn
### a container's span into several runs.
###

# The runs a container's open leaves cover, repeats past the first present copy dropped.
function _open_runs(cntnr::SettingsContainer, s::ContainerSetting)
    starts = Int32[]; prefix = Int32[]
    total = _collect_runs!(starts, prefix, 0, cntnr, s)
    r = s.pool_runs
    if r !== nothing
        skips = _repeat_skips(r, starts, prefix, total)
        isempty(skips) || ((starts, prefix, total) = _drop_skips(starts, prefix, total, skips))
    end
    return starts, prefix, total
end

# Where pool position `p` sits in a run-indexed frame, 0 when the runs do not cover it.
@inline function _run_index(starts::Vector{Int32}, prefix::Vector{Int32}, total::Int, p::Int)
    r = searchsortedlast(starts, Int32(p))
    r == 0 && return 0
    @inbounds run_len = (r < length(prefix) ? Int(prefix[r + 1]) : total) - Int(prefix[r])
    @inbounds off = p - Int(starts[r])
    off < run_len || return 0
    @inbounds return off + Int(prefix[r]) + 1
end

# Split `starts`/`prefix` around `skips`, ascending pool positions lying inside them.
function _drop_skips(starts::Vector{Int32}, prefix::Vector{Int32}, total::Int,
                     skips::Vector{Int32})
    out_starts = Int32[]; out_prefix = Int32[]
    kept = 0
    k = 1
    @inbounds for r in eachindex(starts)
        lo = Int(starts[r])
        stop = lo + (r < length(prefix) ? Int(prefix[r + 1]) : total) - Int(prefix[r])
        pos = lo
        while k <= length(skips) && Int(skips[k]) < lo
            k += 1
        end
        while k <= length(skips) && Int(skips[k]) < stop
            s = Int(skips[k])
            if s > pos
                push!(out_starts, Int32(pos)); push!(out_prefix, Int32(kept))
                kept += s - pos
            end
            pos = s + 1
            k += 1
        end
        if pos < stop
            push!(out_starts, Int32(pos)); push!(out_prefix, Int32(kept))
            kept += stop - pos
        end
    end
    return out_starts, out_prefix, kept
end

# Which repeats to drop given the open runs: the first copy still present is the one kept, so
# closing the leaf holding it promotes the next rather than losing the member.
function _repeat_skips(r::MemberRuns, starts::Vector{Int32}, prefix::Vector{Int32}, total::Int)
    skips = Int32[]
    @inbounds for g in 1:(length(r.bounds) - 1)
        seen = false
        for k in Int(r.bounds[g]):(Int(r.bounds[g + 1]) - 1)
            p = r.groups[k]
            _run_index(starts, prefix, total, Int(p)) == 0 && continue
            seen ? push!(skips, p) : (seen = true)
        end
    end
    sort!(skips)
    return skips
end

###
### POOL CONSTRUCTION
###

# A block's default headroom, as a fraction of its length: memory against relocations.
const DEFAULT_POOL_SLACK = 0.25

"""
    build_pools!(cntnr::SettingsContainer; slack::Real = DEFAULT_POOL_SLACK)

Move each pooled hierarchy's leaf members into one `SettingPool` and repoint the leaves at
their slices. Relocates storage rather than duplicating it. Idempotent per container.

`slack` is each block's headroom as a fraction of its length; zero packs blocks exact-fit.
"""
function build_pools!(cntnr::SettingsContainer; slack::Real = DEFAULT_POOL_SLACK)
    slack >= 0 || throw(ArgumentError("pool slack must not be negative, got $slack"))
    _check_contiguous_ids(cntnr)
    for L in settingtypes_sorted(cntnr)
        (is_pooled_leaf(L) && !isempty(get(cntnr.settings, L, ()))) || continue
        cntnr.pools[L] = _build_pool!(cntnr, L, Float64(slack))
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

function _build_pool!(cntnr::SettingsContainer, ::Type{L}, slack::Float64) where {L<:IndividualSetting}
    leaves = _dfs_leaves(cntnr, L)

    # a container's leaves are consecutive in DFS order, so its span is one index range.
    # ids are contiguous 1..n by now, so a leaf's position is an array index
    pos = Vector{Int32}(undef, length(leaves))
    for (i, l) in enumerate(leaves)
        pos[id(l)] = Int32(i)
    end
    ranges = Vector{UnitRange{Int}}[]
    for C in container_chain(L)
        cs = settings(cntnr, C)
        rs = Vector{UnitRange{Int}}(undef, length(cs))
        for (i, c) in enumerate(cs)
            lo, hi = _leaf_span(pos, cntnr, c)
            rs[i] = hi == 0 ? (1:0) : (lo:hi)
        end
        push!(ranges, rs)
    end

    blocks = _build_blocks!(length(leaves), ranges, slack)
    groups = Any[]
    for (k, C) in enumerate(container_chain(L))
        ptr, idx = _block_containers(ranges[k], blocks, C)
        push!(groups, (settings(cntnr, C), ranges[k], ptr, idx))
    end

    pool = SettingPool(Individual[], 0, 0, leaves, Tuple(groups), blocks, DupTable(), Individual[])
    for (i, l) in enumerate(leaves); l.pool = pool; l.pool_leaf = Int32(i); end
    for g in pool.container_groups, c in g[1]; c.pool = pool; end
    _repack!(pool)

    # settings may already be closed when the population is loaded
    pool.closed = count(!is_open, leaves)
    for g in pool.container_groups
        pool.closed += count(!is_open, g[1])
    end
    return pool
end

# The coarsest partition of `1:nleaves` no container range straddles. Every level, not just the
# root, or a container with no parent gets cut in half. Uncontained leaves stand alone.
function _build_blocks!(nleaves::Int, ranges::Vector{Vector{UnitRange{Int}}}, slack::Float64)
    spans = UnitRange{Int}[]
    for rs in ranges, r in rs
        isempty(r) || push!(spans, r)
    end
    sort!(spans; by = first)

    merged = UnitRange{Int}[]
    for r in spans
        if !isempty(merged) && first(r) <= last(merged[end])
            merged[end] = first(merged[end]):max(last(merged[end]), last(r))
        else
            push!(merged, r)
        end
    end

    first_leaf = Int32[]
    j = 1
    for r in merged
        while j < first(r)
            push!(first_leaf, Int32(j))
            j += 1
        end
        push!(first_leaf, Int32(first(r)))
        j = last(r) + 1
    end
    while j <= nleaves
        push!(first_leaf, Int32(j))
        j += 1
    end
    push!(first_leaf, Int32(nleaves + 1))

    of_leaf = Vector{Int32}(undef, nleaves)
    blocks = PoolBlocks(first_leaf, of_leaf, slack)
    for b in 1:nblocks(blocks), l in leaves_of(blocks, b)
        of_leaf[l] = Int32(b)
    end
    return blocks
end

# Which containers of one level lie in which block, as a CSR index: they come in id order.
function _block_containers(rs::Vector{UnitRange{Int}}, blocks::PoolBlocks, ::Type{C}) where {C}
    nb = nblocks(blocks)
    counts = zeros(Int32, nb)
    for r in rs
        isempty(r) && continue
        b = blocks.of_leaf[first(r)]
        # a container split across blocks would misindex its own frame, silently
        blocks.of_leaf[last(r)] == b ||
            error("a $C spans pool leaves $r, which cross a block boundary; the block " *
                  "partition did not cover every container level")
        counts[b] += 1
    end

    ptr = ones(Int32, nb + 1)
    for b in 1:nb
        ptr[b + 1] = ptr[b] + counts[b]
    end
    idx = Vector{Int32}(undef, Int(ptr[end]) - 1)
    fill = copy(ptr)
    for (i, r) in enumerate(rs)
        isempty(r) && continue
        b = blocks.of_leaf[first(r)]
        idx[fill[b]] = Int32(i)
        fill[b] += 1
    end
    return ptr, idx
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
### REPACKING
###

"""
    repack_dirty_pools!(cntnr::SettingsContainer)

Repack every pool left stale by a member edit. Must run between a membership change and the
next read of `present_members`. `step!` calls it ahead of the transmission phase, which is
the only reader inside a tick, so edits made anywhere in the previous tick are covered.
Cheap when nothing changed.
"""
function repack_dirty_pools!(cntnr::SettingsContainer)
    for pool in values(cntnr.pools)
        bl = pool.blocks
        isempty(bl.dirty) && continue
        # compact once holes outgrow the live data; one flat pass once most blocks are dirty
        if bl.dead * 2 > length(pool.members) || length(bl.dirty) * 4 >= nblocks(bl)
            _repack!(pool)
        else
            for b in bl.dirty
                _repack_block!(pool, Int(b))
            end
            _clear_dirty!(bl)
        end
    end
    return cntnr
end

# Queue a leaf's block. Idempotent, so k edits on one block cost one repack.
function _mark_dirty!(pool::SettingPool, s::IndividualSetting)
    bl = pool.blocks
    b = bl.of_leaf[s.pool_leaf]
    if !bl.is_dirty[b]
        bl.is_dirty[b] = true
        push!(bl.dirty, b)
    end
    return nothing
end

function _clear_dirty!(bl::PoolBlocks)
    for b in bl.dirty
        bl.is_dirty[b] = false
    end
    empty!(bl.dirty)
    return nothing
end

# The slots a block of `n` members is given.
_with_slack(n::Int, slack::Float64) = Int32(n + ceil(Int, slack * n))

"""
    _repack!(pool::SettingPool)

Lay every block out back to back, and every leaf inside its block, refreshing all offsets,
lengths and views. The compaction path: reclaims every hole and re-slacks every block.

Invalidates any previously handed-out member view, which is safe because member edits are
forbidden inside the threaded transmission phase.
"""
function _repack!(pool::SettingPool)
    pool.members = _repack_leaves!(pool.blocks, pool.leaves)
    # re-established here, so an edit's over-count cannot outlive one full repack
    pool.repeats = _count_repeats(pool, pool.leaves)
    _repack_groups!(pool, pool.leaves, pool.container_groups...)
    _clear_dirty!(pool.blocks)
    return nothing
end

"""
    _repack_block!(pool::SettingPool, b::Int)

Relay one block and refresh only the containers inside it - an edit cannot move a coordinate
out of its own block.
"""
function _repack_block!(pool::SettingPool, b::Int)
    _repack_block_leaves!(pool, pool.leaves, b)
    _block_groups!(pool, pool.leaves, b, pool.container_groups...)
    return nothing
end

# Grown to the widest container span, never the pool. Must run before the span it sizes for:
# a table smaller than that spins forever in `_first_seen!`.
function _size_dup_table!(t::DupTable, n::Int)
    want = n == 0 ? 0 : nextpow(2, 2n)
    length(t.keys) >= want && return nothing
    resize!(t.keys, want); resize!(t.pos, want); resize!(t.gen, want)
    fill!(t.gen, Int32(0))
    t.epoch = Int32(0)
    return nothing
end

# Start a fresh container. Every slot the previous one claimed is free again by definition.
@inline function _next_container!(t::DupTable)
    if t.epoch == typemax(Int32)
        fill!(t.gen, Int32(0))
        t.epoch = Int32(1)
    else
        t.epoch += Int32(1)
    end
    return nothing
end

# The position `k` was first seen at in this container, or 0 after claiming a slot for `p`.
@inline function _first_seen!(t::DupTable, k::Int32, p::Int)
    mask = length(t.keys) - 1
    h = (Int(k) * 2654435761) & mask
    e = t.epoch
    @inbounds while true
        if t.gen[h + 1] != e
            t.gen[h + 1] = e
            t.keys[h + 1] = k
            t.pos[h + 1] = Int32(p)
            return 0
        elseif t.keys[h + 1] == k
            return Int(t.pos[h + 1])
        end
        h = (h + 1) & mask
    end
end

function _repack_leaves!(bl::PoolBlocks, leaves::Vector{T}) where {T<:IndividualSetting}
    # place every block before copying: the leaves are pointed into the vector
    total = 0
    @inbounds for b in 1:nblocks(bl)
        n = 0
        for j in leaves_of(bl, b)
            n += length(leaves[j].individuals)
        end
        bl.capacity[b] = _with_slack(n, bl.slack)
        bl.offset[b] = Int32(total + 1)
        total += Int(bl.capacity[b])
    end
    # a repack cannot pack in place: a leaf that grew would overwrite the next leaf before
    # it was copied
    members = Vector{Individual}(undef, total)

    @inbounds for b in 1:nblocks(bl)
        off = Int(bl.offset[b])
        for j in leaves_of(bl, b)
            l = leaves[j]
            n = length(l.individuals)
            copyto!(members, off, l.individuals, 1, n)
            l.pool_offset = Int32(off)
            l.pool_length = Int32(n)
            off += n
        end
    end

    # repoint only after all copying, so no leaf is read after its storage was replaced
    @inbounds for j in eachindex(leaves)
        l = leaves[j]
        lo = Int(l.pool_offset)
        l.individuals = view(members, lo:(lo + Int(l.pool_length) - 1))
    end
    bl.dead = 0
    return members
end

# Memberships beyond the first, counted per block: a repeat only matters inside a container and
# no container straddles one. Block-scoped also keeps the dup table at a single block's width.
function _count_repeats(pool::SettingPool, leaves::Vector{T}) where {T<:IndividualSetting}
    bl = pool.blocks
    tbl = pool.dup_table
    n = 0
    for b in 1:nblocks(bl)
        r = leaves_of(bl, b)
        total = 0
        @inbounds for j in r
            total += length(leaves[j].individuals)
        end
        total == 0 && continue
        _size_dup_table!(tbl, total)
        _next_container!(tbl)
        p = 0
        @inbounds for j in r, m in leaves[j].individuals
            p += 1
            _first_seen!(tbl, id(m), p) == 0 || (n += 1)
        end
    end
    return n
end

# Relay one block's leaves, growing it first if they no longer fit. Behind a barrier because
# `pool.leaves` is widened.
function _repack_block_leaves!(pool::SettingPool, leaves::Vector{T}, b::Int) where {T<:IndividualSetting}
    bl = pool.blocks
    r = leaves_of(bl, b)
    n = 0
    @inbounds for j in r
        n += length(leaves[j].individuals)
    end
    n > Int(bl.capacity[b]) && _relocate_block!(pool, b, n)

    # relaid on top of itself, so a moved leaf would land on one not yet read: via scratch
    scratch = pool.scratch
    length(scratch) < n && resize!(scratch, n)
    at = 1
    @inbounds for j in r
        l = leaves[j]
        m = length(l.individuals)
        copyto!(scratch, at, l.individuals, 1, m)
        at += m
    end

    members = pool.members
    copyto!(members, Int(bl.offset[b]), scratch, 1, n)
    off = Int(bl.offset[b])
    @inbounds for j in r
        l = leaves[j]
        m = length(l.individuals)
        l.pool_offset = Int32(off)
        l.pool_length = Int32(m)
        l.individuals = view(members, off:(off + m - 1))
        off += m
    end
    return nothing
end

# Move a block that outgrew its slack to the end of the pool, stranding the space it held.
function _relocate_block!(pool::SettingPool, b::Int, n::Int)
    bl = pool.blocks
    bl.dead += Int(bl.capacity[b])
    cap = _with_slack(n, bl.slack)
    off = length(pool.members) + 1
    # safe despite the leaves' views: a `SubArray` keeps the parent `Vector`, not a pointer
    resize!(pool.members, length(pool.members) + Int(cap))
    bl.offset[b] = Int32(off)
    bl.capacity[b] = cap
    return nothing
end

# recursive, so each call specialises on that group's concrete vector type
@inline _repack_groups!(pool, leaves) = nothing
@inline function _repack_groups!(pool, leaves, group, rest...)
    _repack_group!(group[1], group[2], pool, leaves)
    _repack_groups!(pool, leaves, rest...)
end

function _repack_group!(cs::Vector{C}, ranges::Vector{UnitRange{Int}}, pool::SettingPool,
                        leaves::Vector{T}) where {C<:ContainerSetting, T<:IndividualSetting}
    @inbounds for i in eachindex(cs)
        _refresh_container!(cs[i], ranges[i], pool, leaves)
    end
    return nothing
end

# the same recursion, restricted to block `b`'s containers
@inline _block_groups!(pool, leaves, b) = nothing
@inline function _block_groups!(pool, leaves, b, group, rest...)
    _block_group!(group[1], group[2], group[3], group[4], b, pool, leaves)
    _block_groups!(pool, leaves, b, rest...)
end

function _block_group!(cs::Vector{C}, ranges::Vector{UnitRange{Int}}, ptr::Vector{Int32},
                       idx::Vector{Int32}, b::Int, pool::SettingPool,
                       leaves::Vector{T}) where {C<:ContainerSetting, T<:IndividualSetting}
    @inbounds for k in Int(ptr[b]):(Int(ptr[b + 1]) - 1)
        i = Int(idx[k])
        _refresh_container!(cs[i], ranges[i], pool, leaves)
    end
    return nothing
end

# One container's span, from its leaves' freshly written offsets.
@inline function _refresh_container!(c::C, r::UnitRange{Int}, pool::SettingPool,
                                     leaves::Vector{T}) where {C<:ContainerSetting, T<:IndividualSetting}
    c.pool_runs = nothing
    if isempty(r)
        c.pool_offset = Int32(0)
        c.pool_length = Int32(0)
        return nothing
    end
    # no gaps inside a block, so the span runs from the first leaf's start to the last's end
    @inbounds lo = leaves[first(r)]
    @inbounds hi = leaves[last(r)]
    len = hi.pool_offset + hi.pool_length - lo.pool_offset
    c.pool_offset = len == 0 ? Int32(0) : lo.pool_offset # 0 means "no members here"
    c.pool_length = len
    len == 0 && return nothing

    # a member in two leaves below sits in the span twice, and only the first copy counts
    pool.repeats == 0 && return nothing
    tbl = pool.dup_table
    _size_dup_table!(tbl, Int(len))
    found = _dup_runs(pool.members, Int(lo.pool_offset), Int(len), tbl)
    if found !== nothing
        runs, kept = found
        c.pool_offset = runs.starts[1]
        c.pool_length = Int32(kept)
        c.pool_runs = runs
    end
    return nothing
end

# The frame for the span `off:(off + len - 1)`, or `nothing` when it holds no member twice.
function _dup_runs(members::Vector{Individual}, off::Int, len::Int, tbl::DupTable)
    _next_container!(tbl)
    # (first position, repeat position) for every copy past the first
    reps = nothing
    @inbounds for p in off:(off + len - 1)
        f = _first_seen!(tbl, id(members[p]), p)
        if f != 0
            reps === nothing && (reps = Tuple{Int32, Int32}[])
            push!(reps, (Int32(f), Int32(p)))
        end
    end
    reps === nothing && return nothing

    # by first position, so groups come out in layout order and a repack is reproducible
    sort!(reps)

    groups = Int32[]; bounds = Int32[]; skips = Int32[]
    prev = Int32(0)
    for (f, p) in reps
        if f != prev
            push!(bounds, Int32(length(groups) + 1))
            push!(groups, f)
            prev = f
        end
        push!(groups, p)
        push!(skips, p)
    end
    push!(bounds, Int32(length(groups) + 1))
    sort!(skips)

    starts, prefix, kept = _drop_skips(Int32[off], Int32[0], len, skips)
    return MemberRuns(starts, prefix, groups, bounds), kept
end

###
### MEMBER EDITS
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
    pool = _pool(s)::SettingPool
    # counted before the add, so an individual already in this block becomes a repeat
    _occurrences(pool, pool.leaves, s, individual) > 0 && (pool.repeats += 1)
    _splice_in!(pool, pool.leaves, s, individual) && return nothing

    v = _detached(s)
    push!(v, individual)
    s.individuals = v
    _mark_dirty!(pool, s)
    return nothing
end

# Swap with last, as before: removal reorders a leaf, which is RNG-visible and unavoidable.
function _pool_remove_member!(s::IndividualSetting, individual::Individual)
    idx = findfirst(i -> i === individual, s.individuals)
    isnothing(idx) && return false

    pool = _pool(s)::SettingPool
    _occurrences(pool, pool.leaves, s, individual) > 1 && (pool.repeats -= 1)
    _splice_out!(pool, pool.leaves, s, idx) && return true

    v = _detached(s)
    @inbounds v[idx] = v[end]
    pop!(v)
    s.individuals = v
    _mark_dirty!(pool, s)
    return true
end

###
### SPLICING
### An edit that fits in its block's slack is made in the pool directly, so the block never
### becomes dirty and members stay readable for the rest of the tick.
###

@inline function _point_at_pool!(members::Vector{Individual}, l::IndividualSetting)
    lo = Int(l.pool_offset)
    l.individuals = view(members, lo:(lo + Int(l.pool_length) - 1))
    return nothing
end

# The block's slots in use, from its last leaf. Valid only while the block is clean, since a
# detached leaf's `pool_length` still describes the span it had before the edit.
@inline function _block_used(bl::PoolBlocks, leaves::Vector{T}, b::Int) where {T<:IndividualSetting}
    @inbounds hi = leaves[last(leaves_of(bl, b))]
    return Int(hi.pool_offset) + Int(hi.pool_length) - Int(bl.offset[b])
end

# Whether `s` can be edited in place: a block already queued is rebuilt wholesale anyway, and
# mixing the two paths would splice against a leaf whose span no longer describes its members.
@inline function _spliceable(bl::PoolBlocks, s::IndividualSetting, b::Int)
    return !bl.is_dirty[b] && s.individuals isa MemberSlice
end

function _splice_in!(pool::SettingPool, leaves::Vector{T}, s::IndividualSetting,
                     individual::Individual) where {T<:IndividualSetting}
    bl = pool.blocks
    b = Int(bl.of_leaf[s.pool_leaf])
    _spliceable(bl, s, b) || return false
    used = _block_used(bl, leaves, b)
    used < Int(bl.capacity[b]) || return false          # no slack left; relocate instead

    members = pool.members
    last_slot = Int(s.pool_offset) + Int(s.pool_length) - 1
    block_end = Int(bl.offset[b]) + used - 1
    # everything below `s` moves up one. copyto! memmoves, so the overlap is safe
    block_end > last_slot &&
        copyto!(members, last_slot + 2, members, last_slot + 1, block_end - last_slot)
    @inbounds members[last_slot + 1] = individual

    s.pool_length += Int32(1)
    _point_at_pool!(members, s)
    @inbounds for j in (Int(s.pool_leaf) + 1):last(leaves_of(bl, b))
        l = leaves[j]
        l.pool_offset += Int32(1)
        _point_at_pool!(members, l)
    end
    _block_groups!(pool, leaves, b, pool.container_groups...)
    return true
end

function _splice_out!(pool::SettingPool, leaves::Vector{T}, s::IndividualSetting,
                      idx::Int) where {T<:IndividualSetting}
    bl = pool.blocks
    b = Int(bl.of_leaf[s.pool_leaf])
    _spliceable(bl, s, b) || return false

    members = pool.members
    lo = Int(s.pool_offset)
    last_slot = lo + Int(s.pool_length) - 1
    block_end = Int(bl.offset[b]) + _block_used(bl, leaves, b) - 1
    # swap with last inside the leaf, as the detached path does: removal reorders a leaf, and
    # that reordering is RNG-visible
    @inbounds members[lo + idx - 1] = members[last_slot]
    block_end > last_slot &&
        copyto!(members, last_slot, members, last_slot + 1, block_end - last_slot)

    s.pool_length -= Int32(1)
    _point_at_pool!(members, s)
    @inbounds for j in (Int(s.pool_leaf) + 1):last(leaves_of(bl, b))
        l = leaves[j]
        l.pool_offset -= Int32(1)
        _point_at_pool!(members, l)
    end
    _block_groups!(pool, leaves, b, pool.container_groups...)
    return true
end

# How many of `s`'s block's leaves hold `individual`.
function _occurrences(pool::SettingPool, leaves::Vector{T}, s::IndividualSetting,
                      individual::Individual) where {T<:IndividualSetting}
    n = 0
    @inbounds for j in leaves_of(pool.blocks, Int(pool.blocks.of_leaf[s.pool_leaf]))
        for m in leaves[j].individuals
            m === individual && (n += 1)
        end
    end
    return n
end

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