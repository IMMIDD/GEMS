###
### SETTING LAYERS
### Activity-plan entries generated from parameters and added to a population's plans.
###

# EXPORTS
export SettingLayer
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

# numbers are stored as Float64 so a layer's fields stay concrete
_layer_value(x::Real) = Float64(x)
_layer_value(x) = x

"""
    _check_assignment(a::LayerAssignment)

Throws an `ArgumentError` if an assignment's parameters are out of range.
"""
_check_assignment(a::NewSettingsAssignment) = _check_positive(a.size, "`size`"; finite_mean = true)
_check_assignment(a::SpatialSettings) =
    (_check_positive(a.size, "`size`"; finite_mean = true); _check_positive(a.spread, "`spread`"))
_check_assignment(::JoinExisting) = nothing
_check_assignment(a::JoinNearby) = _check_positive(a.spread, "`spread`")

# Throws unless `x` is a finite number > 0 or a non-negative distribution, with a finite
# positive mean if `finite_mean`.
function _check_positive(x, what::AbstractString; finite_mean::Bool = false)
    ok = x isa Real ? isfinite(x) && x > 0 :
        x isa UnivariateDistribution && minimum(x) >= 0 && (!finite_mean || (isfinite(mean(x)) && mean(x) > 0))
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

Rules for giving individuals entries of setting type `T`, checked here.

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
    _check_holds_entries(T, "a layer's setting type")
    n = entries isa Integer ? Int(entries) : entries
    s = _layer_value(scale)
    layer = SettingLayer{T, typeof(assignment), typeof(eligible), typeof(n), typeof(s)}(
        name === nothing ? nothing : String(name), assignment, eligible,
        _layer_type_indices(holding, "`holding`"), _layer_type_indices(not_holding, "`not_holding`"),
        Float64(participation), n, s)
    _check_layer(layer)
    register_setting_type!(T)
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
    (n isa Int ? 0 <= n <= cap : minimum(n) >= 0 && (!isfinite(maximum(n)) || maximum(n) <= cap)) ||
        throw(ArgumentError("`entries` must be in 0-$cap, or a non-negative distribution at most $cap if bounded; got $n"))
    s = layer.scale
    (s isa Real ? 0 <= s <= floatmax(Float16) : minimum(s) >= 0) ||
        throw(ArgumentError("`scale` must be in [0, $(floatmax(Float16))] or a non-negative distribution; got $s"))
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
    # the k-th field's stream is keyed on k
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
        (takes_part && _layer_eligible(layer, store, ind)) || continue
        counts[i] = min(n, typemax(UInt8))
    end
    return counts
end

# Whether `ind` is eligible and holds every type in `holding` and none in `not_holding`.
function _layer_eligible(layer::SettingLayer, store::ActivityPlanStore, ind::Individual)
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
