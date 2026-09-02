###
### ACTIVITY PLANS
### An individual's setting memberships, replacing the four setting id fields on `Individual`.
###

# EXPORTS
export PlanEntry, ActivityPlanStore
export member_index, weight, setting_type_of
export plan_entries, plan_length, container_frame_index
export build_plans!, assign_settings!, assign_member_indices!, activity_plans, validate_plans
export membership_column

###
### PLAN ENTRY
###

"""
    PlanEntry

One setting membership: the setting's id and dense type index, the individual's position in
that setting's member frame, and the share of the day spent there.
"""
struct PlanEntry
    setting_id::Int32
    member_index::Int32
    weight::Float16
    setting_type::UInt8
end

"""
    PlanEntry(::Type{T}, setting_id, member_index, weight = 1.0f0)

Builds an entry for a setting of type `T`, resolving the dense type index.
"""
PlanEntry(::Type{T}, setting_id::Integer, member_index::Integer, weight::Real = 1.0f0) where {T<:Setting} =
    PlanEntry(Int32(setting_id), Int32(member_index), Float16(weight), setting_type_index(T))

"""
    setting_id(entry::PlanEntry)

Returns the id of the setting this entry refers to.
"""
@inline setting_id(entry::PlanEntry)::Int32 = entry.setting_id

"""
    member_index(entry::PlanEntry)

Returns the individual's position in the setting's member frame.
"""
@inline member_index(entry::PlanEntry)::Int32 = entry.member_index

"""
    weight(entry::PlanEntry)

Returns the entry's share of the individual's day.
"""
@inline weight(entry::PlanEntry)::Float16 = entry.weight

"""
    setting_type_of(entry::PlanEntry)

Returns the entry's dense setting-type index.
"""
@inline setting_type_of(entry::PlanEntry)::UInt8 = entry.setting_type

# entries are immutable, so an edit rewrites the whole entry
@inline _with_member_index(e::PlanEntry, idx::Integer) =
    PlanEntry(e.setting_id, Int32(idx), e.weight, e.setting_type)
@inline _with_setting_id(e::PlanEntry, sid::Int32) =
    PlanEntry(sid, e.member_index, e.weight, e.setting_type)

###
### PLAN STORE
###

"""
    ActivityPlanStore <: AbstractActivityPlanStore

Every individual's plan entries in one flat vector. An individual's entries are the block
`entries[plan_offset : plan_offset + plan_count - 1]`, both coordinates held on the `Individual`.
"""
mutable struct ActivityPlanStore <: AbstractActivityPlanStore
    entries::Vector{PlanEntry}
    # freed blocks by size, so a resized plan reuses one instead of leaking it
    free::Vector{Vector{Int32}}
    # false until `assign_member_indices!` runs; member indices are meaningless before that
    indexed::Bool
end

ActivityPlanStore() = ActivityPlanStore(PlanEntry[], Vector{Int32}[], false)

Base.length(store::ActivityPlanStore) = length(store.entries)
Base.isempty(store::ActivityPlanStore) = isempty(store.entries)

"""
    activity_plans(pop::Population)

Returns the population's `ActivityPlanStore`.
"""
function activity_plans(pop::Population)
    # narrow the abstractly-typed field for type-stable access
    return pop.activity_plans::ActivityPlanStore
end

# member indices are meaningless before the settings exist, so refuse rather than return a sentinel
@inline function _check_indexed(store::ActivityPlanStore)
    store.indexed || error(
        "activity plans carry no member indices yet. Call `assign_member_indices!` after the " *
        "settings are built and pooled.")
    return nothing
end

"""
    plan_entries(store::ActivityPlanStore, individual::Individual)

Returns the individual's plan as a view into the store, which writing to would edit.
"""
@inline function plan_entries(store::ActivityPlanStore, individual::Individual)
    n = Int(individual.plan_count)
    n == 0 && return view(store.entries, 1:0)
    off = Int(individual.plan_offset)
    return view(store.entries, off:(off + n - 1))
end

"""
    plan_length(individual::Individual)

Returns how many settings the individual belongs to.
"""
@inline plan_length(individual::Individual)::Int = Int(individual.plan_count)

###
### MEMBERSHIP MASK
### Entries are sorted by setting type, so a type's rank among the mask bits is its block offset.
###

const MEMBERSHIP_MASK_BITS = 8 * sizeof(fieldtype(Individual, :membership_mask))

@inline _membership_bit(tidx::UInt8) = UInt16(1) << (tidx - 0x01)

"""
    plan_slot(store::ActivityPlanStore, individual::Individual, ::Type{T}) where {T<:Setting}

Returns the index in `store.entries` of the individual's entry for a setting of type `T`, or `0`.
"""
@inline function plan_slot(store::ActivityPlanStore, individual::Individual, ::Type{T}) where {T<:Setting}
    tidx = setting_type_index(T)
    tidx > MEMBERSHIP_MASK_BITS && return _plan_slot_scan(store, individual, tidx)
    bit = _membership_bit(tidx)
    mask = individual.membership_mask
    mask & bit == 0 && return 0
    return Int(individual.plan_offset) + count_ones(mask & (bit - UInt16(1)))
end

"""
    plan_slot(store::ActivityPlanStore, individual::Individual, ::Type{T}, sid::Int32) where {T<:Setting}

As above, but for one particular setting rather than any of its type.
"""
@inline function plan_slot(store::ActivityPlanStore, individual::Individual, ::Type{T}, sid::Int32) where {T<:Setting}
    slot = plan_slot(store, individual, T)
    slot == 0 && return 0
    return @inbounds store.entries[slot].setting_id == sid ? slot : 0
end

# fallback for setting types beyond the mask width
function _plan_slot_scan(store::ActivityPlanStore, individual::Individual, tidx::UInt8)
    off = Int(individual.plan_offset)
    @inbounds for k in 0:(Int(individual.plan_count) - 1)
        store.entries[off + k].setting_type == tidx && return off + k
    end
    return 0
end

# position an entry of type `tidx` takes in the block
@inline function _insert_position(individual::Individual, tidx::UInt8)
    tidx > MEMBERSHIP_MASK_BITS && return Int(individual.plan_count)
    return count_ones(individual.membership_mask & (_membership_bit(tidx) - UInt16(1)))
end

###
### CONTAINER FRAME INDEX
###

"""
    container_frame_index(cntnr::SettingsContainer, container::ContainerSetting, leaf::IndividualSetting, leaf_index::Integer)

Returns the position in `container`'s frame of the member at `leaf_index` of `leaf`, or
`DEFAULT_MEMBER_INDEX` when they are not in it. Mirrors the three cases of `present_members`.
"""
function container_frame_index(cntnr::SettingsContainer, container::ContainerSetting,
                               leaf::IndividualSetting, leaf_index::Integer)::Int32
    pool = _pool(container)::SettingPool
    _check_clean(container, pool)
    (is_open(container) && is_open(leaf)) || return DEFAULT_MEMBER_INDEX

    # the member's absolute position in the hierarchy pool
    p = Int(leaf.pool_offset) + Int(leaf_index) - 1

    if pool.closed == 0 || _subtree_open(cntnr, container)
        return Int32(p - Int(container.pool_offset) + 1)
    end

    starts = Int32[]
    prefix = Int32[]
    total = _collect_runs!(starts, prefix, 0, cntnr, container)
    isempty(starts) && return DEFAULT_MEMBER_INDEX

    # one run is contiguous again, but based at `starts[1]`, not at `container.pool_offset`
    length(starts) == 1 && return Int32(p - Int(starts[1]) + 1)

    r = searchsortedlast(starts, Int32(p))
    r == 0 && return DEFAULT_MEMBER_INDEX
    run_len = (r < length(prefix) ? Int(prefix[r + 1]) : total) - Int(prefix[r])
    (p - Int(starts[r])) < run_len || return DEFAULT_MEMBER_INDEX
    return Int32(p - Int(starts[r]) + Int(prefix[r]) + 1)
end

###
### CONSTRUCTION
###

"""
    membership_column(::Type{T}) where {T<:Setting}

The population-file column carrying membership of a setting of type `T`.
"""
membership_column(::Type{Household}) = :household
membership_column(::Type{Office}) = :office
membership_column(::Type{SchoolClass}) = :schoolclass
membership_column(::Type{Municipality}) = :municipality

"""
    build_plans!(pop::Population, df::DataFrame)

Builds every individual's plan from the membership columns of `df`.
"""
function build_plans!(pop::Population, df::DataFrame)
    store = ActivityPlanStore()
    pop.activity_plans = store

    cols = propertynames(df)
    types = [T for T in membership_setting_types(Individual) if membership_column(T) in cols]
    # sorted by type index: the order `plan_slot` ranks against
    sort!(types, by = setting_type_index)
    isempty(types) && return store

    data = [Int32.(df[!, membership_column(T)]) for T in types]
    tidx = [setting_type_index(T) for T in types]
    inds = individuals(pop)
    sizehint!(store.entries, length(inds) * length(types))

    for (i, ind) in enumerate(inds)
        off = length(store.entries) + 1
        n = 0
        mask = UInt16(0)
        for k in eachindex(types)
            sid = @inbounds data[k][i]
            sid == DEFAULT_SETTING_ID && continue
            push!(store.entries, PlanEntry(sid, DEFAULT_MEMBER_INDEX, Float16(1.0), tidx[k]))
            tidx[k] <= MEMBERSHIP_MASK_BITS && (mask |= _membership_bit(tidx[k]))
            n += 1
        end
        ind.plan_offset = Int32(n == 0 ? 0 : off)
        ind.plan_count = Int8(n)
        ind.membership_mask = mask
    end
    return store
end

"""
    assign_settings!(pop::Population, individual::Individual, memberships::Pair...)

Gives `individual` one plan entry per `setting type => setting id` pair, as a population
file's membership columns would.
"""
function assign_settings!(pop::Population, individual::Individual, memberships::Pair...)
    plans = activity_plans(pop)
    for (T, sid) in memberships
        plan_add!(plans, individual, PlanEntry(T, Int32(sid), DEFAULT_MEMBER_INDEX))
    end
    return pop
end

"""
    assign_member_indices!(pop::Population, cntnr::SettingsContainer)

Fills in each entry's `member_index` from the finished settings. Must run after `build_pools!`.
"""
function assign_member_indices!(pop::Population, cntnr::SettingsContainer)
    plans = activity_plans(pop)
    for T in settingtypes(cntnr)
        # GlobalSetting holds everyone, so nobody carries an entry for it
        (T <: IndividualSetting && T !== GlobalSetting) && _assign_member_indices!(plans, cntnr, T)
    end
    plans.indexed = true
    return plans
end

# function barrier: with `T` static, `settings(cntnr, T)` is a typed vector
function _assign_member_indices!(plans::ActivityPlanStore, cntnr::SettingsContainer,
                                 ::Type{T}) where {T<:IndividualSetting}
    for s in settings(cntnr, T)
        sid = id(s)
        members = individuals(s)
        for k in eachindex(members)
            slot = plan_slot(plans, members[k], T, sid)
            slot != 0 && plan_set_member_index!(plans, slot, k)
        end
    end
    return nothing
end

###
### VALIDATION
###

"""
    validate_plans(pop::Population, cntnr::SettingsContainer)

Errors unless every entry indexes back to its own individual, and every setting member holds
a matching entry.
"""
function validate_plans(pop::Population, cntnr::SettingsContainer)
    plans = activity_plans(pop)
    _check_indexed(plans)

    for ind in individuals(pop), e in plan_entries(plans, ind)
        T = setting_type_from_index(setting_type_of(e))
        s = settings(cntnr, T)[setting_id(e)]
        idx = member_index(e)
        1 <= idx <= length(individuals(s)) ||
            error("individual $(id(ind)) has member index $idx in $T $(setting_id(e)), which holds $(length(individuals(s))) members")
        individuals(s)[idx] === ind ||
            error("individual $(id(ind)) has member index $idx in $T $(setting_id(e)), but that slot holds individual $(id(individuals(s)[idx]))")
    end

    for T in settingtypes(cntnr)
        (T <: IndividualSetting && T !== GlobalSetting) || continue
        for s in settings(cntnr, T), ind in individuals(s)
            plan_slot(plans, ind, T, id(s)) != 0 ||
                error("individual $(id(ind)) is a member of $T $(id(s)) but holds no plan entry for it")
        end
    end
    return true
end

###
### MEMBER EDITS
###

"""
    plan_add!(store::ActivityPlanStore, individual::Individual, entry::PlanEntry)

Inserts an entry, keeping the individual's block sorted by setting type.
"""
function plan_add!(store::ActivityPlanStore, individual::Individual, entry::PlanEntry)
    tidx = setting_type_of(entry)
    n = Int(individual.plan_count)
    n < typemax(Int8) || throw(ArgumentError(
        "individual $(id(individual)) already holds $n plan entries; the cap is $(typemax(Int8))"))

    pos = _insert_position(individual, tidx)
    old = Int(individual.plan_offset)
    new = _alloc_block!(store, n + 1)

    @inbounds for k in 0:(pos - 1)
        store.entries[new + k] = store.entries[old + k]
    end
    @inbounds store.entries[new + pos] = entry
    @inbounds for k in pos:(n - 1)
        store.entries[new + k + 1] = store.entries[old + k]
    end

    _free_block!(store, old, n)
    individual.plan_offset = Int32(new)
    individual.plan_count = Int8(n + 1)
    tidx <= MEMBERSHIP_MASK_BITS && (individual.membership_mask |= _membership_bit(tidx))
    return nothing
end

"""
    plan_remove!(store::ActivityPlanStore, individual::Individual, slot::Int)

Drops the entry at `slot`, closing the gap so the block stays sorted by setting type.
"""
function plan_remove!(store::ActivityPlanStore, individual::Individual, slot::Int)
    old = Int(individual.plan_offset)
    n = Int(individual.plan_count)
    (n > 0 && old <= slot <= old + n - 1) || return false

    tidx = @inbounds setting_type_of(store.entries[slot])
    pos = slot - old

    if n == 1
        _free_block!(store, old, 1)
        individual.plan_offset = Int32(0)
    else
        new = _alloc_block!(store, n - 1)
        @inbounds for k in 0:(pos - 1)
            store.entries[new + k] = store.entries[old + k]
        end
        @inbounds for k in (pos + 1):(n - 1)
            store.entries[new + k - 1] = store.entries[old + k]
        end
        _free_block!(store, old, n)
        individual.plan_offset = Int32(new)
    end

    individual.plan_count = Int8(n - 1)
    tidx <= MEMBERSHIP_MASK_BITS && (individual.membership_mask &= ~_membership_bit(tidx))
    return true
end

"""
    plan_set_member_index!(store::ActivityPlanStore, slot::Int, idx::Integer)

Repoints one entry at a new position in its setting's member list.
"""
@inline function plan_set_member_index!(store::ActivityPlanStore, slot::Int, idx::Integer)
    @inbounds store.entries[slot] = _with_member_index(store.entries[slot], idx)
    return nothing
end

"""
    plan_set_setting_id!(store::ActivityPlanStore, slot::Int, sid::Int32)

Repoints one entry at a renumbered setting.
"""
@inline function plan_set_setting_id!(store::ActivityPlanStore, slot::Int, sid::Int32)
    @inbounds store.entries[slot] = _with_setting_id(store.entries[slot], sid)
    return nothing
end

# takes a block of `n` entries, reusing a freed one if available
function _alloc_block!(store::ActivityPlanStore, n::Int)
    if n <= length(store.free) && !isempty(store.free[n])
        return Int(pop!(store.free[n]))
    end
    off = length(store.entries) + 1
    resize!(store.entries, off + n - 1)
    return off
end

function _free_block!(store::ActivityPlanStore, off::Int, n::Int)
    n == 0 && return nothing
    n > length(store.free) && _grow_free!(store, n)
    push!(store.free[n], Int32(off))
    return nothing
end

function _grow_free!(store::ActivityPlanStore, n::Int)
    old = length(store.free)
    resize!(store.free, n)
    for k in (old + 1):n
        store.free[k] = Int32[]
    end
    return nothing
end
