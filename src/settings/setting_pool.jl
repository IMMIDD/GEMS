###
### SETTING POOL (TYPE DEFINITIONS)
###

###
### MEMBER STORAGE
###

# A contiguous view into a `SettingPool`'s member vector.
const MemberSlice = SubArray{Individual, 1, Vector{Individual}, Tuple{UnitRange{Int64}}, true}

# What an `individuals` field may hold. A setting outside a hierarchy owns its members
# outright; one inside a pooled hierarchy holds a slice of that pool, so its members are not
# duplicated and its containers can address them as a range. Both alternatives are concrete,
# so reading the field splits a two-way union rather than dispatching dynamically.
const MemberStorage = Union{Vector{Individual}, MemberSlice}

###
### MEMBER VIEWS
###

"""
    MemberRuns

A container's frame when a member sits in two of its leaves at once. The frame skips the repeat
positions instead of being one span, and `groups` records which positions those were, so a
closure below can be answered from the same data.

# Fields

- `starts::Vector{Int32}`, `prefix::Vector{Int32}`: The runs, in the encoding `MemberView`
    indexes with.
- `groups::Vector{Int32}`: The pool positions of each repeated member, one group after another,
    ascending within a group.
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
described by `offset` and `len`. A container with closed descendants or with a member in two of
its leaves needs several runs, and then `starts`/`prefix` describe them and indexing
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

Repack scratch for spotting a member that sits in two leaves of one container. Open addressing
keyed on member id.

# Fields

- `keys::Vector{Int32}`: The member id in that slot, meaningful only while `gen` matches.
- `pos::Vector{Int32}`: The first pool position that member was seen at.
- `gen::Vector{Int32}`: The `epoch` that last claimed the slot; anything else means free.
- `epoch::Int32`: Bumped per container scanned.
"""
mutable struct DupTable
    keys::Vector{Int32}
    pos::Vector{Int32}
    gen::Vector{Int32}
    epoch::Int32
end

DupTable() = DupTable(Int32[], Int32[], Int32[], Int32(0))

"""
    SettingPool

Backing storage for one setting hierarchy. Holds every member of every leaf, leaves laid out
in DFS order over `contains`, so any container's members form a contiguous range of it - unless
a member sits in two of its leaves, which costs that container contiguity but not the members.

# Fields

- `members::Vector{Individual}`: Every member of every leaf in the hierarchy.
- `closed::Int`: How many settings in this hierarchy are currently closed. Zero is the
    common case and lets a container hand over its range without any walk.
- `dirty::Bool`: Set by a member edit and cleared by `repack_dirty_pools!`. While set, every
    offset and length in the hierarchy is stale, so `present_members` refuses to read it.
- `leaves::Vector`: Every leaf in the hierarchy, in the order their members are laid out in
    `members`. A repack walks this to rebuild that layout. Widened to hold a concretely
    typed vector of the pool's one leaf type, which `_repack!` reaches behind a barrier.
- `container_groups::Tuple`: One `(containers, ranges)` pair per container type, so each
    vector is concretely typed. `ranges[i]` is the slice of `leaves` below `containers[i]`;
    a container's leaves are consecutive, so one range covers its whole subtree.
- `dup_table::DupTable` *(internal)*: Repack scratch for finding a member that sits in two
    leaves of one container. Sized once per repack and reused by every container of every level.
"""
mutable struct SettingPool
    members::Vector{Individual}
    # how many settings in this hierarchy are currently closed
    closed::Int
    # set by a member edit, cleared by the repack that follows it
    dirty::Bool
    # everything a repack needs, so a member edit does not have to find the hierarchy again
    leaves::Vector # widened: holds a Vector{SchoolClass} / Vector{Office}
    # one (containers, ranges) pair per container type, so each vector is concretely typed
    container_groups::Tuple
    # repack scratch for duplicate detection, reused by every container of every level
    dup_table::DupTable
end
