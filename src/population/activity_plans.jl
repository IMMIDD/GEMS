###
### ACTIVITY PLANS
### An individual's setting memberships, replacing the four setting id fields on `Individual`.
###

# EXPORTS
export PlanEntry, ActivityPlanStore
export member_index, weight, setting_type_of
export plan_entries, plan_length, entry_active, entry_active!, container_frame_index
export build_plans!, assign_settings!, assign_member_indices!, activity_plans, set_primary!
export check_pool_entries
export membership_column, memberships

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
    # one bit per entry: whether it applies this tick. All true until a calendar gates them.
    active::BitVector
    # freed blocks by size, so a resized plan reuses one instead of leaking it
    free::Vector{Vector{Int32}}
    # false until `assign_member_indices!` runs; member indices are meaningless before that
    indexed::Bool
end

ActivityPlanStore() = ActivityPlanStore(PlanEntry[], BitVector(), Vector{Int32}[], false)

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

"""
    entry_active(store::ActivityPlanStore, slot::Int)

Returns whether the entry at `slot` applies this tick.
"""
@inline entry_active(store::ActivityPlanStore, slot::Int)::Bool = @inbounds store.active[slot]

"""
    entry_active!(store::ActivityPlanStore, slot::Int, val::Bool)

Sets whether the entry at `slot` applies this tick.
"""
@inline function entry_active!(store::ActivityPlanStore, slot::Int, val::Bool)
    @inbounds store.active[slot] = val
    return nothing
end

###
### MEMBERSHIP MASK
### One bit per setting type the individual holds at least one entry for. Entries stay sorted by
### type, so while every type appears once a type's rank among the bits is its block offset; a
### repeated type breaks that and the lookups fall back to scanning the block.
###

const MEMBERSHIP_MASK_BITS = 8 * sizeof(fieldtype(Individual, :membership_mask))

@inline _membership_bit(tidx::UInt8) = UInt16(1) << (tidx - 0x01)

"""
    _mask_locates_entries(individual::Individual)

Whether an entry's position can be counted off the mask. False when a type repeats or one sits
beyond the mask, since the bit count then falls short of `plan_count`.

Conservative: counting is still right for types below the repeat, but rejecting the whole block
costs only a scan.
"""
@inline _mask_locates_entries(individual::Individual) =
    count_ones(individual.membership_mask) == individual.plan_count

# A type's entries form one contiguous run, returned block-relative as `(start, len)`. When
# `len` is 0, `start` is where the run would begin, so inserts read it too.
@inline function _plan_type_run(store::ActivityPlanStore, individual::Individual, tidx::UInt8)
    (tidx > MEMBERSHIP_MASK_BITS || !_mask_locates_entries(individual)) &&
        return _plan_type_run_scan(store, individual, tidx)
    mask = individual.membership_mask
    bit = _membership_bit(tidx)
    return (count_ones(mask & (bit - UInt16(1))), mask & bit == 0 ? 0 : 1)
end

function _plan_type_run_scan(store::ActivityPlanStore, individual::Individual, tidx::UInt8)
    off = Int(individual.plan_offset)
    n = Int(individual.plan_count)
    @inbounds for k in 0:(n - 1)
        t = store.entries[off + k].setting_type
        t < tidx && continue
        # types ascend, so a higher one means the run is empty
        t > tidx && return (k, 0)
        j = k + 1
        while j < n && store.entries[off + j].setting_type == tidx
            j += 1
        end
        return (k, j - k)
    end
    return (n, 0)
end

"""
    plan_slot(store::ActivityPlanStore, individual::Individual, ::Type{T}) where {T<:Setting}

Returns the index in `store.entries` of the individual's primary entry of type `T`, or `0`.
A repeated type's entries sit together and the first is the primary: a repeat joins behind it
unless added with `primary = true`, and `set_primary!` moves one to the front.
"""
@inline function plan_slot(store::ActivityPlanStore, individual::Individual, ::Type{T}) where {T<:Setting}
    start, len = _plan_type_run(store, individual, setting_type_index(T))
    return len == 0 ? 0 : Int(individual.plan_offset) + start
end

"""
    plan_slot(store::ActivityPlanStore, individual::Individual, ::Type{T}, sid::Int32) where {T<:Setting}

As above, but for one particular setting rather than any of its type. Searches the whole run,
so a repeated type's later entries are reachable too.
"""
@inline plan_slot(store::ActivityPlanStore, individual::Individual, ::Type{T}, sid::Int32) where {T<:Setting} =
    _entry_slot(store, individual, setting_type_index(T), sid)

# the slot of the entry for setting `sid` of type index `tidx`, or 0
@inline function _entry_slot(store::ActivityPlanStore, individual::Individual, tidx::UInt8, sid::Int32)
    start, len = _plan_type_run(store, individual, tidx)
    off = Int(individual.plan_offset)
    @inbounds for k in start:(start + len - 1)
        store.entries[off + k].setting_id == sid && return off + k
    end
    return 0
end

"""
    plan_slots(store::ActivityPlanStore, individual::Individual, ::Type{T}) where {T<:Setting}

Returns every slot in `store.entries` holding an entry of type `T`, empty when there are none.
"""
@inline function plan_slots(store::ActivityPlanStore, individual::Individual, ::Type{T}) where {T<:Setting}
    start, len = _plan_type_run(store, individual, setting_type_index(T))
    s = Int(individual.plan_offset) + start
    return s:(s + len - 1)
end

###
### CONTAINER FRAME INDEX
###

"""
    container_frame_index(cntnr::SettingsContainer, container::ContainerSetting, leaf::IndividualSetting, leaf_index::Integer)

Returns the position in `container`'s frame of the member at `leaf_index` of `leaf`, or
`DEFAULT_MEMBER_INDEX` when they are not in it. Mirrors the three cases of `present_members`,
so the dropped copy of a member in two leaves has no position here.
"""
function container_frame_index(cntnr::SettingsContainer, container::ContainerSetting,
                               leaf::IndividualSetting, leaf_index::Integer)::Int32
    pool = _pool(container)::SettingPool
    _check_clean(container, pool)
    (is_open(container) && is_open(leaf)) || return DEFAULT_MEMBER_INDEX

    # the member's absolute position in the hierarchy pool
    p = Int(leaf.pool_offset) + Int(leaf_index) - 1

    if pool.closed == 0 || _subtree_open(cntnr, container)
        runs = container.pool_runs
        runs === nothing && return Int32(p - Int(container.pool_offset) + 1)
        k = _run_index(runs.starts, runs.prefix, Int(container.pool_length), p)
        return k == 0 ? DEFAULT_MEMBER_INDEX : Int32(k)
    end

    starts, prefix, total = _open_runs(cntnr, container)
    isempty(starts) && return DEFAULT_MEMBER_INDEX
    k = _run_index(starts, prefix, total, p)
    return k == 0 ? DEFAULT_MEMBER_INDEX : Int32(k)
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
    build_plans!(pop::Population, df::DataFrame, memberships::Union{Nothing, DataFrame} = nothing)

Builds every individual's plan from the membership columns of `df`, which hold each type's
primary, plus one entry per row of the optional `memberships` table (see `memberships`).
"""
function build_plans!(pop::Population, df::DataFrame, memberships::Union{Nothing, DataFrame} = nothing)
    store = ActivityPlanStore()
    pop.activity_plans = store

    cols = propertynames(df)
    types = [T for T in membership_setting_types(Individual) if membership_column(T) in cols]
    # sorted by type index: the order `plan_slot` ranks against
    sort!(types, by = setting_type_index)
    data = Vector{Int32}[Int32.(df[!, membership_column(T)]) for T in types]
    tidx = UInt8[setting_type_index(T) for T in types]
    rows = memberships === nothing ? nothing : _membership_rows(pop, memberships, tidx, data)
    isempty(types) && (rows === nothing || isempty(rows.ind)) && return store

    # each individual's rows together, primary first and otherwise in file order
    order = rows === nothing ? Int[] : sortperm(collect(zip(rows.ind, .!rows.primary)))
    inds = individuals(pop)
    sizehint!(store.entries, length(inds) * length(types) + length(order))

    cursor = 1
    for (i, ind) in enumerate(inds)
        off = length(store.entries) + 1
        mask = UInt16(0)
        for k in eachindex(types)
            sid = @inbounds data[k][i]
            sid == DEFAULT_SETTING_ID && continue
            push!(store.entries, PlanEntry(sid, DEFAULT_MEMBER_INDEX, Float16(1.0), tidx[k]))
            tidx[k] <= MEMBERSHIP_MASK_BITS && (mask |= _membership_bit(tidx[k]))
        end

        # the individual's table rows follow its population-row entries
        from_table = false
        while cursor <= length(order) && rows.ind[order[cursor]] == i
            r = order[cursor]
            push!(store.entries, PlanEntry(rows.sid[r], DEFAULT_MEMBER_INDEX, Float16(1.0), rows.tidx[r]))
            rows.tidx[r] <= MEMBERSHIP_MASK_BITS && (mask |= _membership_bit(rows.tidx[r]))
            cursor += 1
            from_table = true
        end

        n = length(store.entries) - off + 1
        if from_table
            n <= typemax(Int8) || throw(ArgumentError(
                "individual $(id(ind)) would hold $n plan entries; the cap is $(typemax(Int8))"))
            block = view(store.entries, off:(off + n - 1))
            # stable, so each type keeps its primary first and the rest in file order
            sort!(block; alg = InsertionSort, by = setting_type_of)
            _check_repeated_entries(block, ind)
        end
        ind.plan_offset = Int32(n == 0 ? 0 : off)
        ind.plan_count = Int8(n)
        ind.membership_mask = mask
    end

    # nothing gates entries yet, so every one applies
    resize!(store.active, length(store.entries))
    fill!(store.active, true)
    return store
end

# Resolves the membership table to per-row (individual index, type index, setting id, primary),
# erroring on the first row that names an unknown individual or type, or breaks the primary rule.
function _membership_rows(pop::Population, table::DataFrame, wide_tidx::Vector{UInt8}, wide::Vector{Vector{Int32}})
    for c in (:id, :setting_type, :setting_id)
        c in propertynames(table) || throw(ArgumentError("the membership table has no `$c` column"))
    end
    n = nrow(table)
    ind = Vector{Int}(undef, n)
    tidx = Vector{UInt8}(undef, n)
    sid = Vector{Int32}(undef, n)
    primary = :primary in propertynames(table) ? BitVector(Bool.(table.primary)) : falses(n)
    allowed = membership_setting_types(Individual)
    resolved = Dict{String, UInt8}()
    primaries = Set{Tuple{Int, UInt8}}()

    for r in 1:n
        pid = table.id[r]
        k = Int(pid) - Int(pop.minid) + 1
        (1 <= k <= length(pop.id_map) && pop.id_map[k] > 0) || throw(ArgumentError(
            "membership row $r names individual $pid, who is not in the population"))
        ind[r] = Int(pop.id_map[k])

        name = string(table.setting_type[r])
        tidx[r] = get!(resolved, name) do
            T = _setting_type_by_name(name)
            T === nothing && throw(ArgumentError(
                "membership row $r names setting type \"$name\", which is not registered"))
            T in allowed || throw(ArgumentError(
                "membership row $r names $T; membership tables carry $(join(allowed, ", ")) for now"))
            setting_type_index(T)
        end

        s = Int32(table.setting_id[r])
        s > 0 || throw(ArgumentError("membership row $r has setting id $s; ids start at 1"))
        sid[r] = s

        primary[r] || continue
        w = findfirst(==(tidx[r]), wide_tidx)
        (w === nothing || wide[w][ind[r]] == DEFAULT_SETTING_ID) || throw(ArgumentError(
            "membership row $r makes $name $s the primary of individual $pid, whose population row already names one"))
        (ind[r], tidx[r]) in primaries && throw(ArgumentError(
            "membership row $r is a second primary $name for individual $pid"))
        push!(primaries, (ind[r], tidx[r]))
    end
    return (ind = ind, tidx = tidx, sid = sid, primary = primary)
end

# A setting named twice would put the individual in its member list twice.
function _check_repeated_entries(block, ind::Individual)
    for a in eachindex(block), b in (a + 1):lastindex(block)
        x = block[a]
        y = block[b]
        (setting_type_of(x) == setting_type_of(y) && setting_id(x) == setting_id(y)) || continue
        throw(ArgumentError(
            "individual $(id(ind)) is given $(setting_type_from_index(setting_type_of(x))) $(setting_id(x)) twice"))
    end
    return nothing
end

"""
    memberships(pop::Population)

Returns the memberships `dataframe(pop)` leaves out, one row per plan entry: `id`,
`setting_type` (the type's name) and `setting_id`, in individual then plan order. That is every
entry after the first of its type, and every entry of a type without a membership column.
Loading both tables back rebuilds the same plans.
"""
function memberships(pop::Population)
    plans = activity_plans(pop)
    wide = map(setting_type_index, membership_setting_types(Individual))
    ids = Int32[]
    types = String[]
    sids = Int32[]
    for ind in individuals(pop)
        prev = 0x00
        for e in plan_entries(plans, ind)
            t = setting_type_of(e)
            if t == prev || !(t in wide)
                push!(ids, id(ind))
                push!(types, string(nameof(setting_type_from_index(t))))
                push!(sids, setting_id(e))
            end
            prev = t
        end
    end
    return DataFrame(id = ids, setting_type = types, setting_id = sids)
end

"""
    assign_settings!(pop::Population, individual::Individual, memberships::Pair...; primary::Bool = false)

Gives `individual` one plan entry per `setting type => setting id` pair, as a population
file's membership columns would, each as the primary of its type if `primary`. Only before
the settings are built; afterwards use `add_member!`, which edits the setting too.
"""
function assign_settings!(pop::Population, individual::Individual, memberships::Pair...; primary::Bool = false)
    plans = activity_plans(pop)
    # once indexed, an entry with no matching setting member would go unnoticed
    plans.indexed && throw(ArgumentError(
        "the settings are already built; use `add_member!`, which also edits the setting"))
    for (T, sid) in memberships
        plan_add!(plans, individual, PlanEntry(T, Int32(sid), DEFAULT_MEMBER_INDEX); primary = primary)
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
    check_pool_entries(pop::Population, cntnr::SettingsContainer)

Errors unless every member of every pooled leaf holds a plan entry for it.
"""
function check_pool_entries(pop::Population, cntnr::SettingsContainer)
    plans = activity_plans(pop)
    for T in keys(cntnr.pools)
        _check_member_entries(plans, cntnr, T)
    end
    return true
end

# function barrier: with `T` static, `settings(cntnr, T)` is a typed vector
function _check_member_entries(plans::ActivityPlanStore, cntnr::SettingsContainer,
                               ::Type{T}) where {T<:IndividualSetting}
    for s in settings(cntnr, T), ind in individuals(s)
        plan_slot(plans, ind, T, id(s)) != 0 ||
            error("individual $(id(ind)) is a member of $T $(id(s)) but holds no plan entry " *
                  "for it; membership edits read the plan store, so it has to cover every member")
    end
    return nothing
end

###
### MEMBER EDITS
###

"""
    plan_add!(store::ActivityPlanStore, individual::Individual, entry::PlanEntry; primary::Bool = false)

Inserts an entry, keeping the individual's block sorted by setting type. A repeated type joins
behind its kind, or in front of it as the new primary if `primary`. Throws if the individual
already holds an entry for that setting.
"""
function plan_add!(store::ActivityPlanStore, individual::Individual, entry::PlanEntry; primary::Bool = false)
    tidx = setting_type_of(entry)
    # a second entry for one setting would put the individual in its member list twice
    _entry_slot(store, individual, tidx, setting_id(entry)) == 0 || throw(ArgumentError(
        "individual $(id(individual)) already holds an entry for $(setting_type_from_index(tidx)) $(setting_id(entry))"))
    n = Int(individual.plan_count)
    n < typemax(Int8) || throw(ArgumentError(
        "individual $(id(individual)) already holds $n plan entries; the cap is $(typemax(Int8))"))

    start, len = _plan_type_run(store, individual, tidx)
    pos = primary ? start : start + len
    old = Int(individual.plan_offset)
    new = _alloc_block!(store, n + 1)

    @inbounds for k in 0:(pos - 1)
        store.entries[new + k] = store.entries[old + k]
        store.active[new + k] = store.active[old + k]
    end
    @inbounds store.entries[new + pos] = entry
    @inbounds store.active[new + pos] = true
    @inbounds for k in pos:(n - 1)
        store.entries[new + k + 1] = store.entries[old + k]
        store.active[new + k + 1] = store.active[old + k]
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
            store.active[new + k] = store.active[old + k]
        end
        @inbounds for k in (pos + 1):(n - 1)
            store.entries[new + k - 1] = store.entries[old + k]
            store.active[new + k - 1] = store.active[old + k]
        end
        _free_block!(store, old, n)
        individual.plan_offset = Int32(new)
    end

    individual.plan_count = Int8(n - 1)
    # the bit means "holds at least one of this type", so it only clears once the last one goes
    # the mask still describes the pre-removal block, so scan rather than trust it
    if tidx <= MEMBERSHIP_MASK_BITS && _plan_type_run_scan(store, individual, tidx)[2] == 0
        individual.membership_mask &= ~_membership_bit(tidx)
    end
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

"""
    set_primary!(store::ActivityPlanStore, individual::Individual, ::Type{T}, sid::Integer) where {T<:Setting}

Makes setting `sid` the individual's primary setting of type `T` by moving its entry to the
front of its kind. Member indices and active flags travel with their entries; no setting's
member list changes.
"""
function set_primary!(store::ActivityPlanStore, individual::Individual, ::Type{T}, sid::Integer) where {T<:Setting}
    slot = plan_slot(store, individual, T, Int32(sid))
    slot == 0 && throw(ArgumentError("individual $(id(individual)) holds no entry for $T $sid"))
    front = plan_slot(store, individual, T)
    e = @inbounds store.entries[slot]
    a = @inbounds store.active[slot]
    # the entries ahead of it move back by one, so the rest keep their order
    @inbounds for k in slot:-1:(front + 1)
        store.entries[k] = store.entries[k - 1]
        store.active[k] = store.active[k - 1]
    end
    @inbounds store.entries[front] = e
    @inbounds store.active[front] = a
    return nothing
end

"""
    set_primary!(pop::Population, individual::Individual, ::Type{T}, sid::Integer) where {T<:Setting}

Convenience for callers holding a `Population` rather than the store.
"""
set_primary!(pop::Population, individual::Individual, ::Type{T}, sid::Integer) where {T<:Setting} =
    set_primary!(activity_plans(pop), individual, T, sid)

# takes a block of `n` entries, reusing a freed one if available
function _alloc_block!(store::ActivityPlanStore, n::Int)
    if n <= length(store.free) && !isempty(store.free[n])
        return Int(pop!(store.free[n]))
    end
    off = length(store.entries) + 1
    resize!(store.entries, off + n - 1)
    resize!(store.active, off + n - 1)
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
