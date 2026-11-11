###
### SETTING TYPES
###
export settingchar, settingstring, setting_type_names
export setting_type_index, setting_type_from_index, register_setting_type!, declare_setting_type!

###
### SETTING UTILS
###
# The log chars of the built-in types, and those `register_setting_type!` recorded for the others.
const BUILTIN_SETTING_CHARS = ('h', 'm', 's', 'w', 'g', 'c', 'x', 'y', 'd', 'o', 'p')
const SETTING_TYPE_CHARS = Dict{DataType, Char}()

"""
    settingchar(setting::Setting)

Returns a character that represents the type of setting, or `'?'` for a type that isn't
registered. The infection log also marks seed infections with `'?'`.
"""
function settingchar(setting::Setting)::Char
    # a registered custom type's char, '?' for an unregistered one
    return get(SETTING_TYPE_CHARS, typeof(setting), '?')
end
function settingchar(household::Household)::Char
    return 'h'
end
function settingchar(municipality::Municipality)::Char
    return 'm'
end
function settingchar(school::School)::Char
    return 's'
end
function settingchar(workplace::Workplace)::Char
    return 'w'
end
function settingchar(globalsetting::GlobalSetting)::Char
    return 'g'
end
function settingchar(sc::SchoolClass)::Char
    return 'c'
end
function settingchar(globalsetting::SchoolComplex)::Char
    return 'x'
end
function settingchar(globalsetting::SchoolYear)::Char
    return 'y'
end
function settingchar(department::Department)::Char
    return 'd'
end
function settingchar(office::Office)::Char
    return 'o'
end
function settingchar(workplaceSite::WorkplaceSite)::Char
    return 'p'
end
"""
    settingstring(c::Char)

Returns a string that represents the type of setting based on a char that is returned from
the function `settingchar`, or `"Unknown"` for a char no registered type has.
"""
function settingstring(c::Char)::String
    if c == 'h'
        return "Household"
    elseif c == 's'
        return "School"
    elseif c == 'c'
        return "Schoolclass"
    elseif c == 'x'
        return "Schoolcomplex"
    elseif c == 'y'
        return "Schoolyear"
    elseif c == 'w'
        return "Workplace"
    elseif c == 'p'
        return "WorkplaceSite"
    elseif c == 'd'
        return "Department"
    elseif c == 'o'
        return "Office"
    elseif c == 'm'
        return "Municipality"
    elseif c == 'g'
        return "GlobalSetting"
    else
        # a custom type's char, as `register_setting_type!` recorded it
        for (T, tc) in SETTING_TYPE_CHARS
            tc == c && return setting_type_name(T)
        end
        return "Unknown"
    end
end

"""
    setting_type_names()

Returns every registered setting type's log char, as a string, mapped to its name as `settingstring`
gives it. String keys keep the map hashable and exportable with the results.
"""
setting_type_names() = Dict{String, String}(string(c) => settingstring(c)
    for c in Iterators.flatten((BUILTIN_SETTING_CHARS, values(SETTING_TYPE_CHARS))))

###
### DENSE SETTING-TYPE INDEX
###

"""
    setting_type_index(::Type{T}) where {T<:Setting}

Returns the dense index identifying a setting type, so a `PlanEntry` can name one without
storing a `DataType`. Built-in types resolve to a compile-time constant.
"""
function setting_type_index end

"""
    setting_type_from_index(idx::Integer)

Returns the setting type an index refers to. Inverse of `setting_type_index`.
"""
function setting_type_from_index end

for (i, T) in enumerate(BUILTIN_SETTING_TYPES)
    @eval @inline setting_type_index(::Type{$T}) = $(UInt8(i))
end

const _N_BUILTIN_SETTING_TYPES = UInt8(length(BUILTIN_SETTING_TYPES))

# indices for user types, numbered past the built-ins so a built-in's never shifts
const EXTRA_SETTING_TYPE_INDEX = Dict{DataType, UInt8}()
const EXTRA_SETTING_TYPES = DataType[]

const MEMBERSHIP_MASK_BITS = 8 * sizeof(fieldtype(Individual, :membership_mask))

# Whether a type's settings can sit in a plan; only those get a membership-mask bit.
_holds_entries(::Type{T}) where {T<:Setting} = T <: IndividualSetting && T !== GlobalSetting

# Each type's bit in the membership mask by type index, 0 for none. Slots ascend with the type
# index, since a bit's rank is its entries' offset in the plan block.
const MASK_SLOTS = let n = 0
    UInt8[_holds_entries(T) ? (n += 1) : 0 for T in BUILTIN_SETTING_TYPES]
end

"""
    _mask_slot(tidx::UInt8)

Returns the membership-mask slot of the setting type with index `tidx`, or `0` if it has none.
"""
@inline _mask_slot(tidx::UInt8) = @inbounds MASK_SLOTS[tidx]

# guards the registry's writes; a type first used inside a threaded phase registers there
const SETTING_TYPE_LOCK = ReentrantLock()

"""
    register_setting_type!(::Type{T}; char::Union{Nothing, Char} = nothing) where {T<:Setting}

Assigns `T` a dense setting-type index and the char its infections are logged with, by default
the upper-case first letter of its name, and returns the index. Types register on first use, so
this is only needed to pick the char.
"""
function register_setting_type!(::Type{T}; char::Union{Nothing, Char} = nothing) where {T<:Setting}
    T in BUILTIN_SETTING_TYPES_SET && return setting_type_index(T)
    return lock(SETTING_TYPE_LOCK) do
        idx = get(EXTRA_SETTING_TYPE_INDEX, T, UInt8(0))
        if idx != 0
            (char === nothing || char == SETTING_TYPE_CHARS[T]) || throw(ArgumentError(
                "$T is already registered with char '$(SETTING_TYPE_CHARS[T])'"))
            return idx
        end
        name = setting_type_name(T)
        other = _registered_setting_type(name)
        other === nothing || throw(ArgumentError(
            "cannot register $T: $other is already registered as setting type \"$name\""))
        c = char === nothing ? uppercase(first(name)) : char
        _check_setting_char(c, name)
        length(EXTRA_SETTING_TYPES) < typemax(UInt8) - Int(_N_BUILTIN_SETTING_TYPES) ||
            error("no dense setting-type index left for $T; at most $(typemax(UInt8)) setting types are supported")
        next = maximum(MASK_SLOTS) + 1
        push!(MASK_SLOTS, _holds_entries(T) && next <= MEMBERSHIP_MASK_BITS ? next : 0)
        push!(EXTRA_SETTING_TYPES, T)
        new_idx = _N_BUILTIN_SETTING_TYPES + UInt8(length(EXTRA_SETTING_TYPES))
        EXTRA_SETTING_TYPE_INDEX[T] = new_idx
        SETTING_TYPE_CHARS[T] = c
        return new_idx
    end
end

# Refuses a char another setting type is logged with, and '?', which marks seeds and
# unregistered types.
function _check_setting_char(c::Char, name::AbstractString)
    c == '?' && throw(ArgumentError(
        "'?' marks seeds and unregistered types; give setting type \"$name\" another `char`"))
    holder = get(setting_type_names(), string(c), nothing)
    holder === nothing || throw(ArgumentError(
        "setting type \"$name\" would be logged as '$c', which $holder already is; give it another `char`"))
    return nothing
end

function setting_type_index(::Type{T}) where {T<:Setting}
    idx = get(EXTRA_SETTING_TYPE_INDEX, T, UInt8(0))
    idx == 0 && error("$T has no setting-type index; register it with `add_type!` first")
    return idx
end

function setting_type_from_index(idx::Integer)
    i = UInt8(idx)
    i <= _N_BUILTIN_SETTING_TYPES && return BUILTIN_SETTING_TYPES[Int(i)]
    extra = Int(i) - Int(_N_BUILTIN_SETTING_TYPES)
    1 <= extra <= length(EXTRA_SETTING_TYPES) ||
        throw(ArgumentError("no setting type registered for index $idx"))
    return EXTRA_SETTING_TYPES[extra]
end

# `T`'s rank among `cntnr`'s types, which orders same-tick infections whatever was registered before.
@inline function _type_rank(cntnr::SettingsContainer, ::Type{T})::UInt8 where {T<:Setting}
    t = setting_type_index(T)
    return t <= _N_BUILTIN_SETTING_TYPES ? t : @inbounds cntnr.type_ranks[t]
end

# Ranks `cntnr`'s types after one is added: built-ins keep their index, the others follow in name order.
function _rank_types!(cntnr::SettingsContainer)
    others = sort!([T for T in keys(cntnr.settings) if T <: Setting && !(T in BUILTIN_SETTING_TYPES_SET)];
                   by = setting_type_name)
    ranks = cntnr.type_ranks
    isempty(others) && return ranks
    n = maximum(T -> Int(setting_type_index(T)), others)
    length(ranks) < n && append!(ranks, zeros(UInt8, n - length(ranks)))
    for (k, T) in enumerate(others)
        ranks[setting_type_index(T)] = _N_BUILTIN_SETTING_TYPES + UInt8(k)
    end
    return ranks
end

"""
    setting_type_name(::Type{T}) where {T<:Setting}

Returns the name configs, membership files and results use for setting type `T`.
"""
setting_type_name(::Type{T}) where {T<:Setting} = string(nameof(T))

# The registered setting type called `name`, or `nothing`.
function _registered_setting_type(name::AbstractString)
    for T in BUILTIN_SETTING_TYPES
        setting_type_name(T) == name && return T
    end
    for T in EXTRA_SETTING_TYPES
        setting_type_name(T) == name && return T
    end
    return nothing
end

# The setting type called `name`, or `nothing`: a registered one, else the concrete
# `IndividualSetting` subtype of that name, registered on the way with `char`.
function _resolve_setting_type(name::AbstractString; char::Union{Nothing, Char} = nothing)
    T = _registered_setting_type(name)
    T === nothing || return T
    found = filter(S -> setting_type_name(S) == name, _concrete_subtypes(IndividualSetting))
    isempty(found) && return nothing
    length(found) == 1 || throw(ArgumentError(
        "several setting types are called \"$name\" ($(join(found, ", "))); register the one to use"))
    register_setting_type!(only(found); char = char)
    return only(found)
end

"""
    declare_setting_type!(name::AbstractString; char::Union{Nothing, Char} = nothing)

Declares the setting type `DeclaredSetting{Symbol(name)}`, registered with `char` as
`register_setting_type!` does, and returns it. Errors if another type already has that name.
"""
function declare_setting_type!(name::AbstractString; char::Union{Nothing, Char} = nothing)
    T = DeclaredSetting{Symbol(name)}
    other = _registered_setting_type(name)
    if other === nothing
        structs = filter(S -> setting_type_name(S) == name, _concrete_subtypes(IndividualSetting))
        isempty(structs) || (other = first(structs))
    end
    (other === nothing || other === T) || throw(ArgumentError(
        "cannot declare setting type \"$name\": $other already has that name"))
    register_setting_type!(T; char = char)
    return T
end

