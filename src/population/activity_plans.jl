###
### ACTIVITY PLANS
### An individual's setting memberships, replacing the four setting id fields on `Individual`.
###

# EXPORTS
export PlanEntry, ActivityPlanStore
export member_index, entry_scale, setting_type_of
export plan_entries, plan_length, entry_active, entry_active!, container_frame_index
export build_plans!, assign_settings!, assign_member_indices!, activity_plans, set_primary!, set_scale!
export check_pool_entries
export membership_column, memberships

###
### PLAN ENTRY
###

"""
    PlanEntry

One setting membership: the setting's id and dense type index, the individual's position in
that setting's member frame, and the scale of its contacts there.
"""
struct PlanEntry
    setting_id::Int32
    member_index::Int32
    scale::Float16
    setting_type::UInt8
end

"""
    PlanEntry(::Type{T}, setting_id, member_index, scale = 1.0f0)

Builds an entry for a setting of type `T`, resolving the dense type index and registering a
custom type on first use.
"""
PlanEntry(::Type{T}, setting_id::Integer, member_index::Integer, scale::Real = 1.0f0) where {T<:Setting} =
    PlanEntry(Int32(setting_id), Int32(member_index), Float16(scale), register_setting_type!(T))

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
    entry_scale(entry::PlanEntry)

Returns the scale of the individual's contacts in the entry's setting, relative to a normal member.
"""
@inline entry_scale(entry::PlanEntry)::Float16 = entry.scale

"""
    setting_type_of(entry::PlanEntry)

Returns the entry's dense setting-type index.
"""
@inline setting_type_of(entry::PlanEntry)::UInt8 = entry.setting_type

# entries are immutable, so an edit rewrites the whole entry
@inline _with_member_index(e::PlanEntry, idx::Integer) =
    PlanEntry(e.setting_id, Int32(idx), e.scale, e.setting_type)
@inline _with_setting_id(e::PlanEntry, sid::Int32) =
    PlanEntry(sid, e.member_index, e.scale, e.setting_type)
@inline _with_scale(e::PlanEntry, scale::Real) =
    PlanEntry(e.setting_id, e.member_index, Float16(scale), e.setting_type)

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
    # per setting type index, at least 1 and every scale an entry of that type holds
    scale_bounds::Vector{Float32}
end

ActivityPlanStore() = ActivityPlanStore(PlanEntry[], BitVector(), Vector{Int32}[], false, Float32[])

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

# member indices are meaningless before the settings exist
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
@inline plan_entries(store::ActivityPlanStore, individual::Individual) = view(store.entries, plan_slots(store, individual))

"""
    plan_length(individual::Individual)

Returns how many settings the individual belongs to.
"""
@inline plan_length(individual::Individual)::Int = Int(individual.plan_count)

"""
    entry_active(store::ActivityPlanStore, slot::Int)

Returns whether the entry at `slot` applies this tick. One that does not counts as scale 0 on
both ends of a contact: its individual draws no contacts in that setting, and contacts drawn to
them there are rejected. They keep their place among the setting's members, so a draw can still
land on them.
"""
@inline entry_active(store::ActivityPlanStore, slot::Int)::Bool = @inbounds store.active[slot]

"""
    entry_active!(store::ActivityPlanStore, individual::Individual, slot::Int, val::Bool)

Sets whether the entry at `slot`, which must be one of `individual`'s, applies this tick.
"""
function entry_active!(store::ActivityPlanStore, individual::Individual, slot::Int, val::Bool)
    off = Int(individual.plan_offset)
    off <= slot < off + plan_length(individual) || throw(ArgumentError(
        "slot $slot does not hold one of individual $(id(individual))'s plan entries"))
    @inbounds store.active[slot] = val
    # an inactive entry has scale 0, which the unscaled fast path must not skip
    _refresh_plan_scaled!(store, individual)
    return nothing
end

# The entry's scale this tick: its own while it applies, 0 while it does not. Float32, as Float16
# arithmetic is emulated in software.
@inline _effective_scale(store::ActivityPlanStore, slot::Int)::Float32 =
    entry_active(store, slot) ? Float32(entry_scale(@inbounds store.entries[slot])) : 0.0f0

# Raises the scale bound of setting type index `t` to `scale`; nothing lowers one. Serial only, as
# it may append.
@inline function _raise_scale_bound!(store::ActivityPlanStore, t::UInt8, scale::Float32)
    b = store.scale_bounds
    length(b) < t && append!(b, fill(1.0f0, Int(t) - length(b)))
    @inbounds b[t] = max(b[t], scale)
    return nothing
end

@inline _raise_scale_bound!(store::ActivityPlanStore, entry::PlanEntry) =
    _raise_scale_bound!(store, setting_type_of(entry), Float32(entry_scale(entry)))

# The largest scale any entry of setting type index `t` holds, at least 1.
@inline _type_scale_bound(store::ActivityPlanStore, t::UInt8)::Float32 =
    Int(t) <= length(store.scale_bounds) ? @inbounds(store.scale_bounds[t]) : 1.0f0

###
### MEMBERSHIP MASK
### One bit per setting type the individual holds at least one entry for, at the type's mask slot
### (`_mask_slot`). Entries stay sorted by type, so while every type appears once a type's rank
### among the bits is its block offset; a repeated type breaks that and the lookups fall back to
### scanning the block.
###

@inline _membership_bit(tidx::UInt8) = UInt16(1) << (_mask_slot(tidx) - 0x01)

"""
    _mask_locates_entries(individual::Individual)

Whether an entry's position can be counted off the mask. False when a type repeats or one has no
mask slot, since the bit count then falls short of `plan_count`.

Conservative: counting is still right for types below the repeat, but rejecting the whole block
costs only a scan.
"""
@inline _mask_locates_entries(individual::Individual) =
    count_ones(individual.membership_mask) == individual.plan_count

# A type's entries form one contiguous run, returned block-relative as `(start, len)`. When
# `len` is 0, `start` is where the run would begin, so inserts read it too.
@inline function _plan_type_run(store::ActivityPlanStore, individual::Individual, tidx::UInt8)
    (_mask_slot(tidx) == 0 || !_mask_locates_entries(individual)) &&
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

"""
    plan_slots(store::ActivityPlanStore, individual::Individual)

Returns every slot in `store.entries` holding one of the individual's entries, empty when there are none.
"""
@inline function plan_slots(::ActivityPlanStore, individual::Individual)
    off = Int(individual.plan_offset)
    return off:(off + plan_length(individual) - 1)
end

# Calls `use` with the entry's setting as its concrete type.
@inline _with_entry_setting(use::U, cntnr::SettingsContainer, e::PlanEntry) where {U} =
    _with_entry_settings(v -> use(v[setting_id(e)]), cntnr, e)

# Calls `use` with the settings of the entry's type as a concretely typed vector, found by unrolling
# over the membership types so each comparison is against a constant index.
@inline _with_entry_settings(use::U, cntnr::SettingsContainer, e::PlanEntry) where {U} =
    _unroll_entry_settings(use, cntnr, e, membership_setting_types(Individual)...)

@inline function _unroll_entry_settings(use::U, cntnr::SettingsContainer, e::PlanEntry, ::Type{T}, rest...) where {U, T<:IndividualSetting}
    setting_type_of(e) == setting_type_index(T) || return _unroll_entry_settings(use, cntnr, e, rest...)
    return use(settings(cntnr, T))
end

# no membership type matched: a setting type GEMS does not ship, looked up at runtime
@inline _unroll_entry_settings(use::U, cntnr::SettingsContainer, e::PlanEntry) where {U} =
    use(settings(cntnr, setting_type_from_index(setting_type_of(e))))

###
### CONTAINER FRAME INDEX
###

"""
    container_frame_index(cntnr::SettingsContainer, container::ContainerSetting, leaf::IndividualSetting, leaf_index::Integer)

Returns the position in `container`'s frame of the member at `leaf_index` of `leaf`, or
`DEFAULT_MEMBER_INDEX` when they are not in it. Reads the frame `present_members` hands out, so
a member below a closed setting, and the dropped copy of a member in two leaves, have no
position here.
"""
function container_frame_index(::SettingsContainer, container::ContainerSetting,
                               leaf::IndividualSetting, leaf_index::Integer)::Int32
    pool = _pool(container)::HierarchicalSettingPool
    _check_clean(container, pool)
    (is_open(container) && is_open(leaf)) || return DEFAULT_MEMBER_INDEX

    # the member's absolute position in the hierarchy pool
    p = Int(leaf.pool_offset) + Int(leaf_index) - 1
    runs = container.pool_runs
    if runs === nothing
        k = p - Int(container.pool_offset) + 1
        return 1 <= k <= container.pool_length ? Int32(k) : DEFAULT_MEMBER_INDEX
    end
    k = _run_index(runs.starts, runs.prefix, Int(container.pool_length), p)
    return k == 0 ? DEFAULT_MEMBER_INDEX : Int32(k)
end

###
### MEMBERSHIP SCALE
### An individual's scale in a setting, from its own plan entries. An entry that does not apply
### this tick contributes 0. Also upper bounds on it per setting type, for draws before a setting is loaded.
###

# nobody holds an entry for the GlobalSetting
@inline _membership_scale(::ActivityPlanStore, ::Individual, ::GlobalSetting, ::SettingsContainer) = 1.0f0

@inline function _membership_scale(plans::ActivityPlanStore, individual::Individual, s::T,
                                   ::SettingsContainer) where {T<:IndividualSetting}
    individual.plan_scaled || return 1.0f0
    return _effective_scale(plans, plan_slot(plans, individual, T, id(s)))
end

# A container has no entry: the scales of the individual's open leaves below it, summed and capped at
# the larger of 1 and the largest.
function _membership_scale(plans::ActivityPlanStore, individual::Individual, c::C,
                           cntnr::SettingsContainer) where {C<:ContainerSetting}
    individual.plan_scaled || return 1.0f0
    L = _leaf_type(C)
    slots = plan_slots(plans, individual, L)
    # a single leaf entry is the one that put the individual in c's frame
    length(slots) == 1 && return _effective_scale(plans, first(slots))
    leaves = settings(cntnr, L)
    pool = _pool(c)::HierarchicalSettingPool
    # a closed container frames none of its leaves
    pool.closed != 0 && !is_open(c) && return 0.0f0
    return _capped_scale_sum(plans, slots) do k
        e = @inbounds plans.entries[k]
        _in_container_frame(c, pool, leaves[setting_id(e)], member_index(e))
    end
end

# An upper bound on `_membership_scale` in any type-`S` setting reached from the entry at `slot`: the
# entry's scale for a leaf, the capped sum over all the individual's leaf entries for a container.
@inline _membership_scale_bound(::ActivityPlanStore, ::Individual, ::Type{GlobalSetting}, ::Int) = 1.0f0

@inline function _membership_scale_bound(plans::ActivityPlanStore, individual::Individual, ::Type{T},
                                         slot::Int) where {T<:IndividualSetting}
    individual.plan_scaled || return 1.0f0
    return _effective_scale(plans, slot)
end

function _membership_scale_bound(plans::ActivityPlanStore, individual::Individual, ::Type{C},
                                 ::Int) where {C<:ContainerSetting}
    individual.plan_scaled || return 1.0f0
    # more slots only raise the sum and the cap
    return _capped_scale_sum(_ -> true, plans, plan_slots(plans, individual, _leaf_type(C)))
end

# The scales of the slots `include` accepts, summed but capped at the larger of 1 and the largest
@inline function _capped_scale_sum(include::F, plans::ActivityPlanStore, slots) where {F}
    total = 0.0f0
    largest = 0.0f0
    for k in slots
        include(k) || continue
        s = _effective_scale(plans, k)
        total += s
        largest = max(largest, s)
    end
    return min(total, max(1.0f0, largest))
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
    # no copy when a column is already Int32
    column_ids = Vector{Int32}[_int32_column(df[!, membership_column(T)]) for T in types]
    column_tidx = UInt8[setting_type_index(T) for T in types]
    rows = memberships === nothing ? _no_membership_rows() :
        _membership_rows(pop, memberships, column_tidx, column_ids)
    isempty(types) && isempty(rows.ind) && return store
    # what every block is built from
    source = (column_ids = column_ids, column_tidx = column_tidx, rows = _grouped_rows(rows))

    inds = individuals(pop)
    # chunks count their entries in parallel to find their first slot, then fill their blocks in parallel
    chunks = _thread_chunks(eachindex(inds))
    starts = zeros(Int, length(chunks) + 1)
    Threads.@threads for c in eachindex(chunks)
        @inbounds starts[c + 1] = _count_plan_entries(source, chunks[c])
    end
    starts[1] = 1
    cumsum!(starts, starts)
    resize!(store.entries, starts[end] - 1)

    # table rows are added after, serially, so their errors surface in individual order
    deferred = [Tuple{Int, Int, Int, UInt16}[] for _ in chunks]
    Threads.@threads for c in eachindex(chunks)
        @inbounds _fill_blocks!(store, inds, source, chunks[c], starts[c], deferred[c])
    end
    for c in eachindex(chunks), (i, off, at, mask) in deferred[c]
        _add_table_rows!(store, inds[i], source.rows, i, off, at, mask)
    end

    # nothing gates entries yet, so every one applies
    resize!(store.active, length(store.entries))
    fill!(store.active, true)
    return store
end

_int32_column(col::Vector{Int32}) = col
_int32_column(col::AbstractVector) = Int32.(col)

# The rows `_membership_rows` returns, for a population without a membership table.
_no_membership_rows() = (ind = Int[], tidx = UInt8[], sid = Int32[], primary = falses(0),
    scale = Float64[], rescales = falses(0))

# The rows grouped by individual, each individual's primary first and the rest in file order.
function _grouped_rows(rows)
    order = sortperm(collect(zip(rows.ind, .!rows.primary)))
    return map(v -> v[order], rows)
end

# Plan entries held by the individuals in `r`: population-row settings plus table rows that add one.
function _count_plan_entries(source, r::UnitRange{Int})
    m = 0
    @inbounds for col in source.column_ids, i in r
        col[i] == DEFAULT_SETTING_ID || (m += 1)
    end
    rows = source.rows
    own = searchsortedfirst(rows.ind, first(r)):searchsortedlast(rows.ind, last(r))
    return m + count(!, view(rows.rescales, own))
end

# The rows of individual `i`, which start at `q` if there are any.
@inline function _rows_of(ind::Vector{Int}, i::Int, q::Int)
    e = q
    @inbounds while e <= length(ind) && ind[e] == i
        e += 1
    end
    return q:(e - 1)
end

# Writes individual `i`'s population-row entries from slot `at`; returns (next slot, membership mask).
@inline function _write_population_entries!(store::ActivityPlanStore, source, i::Int, at::Int)
    mask = UInt16(0)
    @inbounds for k in eachindex(source.column_ids)
        sid = source.column_ids[k][i]
        sid == DEFAULT_SETTING_ID && continue
        t = source.column_tidx[k]
        store.entries[at] = PlanEntry(sid, DEFAULT_MEMBER_INDEX, Float16(1.0), t)
        at += 1
        _mask_slot(t) != 0 && (mask |= _membership_bit(t))
    end
    return at, mask
end

# Points `ind` at its block of `n` entries from slot `off`.
@inline function _set_plan!(ind::Individual, off::Int, n::Int, mask::UInt16, scaled::Bool)
    ind.plan_offset = Int32(n == 0 ? 0 : off)
    ind.plan_count = Int8(n)
    ind.membership_mask = mask
    ind.plan_scaled = scaled
    return nothing
end

# Fills the blocks of the individuals in `r` from slot `at`. Those with table rows get only their
# population-row entries and go to `deferred` as (individual, block start, next slot, mask).
function _fill_blocks!(store::ActivityPlanStore, inds::Vector{Individual}, source, r::UnitRange{Int},
                       at::Int, deferred::Vector{Tuple{Int, Int, Int, UInt16}})
    rows = source.rows
    q = searchsortedfirst(rows.ind, first(r))
    @inbounds for i in r
        off = at
        at, mask = _write_population_entries!(store, source, i, at)
        own = _rows_of(rows.ind, i, q)
        q = last(own) + 1
        if isempty(own)
            # every population-row entry has scale 1
            _set_plan!(inds[i], off, at - off, mask, false)
        else
            push!(deferred, (i, off, at, mask))
            at += count(!, view(rows.rescales, own))
        end
    end
    return nothing
end

# Adds individual `i`'s table rows to its block, whose population-row entries fill `off:(at - 1)`,
# then sorts and checks it.
function _add_table_rows!(store::ActivityPlanStore, ind::Individual, rows, i::Int, off::Int, at::Int, mask::UInt16)
    population_end = at
    for r in searchsorted(rows.ind, i)
        t = rows.tidx[r]
        if rows.rescales[r]
            # the population row's entry is the first of its type, so this finds it
            k = off - 1 + findfirst(e -> setting_type_of(e) == t, view(store.entries, off:(at - 1)))
            store.entries[k] = _with_scale(store.entries[k], rows.scale[r])
            continue
        end
        store.entries[at] = PlanEntry(rows.sid[r], DEFAULT_MEMBER_INDEX, Float16(rows.scale[r]), t)
        at += 1
        _mask_slot(t) != 0 && (mask |= _membership_bit(t))
    end

    n = at - off
    block = view(store.entries, off:(at - 1))
    if at > population_end
        n <= typemax(Int8) || throw(ArgumentError(
            "individual $(id(ind)) would hold $n plan entries; the cap is $(typemax(Int8))"))
        # stable, so each type keeps its primary first and the rest in file order
        sort!(block; alg = InsertionSort, by = setting_type_of)
        _check_repeated_entries(block, ind)
    end
    foreach(e -> _raise_scale_bound!(store, e), block)
    # every entry starts active, so its own scale is the one that counts
    _set_plan!(ind, off, n, mask, any(e -> entry_scale(e) != 1, block))
    return nothing
end

"""
    assign_settings!(pop::Population, individual::Individual, memberships::Pair...; primary::Bool = false, scale::Real = 1.0)

Gives `individual` one plan entry at `scale` per `setting type => setting id` pair, as a
population file's membership columns would, each as the primary of its type if `primary`. Only
before the settings are built; afterwards use `add_member!`, which edits the setting too.
"""
function assign_settings!(pop::Population, individual::Individual, memberships::Pair...; primary::Bool = false, scale::Real = 1.0)
    plans = activity_plans(pop)
    # once indexed, an entry with no matching setting member would go unnoticed
    plans.indexed && throw(ArgumentError(
        "the settings are already built; use `add_member!`, which also edits the setting"))
    for (T, sid) in memberships
        plan_add!(plans, individual, PlanEntry(T, Int32(sid), DEFAULT_MEMBER_INDEX, scale); primary = primary)
    end
    return pop
end

###
### ADDING ENTRIES
### New entries of one setting type merged into built plans in one parallel pass, block by block
### as in `build_plans!`.
###

"""
    _PlanAdditions{S}

New plan entries of one setting type by individual position: individual `i`'s setting ids are
`sids[offsets[i]:(offsets[i + 1] - 1)]`, `DEFAULT_SETTING_ID` for none, with `scales` alongside
unless every scale is 1.
"""
struct _PlanAdditions{S<:Union{Nothing, Vector{Float16}}}
    tidx::UInt8
    offsets::Vector{Int32}
    sids::Vector{Int32}
    scales::S
end

@inline _addition_rows(a::_PlanAdditions, i::Int) = Int(a.offsets[i]):(Int(a.offsets[i + 1]) - 1)

@inline _addition_scale(::_PlanAdditions{Nothing}, ::Int) = Float16(1)
@inline _addition_scale(a::_PlanAdditions, k::Int) = @inbounds a.scales[k]

"""
    _merge_additions!(store::ActivityPlanStore, inds::Vector{Individual}, additions::_PlanAdditions; chunks)

Rebuilds the store with each individual's new entries behind its existing ones of their type, so
every primary stays, and returns the bytes allocated. The ids must be new to each individual and
fit under the entry cap (see `_check_room`); freed blocks are dropped.
"""
function _merge_additions!(store::ActivityPlanStore, inds::Vector{Individual}, additions::_PlanAdditions;
                           chunks::Vector{UnitRange{Int}} = _thread_chunks(eachindex(inds)))
    # built settings would not hold the new entries' individuals
    store.indexed && throw(ArgumentError("the settings are already built; entries can only be merged before"))
    starts = _merged_starts(inds, additions, chunks)
    entries = Vector{PlanEntry}(undef, starts[end] - 1)
    # staged as Bools when some entry is inactive; threads can't share a BitVector's words
    staged = all(store.active) ? nothing : Vector{Bool}(undef, length(entries))
    Threads.@threads for c in eachindex(chunks)
        @inbounds _merge_chunk!(entries, staged, store, inds, additions, chunks[c], starts[c])
    end
    store.entries = entries
    store.active = staged === nothing ? trues(length(entries)) : BitVector(staged)
    empty!(store.free)
    _raise_scale_bound!(store, additions.tidx, _max_addition_scale(additions))
    return sizeof(entries) + (staged === nothing ? 0 : sizeof(staged)) + Base.summarysize(store.active)
end

# Each chunk's first slot in the merged entries, then one past the last.
function _merged_starts(inds::Vector{Individual}, additions::_PlanAdditions, chunks::Vector{UnitRange{Int}})
    starts = zeros(Int, length(chunks) + 1)
    Threads.@threads for c in eachindex(chunks)
        @inbounds starts[c + 1] = _merged_count(inds, additions, chunks[c])
    end
    starts[1] = 1
    cumsum!(starts, starts)
    # plan offsets are Int32
    n = starts[end] - 1
    n <= typemax(Int32) || throw(ArgumentError("the plans would hold $n entries; at most $(typemax(Int32)) fit"))
    return starts
end

# Plan entries the individuals in `r` hold after the merge.
function _merged_count(inds::Vector{Individual}, additions::_PlanAdditions, r::UnitRange{Int})
    m = 0
    @inbounds for i in r
        m += plan_length(inds[i])
        for k in _addition_rows(additions, i)
            additions.sids[k] == DEFAULT_SETTING_ID || (m += 1)
        end
    end
    return m
end

# Writes the merged blocks of the individuals in `r` from slot `at`: old entries up to the end of
# the type's run, the new ones, then the rest.
function _merge_chunk!(entries::Vector{PlanEntry}, staged::Union{Nothing, Vector{Bool}}, store::ActivityPlanStore,
                       inds::Vector{Individual}, additions::_PlanAdditions, r::UnitRange{Int}, at::Int)
    @inbounds for i in r
        ind = inds[i]
        old, n = Int(ind.plan_offset), plan_length(ind)
        start, len = _plan_type_run(store, ind, additions.tidx)
        off = at
        at = _copy_entries!(entries, staged, store, old, 0:(start + len - 1), at)
        at, mask, scaled = _write_additions!(entries, staged, additions, i, at, ind.membership_mask, ind.plan_scaled)
        at = _copy_entries!(entries, staged, store, old, (start + len):(n - 1), at)
        _set_plan!(ind, off, at - off, mask, scaled)
    end
    return nothing
end

# Writes individual `i`'s new entries from slot `at`; returns the next slot, and `mask` and `scaled`
# updated for them.
@inline function _write_additions!(entries::Vector{PlanEntry}, staged::Union{Nothing, Vector{Bool}},
                                   additions::_PlanAdditions, i::Int, at::Int, mask::UInt16, scaled::Bool)
    t = additions.tidx
    @inbounds for k in _addition_rows(additions, i)
        sid = additions.sids[k]
        sid == DEFAULT_SETTING_ID && continue
        s = _addition_scale(additions, k)
        entries[at] = PlanEntry(sid, DEFAULT_MEMBER_INDEX, s, t)
        staged === nothing || (staged[at] = true)
        _mask_slot(t) != 0 && (mask |= _membership_bit(t))
        scaled |= s != 1
        at += 1
    end
    return at, mask, scaled
end

# Copies the old entries at block positions `ks` of the block at `old`, with their flags if
# staged, to slot `at`; returns the next slot.
@inline function _copy_entries!(entries::Vector{PlanEntry}, staged::Union{Nothing, Vector{Bool}}, store::ActivityPlanStore,
                                old::Int, ks::UnitRange{Int}, at::Int)
    @inbounds for k in ks
        entries[at] = store.entries[old + k]
        staged === nothing || (staged[at] = store.active[old + k])
        at += 1
    end
    return at
end

_max_addition_scale(::_PlanAdditions{Nothing}) = 1.0f0

function _max_addition_scale(a::_PlanAdditions)
    m = 1.0f0
    @inbounds for k in eachindex(a.sids)
        a.sids[k] == DEFAULT_SETTING_ID || (m = max(m, Float32(a.scales[k])))
    end
    return m
end

# The largest id of a setting of type index `t` in any plan, 0 if none. Reads live blocks only,
# since freed ones can hold stale ids.
function _max_setting_id(store::ActivityPlanStore, inds::Vector{Individual}, t::UInt8)
    m = Int32(0)
    @inbounds for ind in inds
        start, len = _plan_type_run(store, ind, t)
        off = Int(ind.plan_offset) + start
        for k in off:(off + len - 1)
            m = max(m, setting_id(store.entries[k]))
        end
    end
    return m
end

###
### MEMBERSHIP TABLE
###

"""
    memberships(pop::Population)

Returns the memberships `dataframe(pop)` leaves out, one row per plan entry: `id`,
`setting_type` (the type's name), `setting_id` and `scale`, in individual then plan order. That
is every entry after the first of its type, every entry of a type without a membership column,
and every scaled entry. Loading both tables back rebuilds the same plans.
"""
function memberships(pop::Population)
    plans = activity_plans(pop)
    column_tidx = map(setting_type_index, membership_setting_types(Individual))
    ids = Int32[]
    types = String[]
    sids = Int32[]
    scales = Float32[]
    names = Dict{UInt8, String}()
    for ind in individuals(pop)
        prev = 0x00
        for e in plan_entries(plans, ind)
            t = setting_type_of(e)
            # the population row holds only the first entry of each of its types, at scale 1; the rest go in the table
            if t == prev || !(t in column_tidx) || entry_scale(e) != 1
                push!(ids, id(ind))
                push!(types, get!(() -> setting_type_name(setting_type_from_index(t)), names, t))
                push!(sids, setting_id(e))
                push!(scales, entry_scale(e))
            end
            prev = t
        end
    end
    return DataFrame(id = ids, setting_type = types, setting_id = sids, scale = scales)
end

# Resolves the membership table to per-row (individual index, type index, setting id, primary, scale,
# whether the row only scales the population row's entry). Errors on the first invalid row.
function _membership_rows(pop::Population, table::DataFrame, column_tidx::Vector{UInt8}, column_ids::Vector{Vector{Int32}})
    for c in (:id, :setting_type, :setting_id)
        c in propertynames(table) || throw(ArgumentError("the membership table has no `$c` column"))
    end
    n = nrow(table)
    ind = Vector{Int}(undef, n)
    tidx = Vector{UInt8}(undef, n)
    sid = Vector{Int32}(undef, n)
    primary = :primary in propertynames(table) ? BitVector(Bool.(table.primary)) : falses(n)
    has_scale = :scale in propertynames(table)
    scale = has_scale ? Float64.(table.scale) : ones(n)
    rescales = falses(n)
    resolved = Dict{String, UInt8}()
    primaries = Set{Tuple{Int, UInt8}}()
    rescaled = Set{Tuple{Int, UInt8}}()

    for r in 1:n
        pid = table.id[r]
        k = Int(pid) - Int(pop.minid) + 1
        (1 <= k <= length(pop.id_map) && pop.id_map[k] > 0) || throw(ArgumentError(
            "membership row $r names individual $pid, who is not in the population"))
        ind[r] = Int(pop.id_map[k])

        name = string(table.setting_type[r])
        tidx[r] = get!(resolved, name) do
            T = _resolve_setting_type(name)
            T === nothing && throw(ArgumentError(
                "membership row $r names setting type \"$name\", which does not exist"))
            _holds_entries(T) || throw(ArgumentError(
                "membership row $r names $T, whose settings hold no members directly"))
            setting_type_index(T)
        end

        s = Int32(table.setting_id[r])
        s > 0 || throw(ArgumentError("membership row $r has setting id $s; ids start at 1"))
        sid[r] = s
        0 <= scale[r] <= floatmax(Float16) || throw(ArgumentError(
            "membership row $r has scale $(scale[r]); scales lie in [0, $(floatmax(Float16))]"))

        w = findfirst(==(tidx[r]), column_tidx)
        # with a scale column, a row naming the population row's own setting only scales it
        if has_scale && w !== nothing && column_ids[w][ind[r]] == s
            (ind[r], tidx[r]) in rescaled && throw(ArgumentError(
                "membership row $r scales individual $pid's $name $s a second time"))
            push!(rescaled, (ind[r], tidx[r]))
            rescales[r] = true
            continue
        end

        primary[r] || continue
        (w === nothing || column_ids[w][ind[r]] == DEFAULT_SETTING_ID) || throw(ArgumentError(
            "membership row $r makes $name $s the primary of individual $pid, whose population row already names one"))
        (ind[r], tidx[r]) in primaries && throw(ArgumentError(
            "membership row $r is a second primary $name for individual $pid"))
        push!(primaries, (ind[r], tidx[r]))
    end
    return (ind = ind, tidx = tidx, sid = sid, primary = primary, scale = scale, rescales = rescales)
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

###
### INDEXING
###

"""
    assign_member_indices!(pop::Population, cntnr::SettingsContainer)

Fills in each entry's `member_index`, and each setting's scale bound, from the finished settings.
Must run after `build_pools!`. Errors if a member of a pooled leaf holds no entry for it.
"""
function assign_member_indices!(pop::Population, cntnr::SettingsContainer)
    plans = activity_plans(pop)
    for T in settingtypes(cntnr)
        # GlobalSetting holds everyone, so nobody carries an entry for it
        (T <: IndividualSetting && T !== GlobalSetting) && _assign_member_indices!(plans, cntnr, T)
    end
    return _finish_indexing!(plans, cntnr)
end

# Once every leaf's member indices and bound are set: the containers take their bounds from the
# leaves, and the store counts as indexed.
function _finish_indexing!(plans::ActivityPlanStore, cntnr::SettingsContainer)
    for pool in values(cntnr.pools)
        _foreach_block!(_refresh_block!, pool, 1:nblocks(pool.blocks))
    end
    plans.indexed = true
    return plans
end

# function barrier: with `T` static, `settings(cntnr, T)` is a typed vector. The lookup is the
# one `check_pool_entries` makes, so a pooled member without an entry is caught here.
function _assign_member_indices!(plans::ActivityPlanStore, cntnr::SettingsContainer,
                                 ::Type{T}) where {T<:IndividualSetting}
    pooled = haskey(cntnr.pools, T)
    for s in settings(cntnr, T)
        sid = id(s)
        members = individuals(s)
        bound = 1.0f0
        for k in eachindex(members)
            slot = plan_slot(plans, members[k], T, sid)
            if slot == 0
                pooled && _missing_entry_error(members[k], s)
                continue
            end
            plan_set_member_index!(plans, slot, k)
            bound = max(bound, Float32(entry_scale(@inbounds plans.entries[slot])))
        end
        hasfield(T, :scale_bound) && (s.scale_bound = bound)
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
        plan_slot(plans, ind, T, id(s)) != 0 || _missing_entry_error(ind, s)
    end
    return nothing
end

@noinline _missing_entry_error(ind::Individual, s::Setting) = error(
    "individual $(id(ind)) is a member of $(typeof(s)) $(id(s)) but holds no plan entry " *
    "for it; membership edits read the plan store, so it has to cover every member")

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

    for k in 0:(pos - 1)
        _move_entry!(store, new + k, old + k)
    end
    @inbounds store.entries[new + pos] = entry
    _raise_scale_bound!(store, entry)
    @inbounds store.active[new + pos] = true
    for k in pos:(n - 1)
        _move_entry!(store, new + k + 1, old + k)
    end

    _free_block!(store, old, n)
    individual.plan_offset = Int32(new)
    individual.plan_count = Int8(n + 1)
    _mask_slot(tidx) != 0 && (individual.membership_mask |= _membership_bit(tidx))
    entry_scale(entry) != 1 && (individual.plan_scaled = true)
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
    # an inactive entry made the individual scaled too
    scaled = _effective_scale(store, slot) != 1
    pos = slot - old

    if n == 1
        _free_block!(store, old, 1)
        individual.plan_offset = Int32(0)
    else
        new = _alloc_block!(store, n - 1)
        for k in 0:(pos - 1)
            _move_entry!(store, new + k, old + k)
        end
        for k in (pos + 1):(n - 1)
            _move_entry!(store, new + k - 1, old + k)
        end
        _free_block!(store, old, n)
        individual.plan_offset = Int32(new)
    end

    individual.plan_count = Int8(n - 1)
    # the bit means "holds at least one of this type", so it only clears once the last one goes
    # the mask is not updated yet, so scan the block
    if _mask_slot(tidx) != 0 && _plan_type_run_scan(store, individual, tidx)[2] == 0
        individual.membership_mask &= ~_membership_bit(tidx)
    end
    scaled && _refresh_plan_scaled!(store, individual)
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
    for k in slot:-1:(front + 1)
        _move_entry!(store, k, k - 1)
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

"""
    set_scale!(store::ActivityPlanStore, individual::Individual, ::Type{T}, sid::Integer, scale::Real) where {T<:Setting}

Sets the scale of the individual's entry for setting `sid` of type `T`. Only before the settings
are built; afterwards use the `Simulation` method, which also updates the setting's scale bound.
"""
function set_scale!(store::ActivityPlanStore, individual::Individual, ::Type{T}, sid::Integer, scale::Real) where {T<:Setting}
    # once built, the setting's bound would go stale
    store.indexed && throw(ArgumentError(
        "the settings are already built; use `set_scale!` with the simulation, which also updates the setting"))
    _set_entry_scale!(store, individual, T, sid, scale)
    return nothing
end

"""
    set_scale!(pop::Population, individual::Individual, ::Type{T}, sid::Integer, scale::Real) where {T<:Setting}

Convenience for callers holding a `Population` rather than the store.
"""
set_scale!(pop::Population, individual::Individual, ::Type{T}, sid::Integer, scale::Real) where {T<:Setting} =
    set_scale!(activity_plans(pop), individual, T, sid, scale)

function _set_entry_scale!(store::ActivityPlanStore, individual::Individual, ::Type{T}, sid::Integer, scale::Real) where {T<:Setting}
    slot = plan_slot(store, individual, T, Int32(sid))
    slot == 0 && throw(ArgumentError("individual $(id(individual)) holds no entry for $T $sid"))
    @inbounds store.entries[slot] = _with_scale(store.entries[slot], scale)
    _raise_scale_bound!(store, @inbounds store.entries[slot])
    _refresh_plan_scaled!(store, individual)
    return nothing
end

function _refresh_plan_scaled!(store::ActivityPlanStore, individual::Individual)
    individual.plan_scaled = any(k -> _effective_scale(store, k) != 1, plan_slots(store, individual))
    return nothing
end

# copies the entry at slot `from`, with its active flag, to slot `to`
@inline function _move_entry!(store::ActivityPlanStore, to::Int, from::Int)
    @inbounds store.entries[to] = store.entries[from]
    @inbounds store.active[to] = store.active[from]
    return nothing
end

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
