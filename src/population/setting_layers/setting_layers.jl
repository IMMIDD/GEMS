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

New settings: one pool of `entries / mean(size)` settings, each participant in distinct,
uniformly drawn ones, so sizes vary around `size`. Settings nobody drew aren't created, which
raises the mean size of the rest when `size` is small (1.58 for 1, 2.31 for 2, about `size` from 5 on).
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
number for a Gaussian, or a distribution of distances), cut along a space-filling curve. Members
without coordinates are packed among themselves.
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
Gaussian, or a distribution of distances). With none within 32 cells of the displaced home, or
without coordinates, a participant draws from every setting as `JoinExisting` does.
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

Throws an `ArgumentError` if an assignment's parameters are out of range; accepts any by default.
"""
_check_assignment(::LayerAssignment) = nothing
_check_assignment(a::Union{PackedSettings, RandomSettings, GroupedSettings, AgeSortedSettings}) =
    _check_positive(a.size, "`size`"; finite_mean = true)
function _check_assignment(a::SpatialSettings)
    _check_positive(a.size, "`size`"; finite_mean = true)
    _check_positive(a.spread, "`spread`")
    return nothing
end
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

# Whether an assignment places by household coordinates.
_needs_coordinates(::LayerAssignment) = false
_needs_coordinates(::Union{SpatialSettings, JoinNearby}) = true

# The assignment type called `name`, as a config file names it. Both kinds are searched, as
# `get_subtype` sees direct subtypes only.
function _assignment_type(name::AbstractString)
    kinds = (NewSettingsAssignment, JoinAssignment)
    for kind in kinds, A in _cached_subtypes(kind)
        structname(A) == name && return A
    end
    known = [structname(A) for kind in kinds for A in _cached_subtypes(kind)]
    throw(ArgumentError("\"$name\" is not a setting layer assignment; use one of $(join(known, ", "))"))
end

###
### LAYER TYPE
###

"""
    SettingLayer{T, A, F, P, E, C}

Rules for giving individuals entries of setting type `T`; built with `SettingLayer(T; ...)`.
`P`, `E` and `C` are the types of `participation`, `entries` and `scale`.
"""
struct SettingLayer{T<:IndividualSetting, A<:LayerAssignment, F, P, E, C}
    name::Union{Nothing, String}
    assignment::A
    eligible::F
    holding::Vector{UInt8}
    not_holding::Vector{UInt8}
    participation::P
    entries::E
    scale::C
end

"""
    SettingLayer(T; assignment, name = nothing, eligible = _everyone, holding = (),
                 not_holding = (), participation = 1.0, entries = 1, scale = 1.0)

Builds a layer of setting type `T`; throws an `ArgumentError` for out-of-range parameters.

# Keywords
- `assignment::LayerAssignment`: how participants are put into settings
- `name`: identifies the layer in the population's records, unique per population; by default
  `"<Type>[k]"`. The layer's random draws are seeded from it.
- `eligible`: a function of an `Individual` saying who may take part; by default everyone
- `holding` / `not_holding`: setting types, or their names, an individual must / must not already hold
- `participation`: probability that an eligible individual takes part: a number, or a function of
  an `Individual` returning one
- `entries`: settings per participant, an integer in 0-127 or a discrete distribution
- `scale`: contact scale per entry, a number in 0-floatmax(Float16) or a distribution
"""
function SettingLayer(T; assignment::LayerAssignment, name = nothing, eligible = _everyone,
        holding = (), not_holding = (), participation = 1.0,
        entries::Union{Integer, DiscreteUnivariateDistribution} = 1,
        scale::Union{Real, UnivariateDistribution} = 1.0)
    # checks and registers `T`
    _layer_type_index(T, "a layer's setting type")
    p = _layer_value(participation)
    n = entries isa Integer ? Int(entries) : entries
    s = _layer_value(scale)
    layer = SettingLayer{T, typeof(assignment), typeof(eligible), typeof(p), typeof(n), typeof(s)}(
        name === nothing ? nothing : String(name), assignment, eligible,
        _layer_type_indices(holding, "`holding`"), _layer_type_indices(not_holding, "`not_holding`"),
        p, n, s)
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
    p = layer.participation
    if p isa Real
        participation_ok = 0 <= p <= 1
    elseif p isa _ParticipationTable
        participation_ok = !isempty(p.p) && length(p.criteria) == length(p.p) && all(q -> 0 <= q <= 1, p.p)
    else
        # a function's values are checked as they are drawn
        participation_ok = p isa Function
    end
    participation_ok || throw(ArgumentError("`participation` must be a probability in [0, 1], rows of " *
        "probabilities, or a function of an individual returning one; got $(p isa _ParticipationTable ? _describe(p) : repr(p))"))
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

# A type given by name, as a config file gives it.
function _layer_type_index(name::AbstractString, what::AbstractString)
    T = _resolve_setting_type(name)
    T === nothing && throw(ArgumentError("$what names no setting type: \"$name\""))
    return _layer_type_index(T, what)
end

_layer_type_indices(S::Union{Type, AbstractString}, what::AbstractString) = [_layer_type_index(S, what)]
_layer_type_indices(types, what::AbstractString) = unique!(UInt8[_layer_type_index(S, what) for S in types])

_layer_type(::SettingLayer{T}) where {T} = T

###
### ELIGIBILITY AND PARTICIPATION
### What a layer's `eligible` and `participation` default to, or a config file builds them from,
### each with how a record describes it.
###

# the default `eligible`, named so a layer's description can tell it apart
_everyone(::Individual) = true
_describe(::typeof(_everyone)) = nothing

# A config file's condition on individuals: aged `lo` to `hi`, both included, with a sex,
# occupation and education among those listed; an empty list allows any.
struct _Criteria
    lo::Int
    hi::Int
    sex::Vector{Int8}
    occupation::Vector{Int16}
    education::Vector{Int8}
end

# every age an individual can have
const _ALL_AGES = (0, Int(typemax(Int8)))

_Criteria(; ages = _ALL_AGES, sex = Int8[], occupation = Int16[], education = Int8[]) =
    _Criteria(Int(ages[1]), Int(ages[2]), sex, occupation, education)

(c::_Criteria)(ind::Individual) = c.lo <= age(ind) <= c.hi && _allows(c.sex, sex(ind)) &&
    _allows(c.occupation, occupation(ind)) && _allows(c.education, education(ind))
_allows(values::Vector, value) = isempty(values) || value in values

function _describe(c::_Criteria)
    parts = String[]
    (c.lo, c.hi) == _ALL_AGES || push!(parts, "ages $(c.lo)-$(c.hi)")
    for (name, values) in (("sex", c.sex), ("occupation", c.occupation), ("education", c.education))
        isempty(values) || push!(parts, "$name $(join(values, "/"))")
    end
    return isempty(parts) ? "everyone" : join(parts, " ")
end

# A config file's participation by attribute: the first `criteria` an individual meets gives
# their probability `p`; meeting none gives 0.
struct _ParticipationTable
    criteria::Vector{_Criteria}
    p::Vector{Float64}
end
_describe(t::_ParticipationTable) = "[" * join(("$(_describe(c)): $q" for (c, q) in zip(t.criteria, t.p)), "; ") * "]"

# The probability that `ind` takes part.
_participation(p::Float64, ::Individual) = p

function _participation(t::_ParticipationTable, ind::Individual)
    for (c, q) in zip(t.criteria, t.p)
        c(ind) && return q
    end
    return 0.0
end

function _participation(f::Function, ind::Individual)
    p = f(ind)
    (p isa Real && 0 <= p <= 1) || throw(ArgumentError(
        "`participation` gave $(repr(p)) for individual $(id(ind)); it must be a probability in [0, 1]"))
    return Float64(p)
end

###
### APPLYING LAYERS
###

"""
    add_setting_layers!(pop::Population, layers::SettingLayer...; seed::Integer, household_coordinates = nothing)

Gives the population's individuals the plan entries each layer describes, layer by layer,
recording each in `params(pop)["setting_layers"]`. An error in one layer leaves the ones before
it applied and recorded.

# Keywords
- `seed`: seeds the layers' draws, together with each layer's name
- `household_coordinates`: a table with each household's `id`, `lon` and `lat`, needed by
  `SpatialSettings` and `JoinNearby`
- `id_floors`: internal; per setting type, an id the new settings' ids must stay above

New entries go behind the ones an individual already holds of their type, so they become the
primary only for those who held none: an `Office` layer makes `is_working` true for them.
"""
function add_setting_layers!(pop::Population, layers::SettingLayer...; seed::Integer, household_coordinates = nothing,
                             id_floors::AbstractDict = Dict{DataType, Int}())
    # the merge checks this too, but only after the first layer is generated
    activity_plans(pop).indexed && throw(ArgumentError(
        "the settings are already built; add setting layers before building them"))
    isempty(layers) && return pop
    names = _layer_names(layers, _layer_records(pop))
    coords = _layer_coordinates(layers, household_coordinates)
    bytes = 0
    for (layer, name) in zip(layers, names)
        bytes += _apply_layer!(pop, layer, name, seed, coords, get(id_floors, _layer_type(layer), 0))
    end
    added = sum(r -> r["entries"], last(_layer_records(pop), length(layers)))
    @info "Setting layers added $added plan entries; merging them allocated $(round(bytes / 2^20; digits = 1)) MiB"
    return pop
end

# The households' coordinates if a layer places by location, else `nothing`.
function _layer_coordinates(layers, table)
    any(l -> _needs_coordinates(l.assignment), layers) || return nothing
    table === nothing && throw(ArgumentError(
        "`SpatialSettings` and `JoinNearby` need `household_coordinates`, a table with `id`, `lon` and `lat`"))
    return _HomeCoordinates(table)
end

# Generates one layer, merges it into the plans and records it; returns the bytes the merge allocated.
function _apply_layer!(pop::Population, layer::SettingLayer, name::String, seed::Integer, coords, id_floor::Int)
    store, inds = activity_plans(pop), individuals(pop)
    streams = _LayerStreams(seed, name)
    entry_counts = _layer_entry_counts(layer, pop, streams)
    _check_room(entry_counts, inds)
    additions = _layer_additions(layer, entry_counts, streams)
    ctx = _LayerContext(store, inds, additions.tidx, coords, streams.size, id_floor)
    shortfall = _assign!(additions, layer.assignment, ctx, streams.assignment)
    shortfall > 0 && @warn "Setting layer \"$name\" left out $shortfall entries: no " *
        "$(setting_type_name(_layer_type(layer))) was left that their individual did not already hold"
    added, ids = _added_entries(additions)
    # a layer that adds nothing leaves the plans as they are
    bytes = added == 0 ? 0 : _merge_additions!(store, inds, additions)
    push!(_layer_records!(pop), _layer_record(layer, name, seed, added, ids, shortfall))
    return bytes
end

# How many rows got a setting, and the range of their setting ids (`nothing` if none did).
function _added_entries(additions::_PlanAdditions)
    n, lo, hi = 0, typemax(Int32), typemin(Int32)
    for sid in additions.sids
        sid == DEFAULT_SETTING_ID && continue
        n += 1
        lo, hi = min(lo, sid), max(hi, sid)
    end
    return n, n == 0 ? nothing : (lo, hi)
end

# The layers' names: their own, else "<Type>[k]" for the k-th layer of that type, counting the
# `recorded` ones. Errors on a name used twice, here or among the recorded layers.
function _layer_names(layers, recorded::Vector{Dict{String, Any}})
    names = String[r["name"] for r in recorded]
    for (k, layer) in enumerate(layers)
        T = _layer_type(layer)
        n = count(r -> r["type"] == setting_type_name(T), recorded) + count(l -> _layer_type(l) === T, layers[1:k])
        name = something(layer.name, "$(setting_type_name(T))[$n]")
        name in names && throw(ArgumentError("two setting layers are named \"$name\"; names must be unique"))
        push!(names, name)
    end
    return names[(length(recorded) + 1):end]
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

# the uniform number an individual's participation probability is compared with
_draw_participation(rng::Xoshiro) = gems_rand(rng)

_draw_entries(::Xoshiro, n::Int) = n
_draw_entries(rng::Xoshiro, d::Distribution) = round(Int, _rand_val(d, rng))

function _draw_scale(rng::Xoshiro, d::Distribution)
    s = _rand_val(d, rng)
    s <= floatmax(Float16) || throw(ArgumentError(
        "a `scale` of $s was drawn from $d; scales are at most $(floatmax(Float16))"))
    return Float16(s)
end

# The scales of `n` rows: one drawn per row, one for all, or `nothing` when every scale is 1.
_draw_scales(s::Float64, ::Int, ::Xoshiro) = s == 1 ? nothing : Float16(s)
_draw_scales(d::Distribution, n::Int, rng::Xoshiro) = Float16[_draw_scale(rng, d) for _ in 1:n]

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
        u = _draw_participation(streams.participation)
        n = _draw_entries(streams.entries, layer.entries)
        _qualifies(layer, store, ind) || continue
        u < _participation(layer.participation, ind) || continue
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
    scales = _draw_scales(layer.scale, n, streams.scale)
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

###
### RECORDS
###

# where a population keeps its layers' records
const _LAYER_RECORDS_KEY = "setting_layers"

# The layers recorded on the population, empty if there are none.
_layer_records(pop::Population) = get(pop.params, _LAYER_RECORDS_KEY, Dict{String, Any}[])::Vector{Dict{String, Any}}

# As `_layer_records`, stored on first use so records can be added.
_layer_records!(pop::Population) =
    get!(() -> Dict{String, Any}[], pop.params, _LAYER_RECORDS_KEY)::Vector{Dict{String, Any}}

"""
    _layer_record(layer::SettingLayer, name::String, seed::Integer, added::Int, ids, shortfall::Int)

What the population keeps about an applied layer: its name, setting type, parameters as text,
seed, entries added and left out, and for new settings their id range `ids`.
"""
function _layer_record(layer::SettingLayer, name::String, seed::Integer, added::Int, ids, shortfall::Int)
    record = Dict{String, Any}("name" => name, "type" => setting_type_name(_layer_type(layer)),
        "description" => _layer_description(layer), "seed" => seed,
        "entries" => added, "shortfall" => shortfall)
    if layer.assignment isa NewSettingsAssignment && ids !== nothing
        record["first_id"], record["last_id"] = ids
    end
    return record
end

# Moves the recorded id ranges along when building the settings renumbered a type's ids;
# `renaming[T]` maps a type's old ids to its new ones, as `settings_from_population` returns it.
function _rename_layer_records!(pop::Population, renaming::AbstractDict)
    for record in _layer_records(pop)
        haskey(record, "first_id") || continue
        new_ids = get(renaming, _registered_setting_type(record["type"]), nothing)
        new_ids === nothing && continue
        record["first_id"], record["last_id"] = new_ids[record["first_id"]], new_ids[record["last_id"]]
    end
    return pop
end

# The layer's parameters as text, field by field, leaving out those at their defaults.
_layer_description(layer::SettingLayer) = _field_descriptions(layer, (:name,))

# "f = value" for each of `x`'s fields but `skip`, by `_describe`, leaving out those it gives `nothing`.
function _field_descriptions(x, skip = ())
    parts = String[]
    for f in fieldnames(typeof(x))
        f in skip && continue
        text = _describe(getfield(x, f))
        text === nothing || push!(parts, f === :assignment ? text : "$f = $text")
    end
    return join(parts, ", ")
end

# a field's value as text: setting types by name, an assignment with its own fields
_describe(x) = string(x)
_describe(a::LayerAssignment) = "$(nameof(typeof(a)))($(_field_descriptions(a)))"
_describe(t::UInt8) = setting_type_name(setting_type_from_index(t))
_describe(ts::Vector{UInt8}) = isempty(ts) ? nothing : "[" * join(_describe.(ts), ", ") * "]"
# an `eligible` or `participation` function the ELIGIBILITY AND PARTICIPATION section doesn't describe
_describe(::Function) = "custom"
