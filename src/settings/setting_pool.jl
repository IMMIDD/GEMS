###
### SETTING POOL (TYPE DEFINITIONS)
###

###
### MEMBER STORAGE
###

# A contiguous view into a pool's member vector, as `individuals` returns for a pooled setting.
const MemberSlice = SubArray{Individual, 1, Vector{Individual}, Tuple{UnitRange{Int64}}, true}

###
### MEMBER VIEWS
###

"""
    MemberRuns

A container's frame when it is not one span: a member sits in two of its leaves at once, or
something below it is closed or holds deceased members. The frame skips those positions.

# Fields

- `starts::Vector{Int32}`, `prefix::Vector{Int32}`: Run `r` starts at pool position `starts[r]`
    and has `prefix[r]` frame members before it; the last run ends at the frame's length. This
    is the encoding `MemberView` indexes with.
- `groups::Vector{Int32}`: The pool positions of each repeated member, one group after another,
    ascending within a group. The same refresh reads them to keep the first copy still present
    when a closure or death takes out another.
- `bounds::Vector{Int32}`: Group `g` is `groups[bounds[g]:(bounds[g + 1] - 1)]`.
"""
struct MemberRuns
    starts::Vector{Int32}
    prefix::Vector{Int32}
    groups::Vector{Int32}
    bounds::Vector{Int32}
end

# Shared by every contiguous view, so the common case allocates no run vectors.
const NO_RUNS = Int32[]

"""
    MemberView

A setting's present members, as a window onto its hierarchy's pool. Usually one unbroken span,
described by `offset` and `len`. A container with closed descendants, deceased members or a member in
two of its leaves needs several runs, and then `starts`/`prefix` describe them and indexing
binary-searches `prefix`.

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

###
### THE POOL
###

"""
    DupTable

Repack buffer for spotting a member that sits in two leaves of one container. Open addressing
keyed on object identity, which costs no load from the member.

# Fields

- `keys::Vector{UInt}`: The member identity in that slot, meaningful only while `gen` matches.
- `pos::Vector{Int32}`: The first pool position that member was seen at.
- `gen::Vector{Int32}`: The `epoch` that last claimed the slot; anything else means free.
- `epoch::Int32`: Bumped per scan, which frees every slot at once.
"""
mutable struct DupTable
    keys::Vector{UInt}
    pos::Vector{Int32}
    gen::Vector{Int32}
    epoch::Int32
end

DupTable() = DupTable(UInt[], Int32[], Int32[], Int32(0))

"""
    RepackBuffer

The buffers a repack works in. A repack on one task uses its pool's own; a repack on several
tasks gives each one, so blocks repacked at the same time share nothing. Mutable so an unfilled
slot of a task's vector reads as unassigned.

# Fields

- `block::Vector{Individual}`: Holds one block while it is relaid on itself.
- `run_starts::Vector{Int32}`, `run_prefix::Vector{Int32}`: A container's frame, before it is
    known to need runs.
- `dup_table::DupTable`: Finds a member that sits in two leaves of one container. Grown to the
    widest span it is asked to scan and reused from there.
"""
mutable struct RepackBuffer
    block::Vector{Individual}
    run_starts::Vector{Int32}
    run_prefix::Vector{Int32}
    dup_table::DupTable
end

RepackBuffer() = RepackBuffer(Individual[], Int32[], Int32[], DupTable())

###
### BLOCKS
###

# A block's default headroom, as a fraction of its length: memory against relocations.
const DEFAULT_POOL_SLACK = 0.25

"""
    PoolBlocks

The pool's leaves cut into independently repackable blocks, so an edit repacks its own subtree
rather than the hierarchy. A block is the smallest run of leaves that every container range,
at any level, lies either inside or outside of. Leaves stay packed inside a block; the slack
sits at its tail.

# Fields

- `first_leaf::Vector{Int32}`: Block `b` holds leaves `first_leaf[b]:(first_leaf[b + 1] - 1)`,
    so the blocks tile the leaf vector by construction. One entry longer than the rest.
- `offset::Vector{Int32}`: Where `b` starts in `pool.members`.
- `capacity::Vector{Int32}`: Slots reserved for `b`. Outgrowing it relocates the block.
- `of_leaf::Vector{Int32}`: Leaf to block, inverted from `first_leaf` because edits look it up.
- `dirty::Vector{Int32}`, `is_dirty::BitVector`: The repack queue, and its dedup test.
- `dead::Int`: Slots stranded by relocation, reclaimed by the next full repack.
- `slack::Float64`: Headroom as a fraction of block length; 0 means exact fit.
"""
mutable struct PoolBlocks
    first_leaf::Vector{Int32}
    offset::Vector{Int32}
    capacity::Vector{Int32}
    of_leaf::Vector{Int32}
    dirty::Vector{Int32}
    is_dirty::BitVector
    dead::Int
    slack::Float64
end

function PoolBlocks(first_leaf::Vector{Int32}, of_leaf::Vector{Int32}, slack::Float64)
    n = length(first_leaf) - 1
    return PoolBlocks(first_leaf, zeros(Int32, n), zeros(Int32, n), of_leaf,
                      Int32[], falses(n), 0, slack)
end

nblocks(bl::PoolBlocks) = length(bl.first_leaf) - 1

# Block `b`'s leaves; the blocks tile the leaf vector.
@inline leaves_of(bl::PoolBlocks, b::Int) = Int(bl.first_leaf[b]):(Int(bl.first_leaf[b + 1]) - 1)

"""
    ContainerLevel

One container type's settings, and everything a repack needs to find them. `C` is left
unconstrained because `ContainerSetting` is defined in settings.jl, which this file precedes;
in practice it is always a `ContainerSetting`.

# Fields

- `containers::Vector{C}`: Every container of this type, in id order.
- `ranges::Vector{UnitRange{Int}}`: `ranges[i]` is the slice of `pool.leaves` below
    `containers[i]`. A container's leaves are consecutive, so one range covers its subtree.
- `block_ptr::Vector{Int32}`, `block_idx::Vector{Int32}`: CSR from block to containers.
    Block `b` holds `containers[block_idx[block_ptr[b]:(block_ptr[b + 1] - 1)]]`, which is how
    a block-local repack skips every other container at this level.
"""
mutable struct ContainerLevel{C}
    containers::Vector{C}
    ranges::Vector{UnitRange{Int}}
    block_ptr::Vector{Int32}
    block_idx::Vector{Int32}
end

"""
    HierarchicalSettingPool

Backing storage for one setting hierarchy. Holds every member of every leaf, leaves laid out
in DFS order over `contains`, so any container's members form a contiguous range of it - unless
a member sits in two of its leaves, which costs that container contiguity but not the members.
Keeping that layout means repacking after edits; settings no container holds use a
`FlatSettingPool` instead.

# Fields

- `members::Vector{Individual}`: Every member of every leaf, plus block slack and any space
    stranded by a relocation. Only the spans a leaf or container names are meaningful.
- `closed::Int`: How many settings in this hierarchy are currently closed. Zero is the
    common case and lets a repack skip looking for leaves a closure removes.
- `deceased::Int`: Deceased members across its leaves. Zero lets a repack skip narrowing the
    frames.
- `repeats::Int`: Memberships beyond an individual's first within one block. Only a repeated
    member can sit in one container's frame twice, and no container crosses a block, so zero
    skips the duplicate scan.
- `leaves::Vector`: Every leaf in the hierarchy, in the order their members are laid out in
    `members`. A repack walks this to rebuild that layout. Widened to hold a concretely
    typed vector of the pool's one leaf type, which the repack functions reach behind a barrier.
- `container_groups::Tuple`: One `ContainerLevel` per container type, so each level's vectors
    stay concretely typed and a splat over the tuple specialises per level.
- `blocks::PoolBlocks`: The leaves cut into independently repackable blocks.
- `buffer::RepackBuffer` *(internal)*: What a repack on one task and `_count_repeats` work in.
- `task_buffers::Vector{RepackBuffer}` *(internal)*: One per task of a repack on several tasks,
    each created by its task. Empty until the first one.
"""
mutable struct HierarchicalSettingPool
    members::Vector{Individual}
    closed::Int
    deceased::Int
    repeats::Int
    leaves::Vector
    container_groups::Tuple
    blocks::PoolBlocks
    buffer::RepackBuffer
    task_buffers::Vector{RepackBuffer}
end

###
### THE FLAT POOL
###

"""
    FlatSettingPool

Backing storage for the settings of one type that no container holds (`GlobalSetting`,
`Household`, `Municipality`). Each setting owns `cap` slots of `members` starting at its `offset`,
its members in the first `len`, edited in place. Unlike a `HierarchicalSettingPool`, it lays out
no hierarchy, so an edit that fits never waits for a repack.

A removal keeps its slot, so the next addition fills it. A setting that outgrows its slots moves
to the end of the pool with `slack` to spare, stranding the slots it held; `repack_dirty_pools!`
compacts the pool once those make up a third of it.

# Fields

- `members::Vector{Individual}`: Every setting's slots, plus any stranded by a move.
- `dead::Int`: Slots stranded by moves, reclaimed by the next compaction.
- `slack::Float64`: Room a moved setting gets to grow into, as a fraction of its members.
"""
mutable struct FlatSettingPool
    members::Vector{Individual}
    dead::Int
    slack::Float64
end

FlatSettingPool(members::AbstractVector) = FlatSettingPool(convert(Vector{Individual}, members), 0, DEFAULT_POOL_SLACK)
