###
### SETTING LAYERS
### Activity-plan entries generated from parameters and added to a population's plans.
###

# EXPORTS
export SettingLayer, add_setting_layers!
export PackedSettings, RandomSettings, GroupedSettings, AgeSortedSettings, SpatialSettings
export JoinExisting, JoinNearby

###
### ASSIGNMENT TYPES
###

"""
    LayerAssignment

How a `SettingLayer` puts its participants into settings.
"""
abstract type LayerAssignment end

"""
    NewSettingsAssignment <: LayerAssignment

An assignment that puts participants into settings it creates.
"""
abstract type NewSettingsAssignment <: LayerAssignment end

"""
    JoinAssignment <: LayerAssignment

An assignment that puts participants into settings that already exist.
"""
abstract type JoinAssignment <: LayerAssignment end

"""
    PackedSettings(; size)

New settings: participants in random order, cut into settings of `size` members (a number or a
distribution of sizes).
"""
struct PackedSettings{S} <: NewSettingsAssignment
    size::S
end
PackedSettings(; size) = PackedSettings(_layer_value(size))

"""
    RandomSettings(; size)

New settings: one pool of settings with `size` members on average, each participant in
uniformly drawn ones, so sizes vary.
"""
struct RandomSettings{S} <: NewSettingsAssignment
    size::S
end
RandomSettings(; size) = RandomSettings(_layer_value(size))

"""
    GroupedSettings(; size, by = Household)

New settings of about `size` members that keep participants sharing a `by` setting together.
"""
struct GroupedSettings{S} <: NewSettingsAssignment
    size::S
    by::UInt8
end
GroupedSettings(; size, by = Household) = GroupedSettings(_layer_value(size), _layer_type_index(by, "`by`"))

"""
    AgeSortedSettings(; size)

New settings: participants sorted by age, cut into settings of `size` members.
"""
struct AgeSortedSettings{S} <: NewSettingsAssignment
    size::S
end
AgeSortedSettings(; size) = AgeSortedSettings(_layer_value(size))

"""
    SpatialSettings(; size, spread)

New settings of `size` members who live near each other: homes displaced by `spread` km (a
number for a Gaussian, or a distribution of distances), cut along a space-filling curve.
"""
struct SpatialSettings{S, D} <: NewSettingsAssignment
    size::S
    spread::D
end
SpatialSettings(; size, spread) = SpatialSettings(_layer_value(size), _layer_value(spread))

"""
    JoinExisting()

Existing settings, each drawn with probability proportional to its member count.
"""
struct JoinExisting <: JoinAssignment end

"""
    JoinNearby(; spread)

Existing settings near the participant's home displaced by `spread` km (a number for a
Gaussian, or a distribution of distances).
"""
struct JoinNearby{D} <: JoinAssignment
    spread::D
end
JoinNearby(; spread) = JoinNearby(_layer_value(spread))

# numbers become Float64, so the draws need one method for numbers
_layer_value(x::Real) = Float64(x)
_layer_value(x) = x

"""
    _check_assignment(a::LayerAssignment)

Throws an `ArgumentError` if an assignment's parameters are out of range.
"""
_check_assignment(a::NewSettingsAssignment) = _check_positive(a.size, "`size`"; finite_mean = true)
function _check_assignment(a::SpatialSettings)
    _check_positive(a.size, "`size`"; finite_mean = true)
    _check_positive(a.spread, "`spread`")
    return nothing
end
_check_assignment(::JoinExisting) = nothing
_check_assignment(a::JoinNearby) = _check_positive(a.spread, "`spread`")

# Throws unless `x` is a finite number > 0 or a non-negative distribution, with a finite
# positive mean if `finite_mean`.
function _check_positive(x, what::AbstractString; finite_mean::Bool = false)
    ok = if x isa Real
        isfinite(x) && x > 0
    elseif x isa UnivariateDistribution
        minimum(x) >= 0 && (!finite_mean || (isfinite(mean(x)) && mean(x) > 0))
    else
        false
    end
    ok || throw(ArgumentError("$what must be a number > 0 or a non-negative distribution" *
        (finite_mean ? " with a finite positive mean" : "") * "; got $x"))
    return nothing
end

###
### LAYER TYPE
###

"""
    SettingLayer{T, A, F, E, C}

Rules for giving individuals entries of setting type `T`; built with `SettingLayer(T; ...)`.
`E` and `C` are the types of `entries` and `scale`.
"""
struct SettingLayer{T<:IndividualSetting, A<:LayerAssignment, F, E, C}
    name::Union{Nothing, String}
    assignment::A
    eligible::F
    holding::Vector{UInt8}
    not_holding::Vector{UInt8}
    participation::Float64
    entries::E
    scale::C
end

"""
    SettingLayer(T; assignment, name = nothing, eligible = _ -> true, holding = (),
                 not_holding = (), participation = 1.0, entries = 1, scale = 1.0)

Builds a layer of setting type `T`; throws an `ArgumentError` for out-of-range parameters.

# Keywords
- `assignment::LayerAssignment`: how participants are put into settings
- `name`: identifies the layer in the population's records, unique per population; by default
  `"<Type>[k]"`. The layer's random draws are seeded from it.
- `eligible`: a function of an `Individual` saying who may take part
- `holding` / `not_holding`: setting types an individual must / must not already hold
- `participation`: probability that an eligible individual takes part
- `entries`: settings per participant, an integer in 0-127 or a discrete distribution
- `scale`: contact scale per entry, a number in 0-floatmax(Float16) or a distribution
"""
function SettingLayer(T; assignment::LayerAssignment, name = nothing, eligible = _ -> true,
        holding = (), not_holding = (), participation::Real = 1.0,
        entries::Union{Integer, DiscreteUnivariateDistribution} = 1,
        scale::Union{Real, UnivariateDistribution} = 1.0)
    # checks and registers `T`
    _layer_type_index(T, "a layer's setting type")
    n = entries isa Integer ? Int(entries) : entries
    s = _layer_value(scale)
    layer = SettingLayer{T, typeof(assignment), typeof(eligible), typeof(n), typeof(s)}(
        name === nothing ? nothing : String(name), assignment, eligible,
        _layer_type_indices(holding, "`holding`"), _layer_type_indices(not_holding, "`not_holding`"),
        Float64(participation), n, s)
    _check_layer(layer)
    return layer
end

"""
    _check_layer(layer::SettingLayer)

Throws an `ArgumentError` if a layer's parameters are out of range.
"""
function _check_layer(layer::SettingLayer)
    isdisjoint(layer.holding, layer.not_holding) ||
        throw(ArgumentError("`holding` and `not_holding` share a setting type"))
    0 <= layer.participation <= 1 ||
        throw(ArgumentError("`participation` must be in [0, 1]; got $(layer.participation)"))
    n, cap = layer.entries, typemax(Int8)
    if n isa Int
        entries_ok = 0 <= n <= cap
    else
        bounded_ok = !isfinite(maximum(n)) || maximum(n) <= cap
        entries_ok = minimum(n) >= 0 && bounded_ok
    end
    entries_ok || throw(ArgumentError(
        "`entries` must be in 0-$cap, or a non-negative distribution at most $cap if bounded; got $n"))
    s = layer.scale
    if s isa Real
        scale_ok = 0 <= s <= floatmax(Float16)
    else
        scale_ok = minimum(s) >= 0
    end
    scale_ok || throw(ArgumentError(
        "`scale` must be in [0, $(floatmax(Float16))] or a non-negative distribution; got $s"))
    _check_assignment(layer.assignment)
    return nothing
end

# Throws unless `S` is a concrete setting type individuals hold entries of.
function _check_holds_entries(S, what::AbstractString)
    (S isa Type && S <: Setting && isconcretetype(S) && _holds_entries(S)) || throw(ArgumentError(
        "$what must be a concrete setting type individuals hold entries of (not a container or GlobalSetting); got $S"))
    return nothing
end

# The type index of `S`, registering it after checking individuals can hold entries of it.
function _layer_type_index(S, what::AbstractString)
    _check_holds_entries(S, what)
    return register_setting_type!(S)
end

_layer_type_indices(S::Type, what::AbstractString) = [_layer_type_index(S, what)]
_layer_type_indices(types, what::AbstractString) = unique!(UInt8[_layer_type_index(S, what) for S in types])

_layer_type(::SettingLayer{T}) where {T} = T

###
### APPLYING LAYERS
###

"""
    add_setting_layers!(pop::Population, layers::SettingLayer...; seed::Integer)

Gives the population's individuals the plan entries each layer describes, layer by layer, with
draws seeded from `seed` and each layer's name.
"""
function add_setting_layers!(pop::Population, layers::SettingLayer...; seed::Integer)
    # the merge checks this too, but only after the first layer is generated
    activity_plans(pop).indexed && throw(ArgumentError(
        "the settings are already built; add setting layers before building them"))
    for (layer, name) in zip(layers, _layer_names(layers))
        _apply_layer!(pop, layer, name, seed, nothing)
    end
    return pop
end

# Generates one layer and merges it into the plans; returns the bytes the merge allocated.
function _apply_layer!(pop::Population, layer::SettingLayer, name::String, seed::Integer, coords)
    store, inds = activity_plans(pop), individuals(pop)
    streams = _LayerStreams(seed, name)
    entry_counts = _layer_entry_counts(layer, pop, streams)
    _check_room(entry_counts, inds)
    additions = _layer_additions(layer, entry_counts, streams)
    ctx = _LayerContext(store, inds, additions.tidx, coords, streams.size)
    _assign!(additions, layer.assignment, ctx, streams.assignment)
    return _merge_additions!(store, inds, additions)
end

# The layers' names: their own, else "<Type>[k]" for the k-th layer of that type. Errors on a repeat.
function _layer_names(layers)
    names = String[]
    for (k, layer) in enumerate(layers)
        T = _layer_type(layer)
        n = count(l -> _layer_type(l) === T, layers[1:k])
        name = something(layer.name, "$(setting_type_name(T))[$n]")
        name in names && throw(ArgumentError("two setting layers are named \"$name\"; names must be unique"))
        push!(names, name)
    end
    return names
end

"""
    _LayerContext{C}

What an assignment reads while placing a layer's participants: the plans, the individuals, the
layer's setting type index, home coordinates (`nothing` without), and the stream setting sizes
are drawn from.
"""
struct _LayerContext{C}
    store::ActivityPlanStore
    inds::Vector{Individual}
    tidx::UInt8
    coords::C
    size_rng::Xoshiro
end

###
### STREAMS AND DRAWS
###

"""
    _LayerStreams(seed::Integer, name::AbstractString)

One random stream per kind of draw a layer makes, seeded from the layer's seed and name.
"""
struct _LayerStreams
    participation::Xoshiro
    entries::Xoshiro
    scale::Xoshiro
    assignment::Xoshiro
    size::Xoshiro
end

function _LayerStreams(seed::Integer, name::AbstractString)
    key = _mix(UInt64(3), seed % UInt64, _name_key(name))
    # the k-th field's stream is keyed on k, so add streams at the end
    return _LayerStreams(ntuple(k -> _rekey!(Xoshiro(0), _mix(key, k)), fieldcount(_LayerStreams))...)
end

_draw_participates(rng::Xoshiro, p::Float64) = gems_rand(rng) < p

_draw_entries(::Xoshiro, n::Int) = n
_draw_entries(rng::Xoshiro, d::Distribution) = round(Int, _rand_val(d, rng))

_draw_scale(::Xoshiro, s::Float64) = Float16(s)

function _draw_scale(rng::Xoshiro, d::Distribution)
    s = _rand_val(d, rng)
    s <= floatmax(Float16) || throw(ArgumentError(
        "a `scale` of $s was drawn from $d; scales are at most $(floatmax(Float16))"))
    return Float16(s)
end

# a number is the mean size, rounded at random so it stays the mean
_draw_size(rng::Xoshiro, size::Float64) = max(1, rand_round(size, rng))
_draw_size(rng::Xoshiro, d::Distribution) = max(1, round(Int, _rand_val(d, rng)))

###
### PARTICIPANTS
###

"""
    _layer_entry_counts(layer::SettingLayer, pop::Population, streams::_LayerStreams)

Returns how many entries the layer gives each individual, by position, 0 for those not taking part.
"""
function _layer_entry_counts(layer::SettingLayer, pop::Population, streams::_LayerStreams)
    store, inds = activity_plans(pop), individuals(pop)
    counts = zeros(UInt8, length(inds))
    for (i, ind) in enumerate(inds)
        # drawn for everyone, so participants nest as participation or eligibility widen
        takes_part = _draw_participates(streams.participation, layer.participation)
        n = _draw_entries(streams.entries, layer.entries)
        (takes_part && _qualifies(layer, store, ind)) || continue
        counts[i] = min(n, typemax(UInt8))
    end
    return counts
end

# Whether `ind` is eligible and holds every type in `holding` and none in `not_holding`.
function _qualifies(layer::SettingLayer, store::ActivityPlanStore, ind::Individual)
    layer.eligible(ind) || return false
    for t in layer.holding
        _plan_type_run(store, ind, t)[2] == 0 && return false
    end
    for t in layer.not_holding
        _plan_type_run(store, ind, t)[2] == 0 || return false
    end
    return true
end

# Throws if the layer would give an individual more plan entries than the cap.
function _check_room(counts::Vector{UInt8}, inds::Vector{Individual})
    for (i, ind) in enumerate(inds)
        n = plan_length(ind) + counts[i]
        n <= typemax(Int8) || throw(ArgumentError(
            "the layer would give individual $(id(ind)) $n plan entries; the cap is $(typemax(Int8))"))
    end
    return nothing
end

###
### ADDITIONS
###

"""
    _layer_additions(layer::SettingLayer, entry_counts::Vector{UInt8}, streams::_LayerStreams)

Returns the layer's rows, `entry_counts[i]` for the individual at position `i`, with scales drawn
and setting ids still to be assigned.
"""
function _layer_additions(layer::SettingLayer, entry_counts::Vector{UInt8}, streams::_LayerStreams)
    offsets = _addition_offsets(entry_counts)
    n = Int(offsets[end]) - 1
    scales = _addition_scales(layer.scale, n, streams.scale)
    return _PlanAdditions(setting_type_index(_layer_type(layer)), offsets, fill(DEFAULT_SETTING_ID, n), scales)
end

# Each individual's first row, then one past the last row.
function _addition_offsets(entry_counts::Vector{UInt8})
    n = sum(Int, entry_counts; init = 0)
    n < typemax(Int32) || throw(ArgumentError("the layer would add $n entries; at most $(typemax(Int32) - 1) fit"))
    offsets = Vector{Int32}(undef, length(entry_counts) + 1)
    offsets[1] = 1
    for i in eachindex(entry_counts)
        @inbounds offsets[i + 1] = offsets[i] + entry_counts[i]
    end
    return offsets
end

# One scale per row, or `nothing` when every scale is 1.
_addition_scales(s::Float64, n::Int, ::Xoshiro) = s == 1 ? nothing : fill(Float16(s), n)
_addition_scales(d::Distribution, n::Int, rng::Xoshiro) = Float16[_draw_scale(rng, d) for _ in 1:n]

# The positions of the individuals with at least `r` rows.
function _round_members(additions::_PlanAdditions, r::Int)
    members = Int32[]
    for i in _addition_individuals(additions)
        length(_addition_rows(additions, i)) >= r && push!(members, Int32(i))
    end
    return members
end

# The most rows any individual has.
_round_count(additions::_PlanAdditions) =
    maximum(i -> length(_addition_rows(additions, i)), _addition_individuals(additions); init = 0)

###
### NEW SETTINGS
###

"""
    _assign!(additions::_PlanAdditions, a::NewSettingsAssignment, ctx::_LayerContext, rng::Xoshiro)

Puts round `r`'s members, those with at least `r` rows, into new settings by `_partition`, so
nobody gets one setting twice. Returns the number of rows left without a setting, here 0.
"""
function _assign!(additions::_PlanAdditions, a::NewSettingsAssignment, ctx::_LayerContext, rng::Xoshiro)
    next_id = _max_setting_id(ctx.store, ctx.inds, ctx.tidx) + Int32(1)
    for r in 1:_round_count(additions)
        members = _round_members(additions, r)
        next_id = _write_labels!(additions, _partition(a, members, ctx, rng), members, r, next_id)
    end
    return 0
end

"""
    _partition(a::NewSettingsAssignment, members::Vector{Int32}, ctx::_LayerContext, rng::Xoshiro)

Returns a label ≥ 1 per member, by position in `members`; members with one label share a new
setting. Setting sizes are drawn from `ctx.size_rng`, never from `rng`.
"""
function _partition end

function _partition(a::PackedSettings, members::Vector{Int32}, ctx::_LayerContext, rng::Xoshiro)
    order = gems_shuffle!(rng, collect(Int32(1):Int32(length(members))))
    return _cut_labels(order, a.size, ctx.size_rng)
end

# Labels the positions in `order` setting by setting along it, each setting's size drawn from
# `size_rng`; the last one may be smaller than drawn.
function _cut_labels(order::Vector{Int32}, size, size_rng::Xoshiro)
    labels = Vector{Int32}(undef, length(order))
    label, left = Int32(0), 0
    for p in order
        if left == 0
            label += Int32(1)
            left = _draw_size(size_rng, size)
        end
        @inbounds labels[p] = label
        left -= 1
    end
    return labels
end

"""
    _write_labels!(additions::_PlanAdditions, labels::Vector{Int32}, members::Vector{Int32}, r::Int, first_id::Int32)

Gives each member's round-`r` row the setting its label names, numbering the labels in use in
sorted order from `first_id`; returns the next free id. The only place rows get new ids.
"""
function _write_labels!(additions::_PlanAdditions, labels::Vector{Int32}, members::Vector{Int32},
                        r::Int, first_id::Int32)
    length(labels) == length(members) || error("got $(length(labels)) labels for $(length(members)) members")
    ids, next_id = _label_ids(labels, first_id)
    @inbounds for (k, i) in enumerate(members)
        additions.sids[_addition_row(additions, Int(i), r)] = ids[labels[k]]
    end
    return next_id
end

# The setting id of each label in use, numbered in sorted order from `first_id`, and the next free id.
function _label_ids(labels::Vector{Int32}, first_id::Int32)
    isempty(labels) && return Int32[], first_id
    minimum(labels) >= 1 || error("setting labels must be at least 1; got $(minimum(labels))")
    used = falses(maximum(labels))
    used[labels] .= true
    Int(first_id) + count(used) - 1 <= typemax(Int32) || throw(ArgumentError(
        "new settings would need ids past $(typemax(Int32))"))
    ids = zeros(Int32, length(used))
    next_id = first_id
    for l in eachindex(used)
        used[l] || continue
        ids[l] = next_id
        next_id += Int32(1)
    end
    return ids, next_id
end
