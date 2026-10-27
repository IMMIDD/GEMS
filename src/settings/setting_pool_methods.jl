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
hierarchy pool, and only a container with closed descendants, deceased members or a repeated
member needs run indexing.

Equal element for element to `present_individuals(setting, sim)`, except that a member in two
leaves of one container appears once here and twice there.

The result aliases real member storage, so writing to it edits membership - see the note on
`ContactSamplingMethod`.
"""
function present_members(s::FlatSetting, ::SettingsContainer)::MemberView
    return MemberView(s.flat_pool.members, s.offset, is_open(s) ? Int32(_alive(s)) : Int32(0))
end

function present_members(s::IndividualSetting, ::SettingsContainer)::MemberView
    pool = _pool(s)
    if pool === nothing
        # hierarchy leaf not pooled yet: its own vector already holds exactly the members
        v = s.individuals::Vector{Individual}
        return is_open(s) ? MemberView(v, Int32(1), Int32(_alive(s))) : MemberView(v, Int32(1), Int32(0))
    end
    _check_clean(s, pool)
    return is_open(s) ? MemberView(pool.members, s.pool_offset, s.pool_length - Int32(_deceased(s))) :
                        MemberView(pool.members, Int32(1), Int32(0))
end

function present_members(s::ContainerSetting, ::SettingsContainer)::MemberView
    pool = _pool(s)::HierarchicalSettingPool
    _check_clean(s, pool)
    is_open(s) || return MemberView(pool.members, Int32(1), Int32(0))

    # the frame is stored as runs if a member repeats, or something below is closed or has dead members
    r = s.pool_runs
    # zero or one run is a plain slice
    (r === nothing || length(r.starts) <= 1) &&
        return MemberView(pool.members, s.pool_offset, s.pool_length)
    return MemberView(pool.members, r.starts, r.prefix, s.pool_length)
end

# Edits, deaths, scale changes and opening or closing leave the pool's offsets and frames stale until it is
# repacked, so reads error until then. `present_individuals` reads the member vectors and still works.
@inline function _check_clean(s::Setting, pool::HierarchicalSettingPool)
    isempty(pool.blocks.dirty) || error(
        "$(typeof(s)) belongs to a setting pool with pending member edits or closures. Call " *
        "`repack_dirty_pools!` after editing membership, marking members deceased, or opening or closing settings, and " *
        "before reading members.")
    return nothing
end

###
### MEMBER RUNS
### Run arithmetic shared by the closed case and the repeated-member case, both of which turn
### a container's span into several runs.
###

# How many members run `r` holds: up to the next run's prefix, or to the frame's `total` for the last.
Base.@propagate_inbounds _run_length(prefix::Vector{Int32}, total::Int, r::Int) =
    (r < length(prefix) ? Int(prefix[r + 1]) : total) - Int(prefix[r])

# Where pool position `p` sits in a run-indexed frame, 0 when the runs do not cover it.
@inline function _run_index(starts::Vector{Int32}, prefix::Vector{Int32}, total::Int, p::Int)
    r = searchsortedlast(starts, Int32(p))
    r == 0 && return 0
    @inbounds off = p - Int(starts[r])
    @inbounds len = _run_length(prefix, total, r)
    off < len || return 0
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
        stop = lo + _run_length(prefix, total, r)
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

# Which repeats to drop given the open runs. The first copy still present is kept, so closing its leaf
# keeps the member through the next copy.
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

"""
    build_pools!(cntnr::SettingsContainer; slack::Real = DEFAULT_POOL_SLACK)

Move each pooled hierarchy's leaf members into one `HierarchicalSettingPool` and repoint the leaves at
their slices. Relocates storage rather than duplicating it. Idempotent per container.

`slack` is each block's headroom as a fraction of its length; zero packs blocks exact-fit. The
flat pools take it too, as the room a setting gets when it outgrows its slots.
"""
function build_pools!(cntnr::SettingsContainer; slack::Real = DEFAULT_POOL_SLACK)
    slack >= 0 || throw(ArgumentError("pool slack must not be negative, got $slack"))
    for pool in values(cntnr.flat_pools)
        pool.slack = Float64(slack)
    end
    _check_contiguous_ids(cntnr)
    types = [L for L in settingtypes_sorted(cntnr) if is_pooled_leaf(L) && !isempty(get(cntnr.settings, L, ()))]
    # the hierarchies share no settings, so their pools build in parallel
    tasks = [Threads.@spawn _build_pool!(cntnr, L, Float64(slack)) for L in types]
    for (L, task) in zip(types, tasks)
        cntnr.pools[L] = _fetch_rethrow(task)
    end
    return cntnr
end

# Settings are looked up by id (`settings(cntnr, T)[id]`), so the ids must run 1..n.
function _check_contiguous_ids(cntnr::SettingsContainer)
    for T in settingtypes_sorted(cntnr)
        # every container, roots included, and every pooled leaf is looked up by id
        (T <: ContainerSetting || is_pooled_leaf(T)) || continue
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
        push!(ranges, _leaf_ranges(pos, cntnr, settings(cntnr, C)))
    end

    blocks = _build_blocks(length(leaves), ranges, slack)
    groups = Any[]
    for (k, C) in enumerate(container_chain(L))
        ptr, idx = _block_containers(ranges[k], blocks, C)
        push!(groups, ContainerLevel(settings(cntnr, C), ranges[k], ptr, idx))
    end

    closed = count(!is_open, leaves) + sum(g -> count(!is_open, g.containers), groups; init = 0)
    deceased = sum(_deceased, leaves; init = 0)
    pool = HierarchicalSettingPool(leaves, Tuple(groups), blocks, closed, deceased)

    # detach first, or a rebuilt leaf reads its old offsets from the new, empty pool
    for (i, l) in enumerate(leaves)
        l.individuals = _detached(l)
        l.pool = pool
        l.pool_leaf = Int32(i)
    end
    # every frame starts empty; the repack fills those of containers with leaves, the rest stay empty
    for g in pool.container_groups, c in g.containers
        c.pool = pool
        c.pool_offset, c.pool_length, c.pool_runs = Int32(0), Int32(0), nothing
        hasfield(typeof(c), :scale_bound) && (c.scale_bound = 1.0f0)
    end
    # counted once here; the edits keep it exact
    pool.repeats = _count_repeats(pool, leaves)
    _repack_all!(pool)
    return pool
end

# Splits `1:nleaves` into the smallest blocks that no container range straddles. Spans of every level
# count, since a container orphaned partway down has no root above it.
function _build_blocks(nleaves::Int, ranges::Vector{Vector{UnitRange{Int}}}, slack::Float64)
    # a leaf starts a block unless a span covers it past the span's first leaf
    starts_block = trues(nleaves)
    for rs in ranges, r in rs
        isempty(r) || (starts_block[(first(r) + 1):last(r)] .= false)
    end
    first_leaf = Int32[findall(starts_block); nleaves + 1]

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
        # a container split across blocks would misindex its frame
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

# each container's leaf range; a barrier like `_take_leaves!`
function _leaf_ranges(pos, cntnr::SettingsContainer, cs::Vector{C}) where {C<:ContainerSetting}
    rs = Vector{UnitRange{Int}}(undef, length(cs))
    for (i, c) in enumerate(cs)
        lo, hi = _leaf_span(pos, cntnr, c)
        rs[i] = hi == 0 ? (1:0) : (lo:hi)
    end
    return rs
end

# Lowest and highest layout position `s` covers, `(typemax(Int), 0)` for none. A leaf under two
# parents spans both.
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

# Leaves in DFS order over `contains`, which keeps each container's members contiguous: roots first,
# then subtrees orphaned partway down, then leaves under no container.
function _dfs_leaves(cntnr::SettingsContainer, ::Type{L}) where {L<:IndividualSetting}
    leaves = settings(cntnr, L)
    order = Vector{L}()
    taken = falses(length(leaves)) # ids are contiguous 1..n by now

    for C in reverse(container_chain(L))
        _take_leaves!(order, taken, cntnr, settings(cntnr, C))
    end
    for leaf in leaves
        _take_leaf!(order, taken, cntnr, leaf)
    end
    return order
end

# barrier: `C` is only known at runtime, so iterate its settings behind a concrete vector type
function _take_leaves!(order, taken, cntnr::SettingsContainer, cs::Vector{C}) where {C<:Setting}
    for s in cs
        _take_leaf!(order, taken, cntnr, s)
    end
    return nothing
end

function _take_leaf!(order, taken, ::SettingsContainer, s::IndividualSetting)
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
### PENDING CHANGES
### What the next repack has to catch up on: the blocks edits, deaths, closures and scale changes
### left stale, and how many settings are closed.
###

# Queue a leaf's block. Idempotent, so k edits on one block cost one repack.
_mark_dirty!(pool::HierarchicalSettingPool, s::IndividualSetting) =
    _mark_block_dirty!(pool.blocks, pool.blocks.of_leaf[s.pool_leaf])

# A container lies in its first leaf's block, as no container crosses a block. Nothing to do for one
# without leaves.
function _mark_dirty!(pool::HierarchicalSettingPool, c::ContainerSetting)
    r = _leaf_range(c)
    isempty(r) || _mark_block_dirty!(pool.blocks, pool.blocks.of_leaf[first(r)])
    return nothing
end

function _mark_block_dirty!(bl::PoolBlocks, b::Int32)
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

# `open!` and `close!` keep this in step; they only call it on a real state change.
function _count_closed!(pool::HierarchicalSettingPool, delta::Int)
    pool.closed += delta
    return nothing
end

# Whether every setting of the hierarchy with leaf type `L` is open. `false` if `L` has no pool
function _all_open(cntnr::SettingsContainer, ::Type{L}) where {L<:Setting}
    pool = get(cntnr.pools, L, nothing)
    return pool !== nothing && pool.closed == 0
end

###
### REPACKING
### A repack relays a block's leaves, laying their members out in the pool again, and refreshes
### the containers above them, reading their frames back from the leaves' new offsets. LEAF
### LAYOUT and CONTAINER REFRESH below hold the two halves.
###
### Several functions here take `leaves` alongside `pool`, always `pool.leaves`. The field is
### widened to hold a `Vector{SchoolClass}` or `Vector{Office}`, so passing it as an argument
### is what lets the callee specialise on the concrete vector. Do not "simplify" it away.
###

"""
    repack_dirty_pools!(cntnr::SettingsContainer)

Repack every pool left stale by a member edit, a death, a scale change, or a setting opened or closed,
and compact every flat pool that moved settings have left a third stranded.
Must run between such a change and the next read of `present_members`, so every reader of frames
calls it first; `spread_infections!` does once per tick.
Cheap when nothing changed. The dirty blocks of a pool are repacked in parallel.

Invalidates any member view handed out before, since members move and a pool may be replaced.
That is safe because it runs outside the transmission phase, the only place views are held.
"""
function repack_dirty_pools!(cntnr::SettingsContainer)
    for (T, pool) in cntnr.flat_pools
        # a third: moves copy whole settings with slack, so they never strand half the pool
        pool.dead * 3 > length(pool.members) && _compact_flat!(pool, settings(cntnr, T))
    end
    for pool in values(cntnr.pools)
        bl = pool.blocks
        isempty(bl.dirty) && continue
        # relocations have stranded half the pool: lay everything out afresh
        if bl.dead * 2 > length(pool.members)
            _repack_all!(pool)
        else
            _repack_dirty!(pool)
        end
    end
    return cntnr
end

# Lays the pool's settings out again in the order they are stored, each keeping its slots, and
# drops the stranded ones. Moves no member within its setting.
function _compact_flat!(pool::FlatSettingPool, stngs::Vector{T}) where {T<:FlatSetting}
    old = pool.members
    n = 0
    for s in stngs
        s.flat_pool === pool && (n += Int(s.cap))
    end
    members = Vector{Individual}(undef, n)
    at = 1
    for s in stngs
        s.flat_pool === pool || continue
        copyto!(members, at, old, Int(s.offset), Int(s.len))
        s.offset = at
        at += Int(s.cap)
    end
    pool.members = members
    pool.dead = 0
    return nothing
end

"""
    _repack_all!(pool::HierarchicalSettingPool)

Lay every block out back to back in a new member vector, and every leaf inside its block,
then refresh every container's frame. The compaction path: reclaims every hole and re-slacks
every block.
"""
function _repack_all!(pool::HierarchicalSettingPool)
    bl = pool.blocks
    blocks = 1:nblocks(bl)
    # a new vector: the old one is read until every block has moved
    members = Vector{Individual}(undef, _place_blocks!(bl, pool.leaves))
    _foreach_block!((_, leaves, b, _...) -> _copy_block!(members, bl, leaves, b), pool, blocks)
    pool.members = members
    bl.dead = 0
    # frames read `pool.members`, so refresh them after the swap
    _foreach_block!(_refresh_block!, pool, blocks)
    _clear_dirty!(bl)
    return nothing
end

# Repacks the dirty blocks and empties the queue. A relocation grows `pool.members`, which the
# other tasks read, so the outgrown blocks move first.
function _repack_dirty!(pool::HierarchicalSettingPool)
    dirty = pool.blocks.dirty
    _relocate_outgrown!(pool, pool.leaves, dirty)
    _foreach_block!(_repack_block!, pool, dirty)
    _clear_dirty!(pool.blocks)
    return nothing
end

# Relays block `b`'s leaves and refreshes the containers above them, working in `buf`.
@inline function _repack_block!(pool::HierarchicalSettingPool, leaves::Vector{T}, b::Int,
                                buf::RepackBuffer, levels::Vararg{Any, N}) where {T<:IndividualSetting, N}
    _relay_block!(pool, leaves, b, buf)
    _refresh_block!(pool, leaves, b, buf, levels...)
    return nothing
end

# Runs `work(pool, leaves, b, buf, levels...)` for every block `b` in `blocks`. Blocks share no
# leaf and no container, so tasks take them at once, each in a buffer of its own.
function _foreach_block!(work::F, pool::HierarchicalSettingPool, blocks::AbstractVector{<:Integer}) where {F}
    # blocks differ in size, so tasks claim them one at a time
    next = Threads.Atomic{Int}(1)
    # at most one task per block
    nt = min(Threads.nthreads(), length(blocks))
    if nt <= 1
        # a single task runs inline, off the scheduler
        _claim_blocks!(work, pool, pool.leaves, blocks, next, pool.buffer, pool.container_groups...)
    else
        buffers = pool.task_buffers
        length(buffers) < nt && resize!(buffers, nt)
        # buffers are picked by `t`, since a task may change threads
        Threads.@threads :dynamic for t in 1:nt
            # made by the task that uses it, so no two tasks write to one cache line
            isassigned(buffers, t) || (buffers[t] = RepackBuffer())
            _claim_blocks!(work, pool, pool.leaves, blocks, next, buffers[t], pool.container_groups...)
        end
    end
    return nothing
end

# One task's loop: claims blocks until none are left. Also the function barrier over the pool's
# abstract fields, once per task.
function _claim_blocks!(work::F, pool::HierarchicalSettingPool, leaves::Vector{T}, blocks::AbstractVector{<:Integer},
                        next::Threads.Atomic{Int}, buf::RepackBuffer,
                        levels::Vararg{Any, N}) where {F, T<:IndividualSetting, N}
    while true
        k = Threads.atomic_add!(next, 1)
        k > length(blocks) && return nothing
        work(pool, leaves, Int(@inbounds blocks[k]), buf, levels...)
    end
end

###
### LEAF LAYOUT
### Where each leaf's members sit in the pool. A dirty block is relaid in place; a full repack
### copies every block into a new vector.
###

# How many members block `b`'s leaves hold between them.
@inline function _block_members(bl::PoolBlocks, leaves::Vector{T}, b::Int) where {T<:IndividualSetting}
    n = 0
    @inbounds for j in leaves_of(bl, b)
        n += length(individuals(leaves[j]))
    end
    return n
end

# The slots a block of `n` members is given.
_with_slack(n::Int, slack::Float64) = Int32(n + ceil(Int, slack * n))

# Gives every block fresh slack, back to back from the start, and returns how long a member vector
# holding them must be.
function _place_blocks!(bl::PoolBlocks, leaves::Vector{T}) where {T<:IndividualSetting}
    total = 0
    @inbounds for b in 1:nblocks(bl)
        bl.capacity[b] = _with_slack(_block_members(bl, leaves, b), bl.slack)
        bl.offset[b] = Int32(total + 1)
        total += Int(bl.capacity[b])
    end
    return total
end

# Copies block `b`'s leaves' members into `dest` from position `at`, one leaf after another.
@inline function _gather_block!(dest::Vector{Individual}, at::Int, bl::PoolBlocks,
                                leaves::Vector{T}, b::Int) where {T<:IndividualSetting}
    @inbounds for j in leaves_of(bl, b)
        v = individuals(leaves[j])
        copyto!(dest, at, v, 1, length(v))
        at += length(v)
    end
    return nothing
end

# Copies block `b` into the new vector `members` at the block's offset and points its leaves
# there. The old vector stays readable for the blocks not copied yet.
function _copy_block!(members::Vector{Individual}, bl::PoolBlocks, leaves::Vector{T}, b::Int) where {T<:IndividualSetting}
    _gather_block!(members, Int(bl.offset[b]), bl, leaves, b)
    _point_leaves!(bl, leaves, b)
    return nothing
end

# Writes block `b`'s members back into the block's own slots and points its leaves there. The
# block must fit: `_repack_dirty!` relocates outgrown blocks before any is relaid.
function _relay_block!(pool::HierarchicalSettingPool, leaves::Vector{T}, b::Int,
                       buf::RepackBuffer) where {T<:IndividualSetting}
    bl = pool.blocks
    n = _block_members(bl, leaves, b)
    # past its capacity, the block would overwrite the next one
    n <= Int(bl.capacity[b]) || error("block $b holds $n members but has room for $(bl.capacity[b]); " *
                                      "relocate outgrown blocks before relaying")

    # relaid in place, a moved leaf could overwrite one not yet read, so go through the buffer
    temp = buf.block
    length(temp) < n && resize!(temp, n)
    _gather_block!(temp, 1, bl, leaves, b)
    copyto!(pool.members, Int(bl.offset[b]), temp, 1, n)
    _point_leaves!(bl, leaves, b)
    return nothing
end

# Points block `b`'s leaves at consecutive ranges from the block's offset, each as long as it is
# now, and reattaches a leaf an edit had detached. Reads each leaf's length before moving it.
function _point_leaves!(bl::PoolBlocks, leaves::Vector{T}, b::Int) where {T<:IndividualSetting}
    off = Int(bl.offset[b])
    @inbounds for j in leaves_of(bl, b)
        l = leaves[j]
        m = length(individuals(l))
        l.pool_offset = Int32(off)
        l.pool_length = Int32(m)
        l.individuals = nothing
        off += m
    end
    return nothing
end

# Move a block that outgrew its slack to the end of the pool, stranding the space it held.
function _relocate_block!(pool::HierarchicalSettingPool, b::Int, n::Int)
    bl = pool.blocks
    bl.dead += Int(bl.capacity[b])
    cap = _with_slack(n, bl.slack)
    off = length(pool.members) + 1
    # safe for the leaves: `individuals` reads `pool.members` afresh, never a stored pointer
    resize!(pool.members, length(pool.members) + Int(cap))
    bl.offset[b] = Int32(off)
    bl.capacity[b] = cap
    return nothing
end

# Relocates every dirty block that outgrew its slack, in queue order, so where they land does not
# depend on the tasks.
function _relocate_outgrown!(pool::HierarchicalSettingPool, leaves::Vector{T}, dirty) where {T<:IndividualSetting}
    bl = pool.blocks
    for b in dirty
        n = _block_members(bl, leaves, Int(b))
        n > Int(bl.capacity[b]) && _relocate_block!(pool, Int(b), n)
    end
    return nothing
end

###
### CONTAINER REFRESH
### A container stores no members, so its span is read back from its leaves' fresh offsets.
###

# Refreshes the frames of the containers above block `b`'s leaves, working in `buf`. Recursive and
# `Vararg{Any, N}` over the levels, so each call specialises on that level's concrete container vector.
@inline _refresh_block!(pool, leaves, b, buf) = nothing
@inline function _refresh_block!(pool, leaves, b, buf, level, rest::Vararg{Any, N}) where {N}
    _refresh_level!(pool, leaves, b, buf, level)
    _refresh_block!(pool, leaves, b, buf, rest...)
end

# The containers of one level that lie in block `b`.
function _refresh_level!(pool::HierarchicalSettingPool, leaves::Vector{T}, b::Int, buf::RepackBuffer,
                         lv::ContainerLevel{C}) where {C, T<:IndividualSetting}
    @inbounds for k in Int(lv.block_ptr[b]):(Int(lv.block_ptr[b + 1]) - 1)
        i = Int(lv.block_idx[k])
        _refresh_container!(lv.containers[i], lv.ranges[i], pool, leaves, buf)
    end
    return nothing
end

# One container's span, from its leaves' freshly written offsets. `r` is never empty: a container
# without leaves lies in no block.
@inline function _refresh_container!(c::C, r::UnitRange{Int}, pool::HierarchicalSettingPool,
                                     leaves::Vector{T}, buf::RepackBuffer) where {C<:ContainerSetting, T<:IndividualSetting}
    # sampling methods drop what they derived from the old frame
    membership_changed!(contact_sampling_method(c), c)
    # a member's scale here never exceeds 1 or its largest leaf's, so the leaves bound it
    if hasfield(C, :scale_bound)
        bound = 1.0f0
        @inbounds for j in r
            bound = max(bound, _scale_bound(leaves[j]))
        end
        c.scale_bound = bound
    end
    # no gaps inside a block, so the span runs from the first leaf's start to the last's end
    @inbounds lo = leaves[first(r)]
    @inbounds hi = leaves[last(r)]
    len = hi.pool_offset + hi.pool_length - lo.pool_offset
    if len == 0
        # 0 means "no members here"
        c.pool_offset, c.pool_length, c.pool_runs = Int32(0), Int32(0), nothing
        return nothing
    end

    # a member in two leaves below sits in the span twice, and only the first copy counts
    runs, kept = pool.repeats == 0 ? (nothing, Int(len)) :
        _dup_runs(pool.members, Int(lo.pool_offset), Int(len), buf.dup_table)
    if (pool.closed != 0 || pool.deceased != 0) && !_all_present(pool, leaves, r, C)
        # a closure or death below takes members out of the frame
        _set_present_frame!(c, r, pool, leaves, buf, runs)
    else
        c.pool_offset, c.pool_length, c.pool_runs = lo.pool_offset, Int32(kept), runs
    end
    return nothing
end

# Sets a container's frame to the living members of leaves open up to it; `present_members` handles
# closures at and above it. `dup` is `_dup_runs`' frame, or `nothing` without repeats.
function _set_present_frame!(c::C, r::UnitRange{Int}, pool::HierarchicalSettingPool, leaves::Vector{T},
                             buf::RepackBuffer, dup::Union{Nothing, MemberRuns}) where {C<:ContainerSetting, T<:IndividualSetting}
    # built in the buffer, so a frame that stays one run allocates nothing
    starts = empty!(buf.run_starts); prefix = empty!(buf.run_prefix)
    total = 0
    run_end = -1
    @inbounds for j in r
        l = leaves[j]
        # deceased members sit at the end of the leaf, past its living ones
        n = Int(l.pool_length) - _deceased(l)
        (n > 0 && _open_up_to(pool, l, C)) || continue
        lo = Int(l.pool_offset)
        # a leaf that starts where the previous run ends extends it
        if lo != run_end
            push!(starts, Int32(lo))
            push!(prefix, Int32(total))
        end
        total += n
        run_end = lo + n
    end

    if dup !== nothing
        # of a repeated member, the first copy still present is the one kept
        skips = _repeat_skips(dup, starts, prefix, total)
        isempty(skips) || ((starts, prefix, total) = _drop_skips(starts, prefix, total, skips))
        c.pool_runs = MemberRuns(copy(starts), copy(prefix), dup.groups, dup.bounds)
    elseif length(starts) > 1
        c.pool_runs = MemberRuns(copy(starts), copy(prefix), NO_RUNS, NO_RUNS)
    else
        # without repeats, one run or none is a plain span and stores no runs
        c.pool_runs = nothing
    end
    c.pool_offset = isempty(starts) ? Int32(0) : starts[1]
    c.pool_length = Int32(total)
    return nothing
end

# Whether every leaf with members in the range is present in the frame of its ancestor of type `C`.
function _all_present(pool::HierarchicalSettingPool, leaves::Vector{T}, r::UnitRange{Int},
                      ::Type{C}) where {C<:ContainerSetting, T<:IndividualSetting}
    @inbounds for j in r
        l = leaves[j]
        (l.pool_length == 0 || (_deceased(l) == 0 && _open_up_to(pool, l, C))) || return false
    end
    return true
end

###
### DUPLICATE DETECTION
### A member in two leaves of one container would sit in its frame twice. `pool.repeats`
### gates all of this: at zero, none of it runs.
###

# Readies the table for a scan of `n` members: all slots free, and at least 2n of them, as a fuller
# table loops forever in `_first_seen!`. It only grows, to the widest span scanned.
function _start_scan!(t::DupTable, n::Int)
    want = n == 0 ? 0 : nextpow(2, 2n)
    if length(t.keys) < want
        resize!(t.keys, want); resize!(t.pos, want); resize!(t.gen, want)
        fill!(t.gen, Int32(0))
        t.epoch = Int32(0)
    end
    # a new epoch frees every slot an earlier scan claimed
    if t.epoch == typemax(Int32)
        fill!(t.gen, Int32(0))
        t.epoch = Int32(1)
    else
        t.epoch += Int32(1)
    end
    return nothing
end

# What `===` compares; unlike `id`, it reads nothing from the object.
@inline _identity(m::Individual) = UInt(pointer_from_objref(m))

# The position `k` was first seen at in this scan, or 0 after claiming a slot for `p`. Positions
# start at 1, so 0 is free to mean "not seen".
@inline function _first_seen!(t::DupTable, k::UInt, p::Int)
    mask = UInt(length(t.keys) - 1)
    # identities are addresses, so the low bits are alignment: drop them, multiply, and take the
    # well-mixed upper half of the product
    h = (((k >> 4) * 0x9e3779b97f4a7c15) >> 32) & mask
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
        h = (h + UInt(1)) & mask
    end
end

# The frame for the span `off:(off + len - 1)` holding each member once, as (runs, members kept). The
# runs are `nothing` when no member repeats. The first run starts at `off`, as a first copy is never dropped.
function _dup_runs(members::Vector{Individual}, off::Int, len::Int, tbl::DupTable)
    _start_scan!(tbl, len)
    # (first position, repeat position) for every copy past the first
    reps = nothing
    @inbounds for p in off:(off + len - 1)
        f = _first_seen!(tbl, _identity(members[p]), p)
        if f != 0
            reps === nothing && (reps = Tuple{Int32, Int32}[])
            push!(reps, (Int32(f), Int32(p)))
        end
    end
    reps === nothing && return (nothing, len)

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

# Memberships beyond the first, counted per block, since no container straddles one. This also keeps
# the dup table one block wide.
function _count_repeats(pool::HierarchicalSettingPool, leaves::Vector{T}) where {T<:IndividualSetting}
    bl = pool.blocks
    tbl = pool.buffer.dup_table
    n = 0
    for b in 1:nblocks(bl)
        r = leaves_of(bl, b)
        total = _block_members(bl, leaves, b)
        total == 0 && continue
        _start_scan!(tbl, total)
        p = 0
        @inbounds for j in r, m in individuals(leaves[j])
            p += 1
            _first_seen!(tbl, _identity(m), p) == 0 || (n += 1)
        end
    end
    return n
end

###
### MEMBER EDITS
### How `add_member!` / `remove_member!` in settings.jl store the change, per kind of storage.
###

# The leaf's members as a vector it owns: its own if it has one, else copied out of the pool. Edits
# leave the pool stale until `repack_dirty_pools!`, which repacks once per batch.
_detached(s::IndividualSetting)::Vector{Individual} =
    s.individuals === nothing ? collect(individuals(s)) : s.individuals

# Stores a newcomer after the setting's last member.
function _store_member!(s::IndividualSetting, individual::Individual, plans)
    pool = _pool(s)
    # already in the block, so this is a second membership
    pool !== nothing && _in_block(pool, plans, s, individual) && (pool.repeats += 1)
    v = _detached(s)
    push!(v, individual)
    s.individuals = v
    pool === nothing || _mark_dirty!(pool, s)
    return nothing
end

# A flat setting fills its next free slot. Out of slots, it grows in place when it ends the pool,
# and otherwise moves to the end, stranding the slots it held. Either way it gains slack.
function _store_member!(s::FlatSetting, individual::Individual, _)
    pool = s.flat_pool
    m = pool.members
    n = Int(s.len)
    if n == Int(s.cap)
        grow = max(1, ceil(Int, pool.slack * n))
        if Int(s.offset) + n - 1 == length(m)
            resize!(m, length(m) + grow)
        else
            at = length(m) + 1
            resize!(m, length(m) + n + grow)
            copyto!(m, at, m, Int(s.offset), n)
            pool.dead += n
            s.offset = at
        end
        s.cap += Int32(grow)
    end
    @inbounds m[Int(s.offset) + n] = individual
    s.len += Int32(1)
    return nothing
end

# Drops the member at `idx` by swapping the last member into its place. This reorders the leaf, which
# changes later random draws.
function _unstore_member!(s::IndividualSetting, individual::Individual, idx::Int, plans)
    pool = _pool(s)
    # in the block twice, so this removal leaves one behind
    pool !== nothing && _repeated_in_block(pool, plans, s, individual) && (pool.repeats -= 1)
    v = _detached(s)
    @inbounds v[idx] = v[end]
    pop!(v)
    s.individuals = v
    pool === nothing || _mark_dirty!(pool, s)
    return nothing
end

# The freed slot stays the setting's, for its next member.
function _unstore_member!(s::FlatSetting, ::Individual, idx::Int, _)
    m = s.flat_pool.members
    r = _flat_range(s)
    @inbounds m[r[idx]] = m[last(r)]
    s.len -= Int32(1)
    return nothing
end

# Whether `individual` sits in more than `n` leaves of `s`'s block, usually answered by the plan alone.
# Leaf and plan must both still show the state before the edit, as in `add_member!` and `remove_member!`.
@inline function _in_more_leaves_than(pool::HierarchicalSettingPool, plans, s::IndividualSetting,
                                      individual::Individual, n::Int)
    length(plan_slots(plans, individual, typeof(s))) <= n && return false
    return _occurrences(pool, pool.leaves, s, individual) > n
end

# Already a member of `s`'s block.
@inline _in_block(pool::HierarchicalSettingPool, plans, s::IndividualSetting, individual::Individual) =
    _in_more_leaves_than(pool, plans, s, individual, 0)

# A member of `s`'s block more than once.
@inline _repeated_in_block(pool::HierarchicalSettingPool, plans, s::IndividualSetting, individual::Individual) =
    _in_more_leaves_than(pool, plans, s, individual, 1)

# How many of `s`'s block's leaves hold `individual`
function _occurrences(pool::HierarchicalSettingPool, leaves::Vector{T}, s::IndividualSetting,
                      individual::Individual) where {T<:IndividualSetting}
    n = 0
    @inbounds for j in leaves_of(pool.blocks, Int(pool.blocks.of_leaf[s.pool_leaf]))
        for m in individuals(leaves[j])
            m === individual && (n += 1)
        end
    end
    return n
end

###
### HIERARCHY TRAITS
###

# Both traits derive from `contained_type`, so a new level or user type joins a hierarchy by defining
# it. Root containers leave it undefined, which ends the walk. Both run at pool construction only.

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

###
### SETTING HELPERS
### Small lookups on a setting and its pool, used on the per-tick path as well as at construction.
###

# The setting's pool, or `nothing` when unpooled. `hasfield` folds on a concrete type, so
# this compiles to a field load or a constant.
@inline _pool(s::T) where {T<:Setting} = hasfield(T, :pool) ? s.pool : nothing

# how many members at the end of the setting's list have died; none for a type without the field
@inline _deceased(s::T) where {T<:Setting} = hasfield(T, :deceased) ? Int(s.deceased) : 0

# how many members come before the deceased ones
@inline _alive(s::IndividualSetting) = length(individuals(s)) - _deceased(s)

# whether the member at position `idx` is deceased
@inline _is_deceased(s::IndividualSetting, idx::Integer) = _deceased(s) > 0 && idx > _alive(s)

# Whether `s` sits under a container: its type has a parent level and its `contained` id is set.
# `hasfield` folds on a concrete type, so a type without a parent compiles to `false`.
@inline _has_container(s::S) where {S<:Setting} = hasfield(S, :contained) && s.contained != DEFAULT_SETTING_ID

# c's leaves, as the range of its pool's leaves `_build_pool!` recorded for it
@inline function _leaf_range(c::C) where {C<:ContainerSetting}
    level = (_pool(c)::HierarchicalSettingPool).container_groups[_container_depth(C)]::ContainerLevel{C}
    return @inbounds level.ranges[id(c)]
end

# levels above the leaf type, which is C's position in `container_groups`
_container_depth(::Type{T}) where {T<:IndividualSetting} = 0
_container_depth(::Type{C}) where {C<:ContainerSetting} = 1 + _container_depth(contains_type(C))

# Whether `s` and every container between it and its ancestor of type `C` are open, that ancestor
# not included. Climbs through the pool's own levels, so it needs no settings container.
@inline _open_up_to(::HierarchicalSettingPool, ::C, ::Type{C}) where {C<:ContainerSetting} = true
function _open_up_to(pool::HierarchicalSettingPool, s::S, ::Type{C}) where {S<:Setting, C<:ContainerSetting}
    is_open(s) || return false
    P = contained_type(S)
    lv = pool.container_groups[_container_depth(P)]::ContainerLevel{P}
    return _open_up_to(pool, @inbounds(lv.containers[s.contained]), C)
end

# Whether the member at `idx` of `leaf` is in `c`'s frame: alive, in a leaf below `c` and open up to it.
# `c`'s own closure is not checked.
@inline _in_container_frame(c::C, pool::HierarchicalSettingPool, leaf::IndividualSetting, idx::Integer) where {C<:ContainerSetting} =
    Int(leaf.pool_leaf) in _leaf_range(c) && (pool.closed == 0 || _open_up_to(pool, leaf, C)) && !_is_deceased(leaf, idx)
