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
