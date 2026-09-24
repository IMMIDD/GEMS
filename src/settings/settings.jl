###
### SETTINGS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
import Base.contains
export Setting, Geolocated, IndividualSetting, ContainerSetting
export GlobalSetting, Household, Municipality, Setting
export SchoolComplex, School, SchoolYear, SchoolClass
export Department, Office, WorkplaceSite, Workplace
export settingchar, settingstring
export ContactSamplingMethod, contact_sampling_method, contact_sampling_method!
export add!, remove!
export add_member!, remove_member!, mark_deceased!
export id, individuals
export open!, close!

###
### ABSTRACT TYPES
###
"""
Supertype for all simulation settings
"""
abstract type Setting end

#TODO decide whether we need geolocations in settings during the simulation

"""
Supertype for all simulation settings which directly contain individuals.
"""
abstract type IndividualSetting <: Setting end

"""
Supertype for all simulation settings which directly contain individuals and are geolocated.
"""
abstract type Geolocated <: IndividualSetting end

"""
Supertype for all simulation settings which act as containers of settings.
"""
abstract type ContainerSetting <: Setting end

"""
    ContactSamplingMethod

Supertype for all contact sampling methods. This type is intended to be extended by providing different sampling methods suitable for the structure of the simulation model.

Implement `sample_contacts!` for your subtype. Its `present_inds` argument is a view of the
setting's real members, not a scratch buffer: writing to it edits membership. Read only, and
write results into `indivs`.

Simulations often keep only a share of the sampled contacts. Optionally implement
`sample_thinned_contacts!` to skip the dropped ones before drawing them.
"""
abstract type ContactSamplingMethod end

###
### GLOBALSETTING
###
"""
    GlobalSetting <: IndividualSetting

A type to a setting that contains all individuals at once (mainly for testing purposes).
With this type, each individual can theoretically connect with any other individual.

There should only be one `GlobalSetting` instance in any simulation.

# Fields

- `individuals::Vector{Individual}`: List of associated individuals
- `contact_sampling_method::ContactSamplingMethod`: Sampling Method, defining how contacts are drawn.
- `isopen::Bool`: Whether the setting is open for contacts.
    conditions
- `flat_pool`, `offset`, `len`, `cap` *(internal)*: The members are `flat_pool.members[offset:(offset + len - 1)]`,
    in `cap` slots of that pool.
"""
mutable struct GlobalSetting <: IndividualSetting
    id::Int32 # ONLY ONE GLOBALSETTING SHOULD EXIST!!!
    # this setting's slots of flat_pool.members, its members in the first len
    offset::Int32
    len::Int32
    cap::Int32
    flat_pool::FlatSettingPool
    contact_sampling_method::ContactSamplingMethod
    ags::AGS # 4 bytes

    # if closed, no contacts can happen here
    isopen::Bool
end

function GlobalSetting(; id = GLOBAL_SETTING_ID, individuals = nothing, flat_pool = nothing, offset = 1, len = 0,
        cap = len, contact_sampling_method::ContactSamplingMethod, ags = AGS(), isopen = true)
    flat_pool, offset, len, cap = _flat_storage(individuals, flat_pool, offset, len, cap)
    return GlobalSetting(id, offset, len, cap, flat_pool, contact_sampling_method, ags, isopen)
end

###
### HOUSEHOLDS
###
"""
    Household <: Geolocated

A type to represent households with associated individuals as members.

# Instantiation

The instantiation requires at least an `id` that be supplied
as a keyword argument. All other fields are optional parameters.

```julia
h1 = Household(id = 1)
h2 = Household(id = 2, individuals = [i1, i2, i3])
```

# Parameters

- `id::Int32`: Unique identifier of the household
- `individuals::Vector{Individual} = []` *(optional)*: List of associated individuals
- `income::Int8 = -1` *(optional)*: Category of income for the household
- `dwelling::Int8 = -1  *(optional)*`: Category of dwelliung size
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `ags::AGS = AGS()` *(optional)*: The Amtlicher Gemeindeschlüssel (AGS) of the Household.
- `lon::Float32 = NaN` *(optional)*: Longitude of the household
- `lat::Float32 = NaN`: Latitude of the household
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `flat_pool`, `offset`, `len`, `cap` *(internal)*: The members are `flat_pool.members[offset:(offset + len - 1)]`,
    in `cap` slots of the pool all households share.
- `scale_bound` *(internal)*: Upper bound on its members' scales.
- `deceased` *(internal)*: How many members at the end of `individuals` have died.
"""
mutable struct Household <: Geolocated
    # ordered so the object stays at 56 bytes, in the 64-byte size class
    id::Int32
    # this setting's slots of flat_pool.members, its members in the first len
    offset::Int32
    len::Int32
    cap::Int32
    # members at the end of `individuals` who have died
    deceased::Int32
    ags::AGS
    flat_pool::FlatSettingPool
    contact_sampling_method::ContactSamplingMethod
    lon::Float32
    lat::Float32
    # upper bound on its members' scales
    scale_bound::Float32
    income::Int8
    dwelling::Int8

    # if closed, no contacts can happen here
    isopen::Bool
end

function Household(; id, individuals = nothing, flat_pool = nothing, offset = 1, len = 0, cap = len, income = -1,
        dwelling = -1, contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0), ags = AGS(),
        lon = NaN, lat = NaN, isopen = true, scale_bound = 1, deceased = 0)
    flat_pool, offset, len, cap = _flat_storage(individuals, flat_pool, offset, len, cap)
    return Household(id, offset, len, cap, deceased, ags, flat_pool, contact_sampling_method, lon, lat, scale_bound,
        income, dwelling, isopen)
end

###
### MUNICIPALITY
###
"""
    Municipality <: IndividualSetting
    
A type to represent (geographical) municipalities.

# Instantiation

The instantiation requires at least an `id` that be supplied
as a keyword argument. All other fields are optional parameters.

```julia
m1 = Municipality(id = 1)
m2 = Municipality(id = 2, individuals = [i1, i2, i3])
```

# Parameters

- `id::Int32`: Unique identifier of the municipality
- `individuals::Vector{Individual} = []` *(optional)*: List of associated individuals
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*: Sampling Method, defining how contacts are drawn.
- `ags::AGS = AGS()` *(optional)*: The Amtlicher Gemeindeschlüssel (AGS) of the municipality.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `flat_pool`, `offset`, `len`, `cap` *(internal)*: The members are `flat_pool.members[offset:(offset + len - 1)]`,
    in `cap` slots of the pool all municipalities share.
- `scale_bound` *(internal)*: Upper bound on its members' scales.
- `deceased` *(internal)*: How many members at the end of `individuals` have died.
"""
mutable struct Municipality <: IndividualSetting
    id::Int32 # 4 bytes // Municipality identifier
    # this setting's slots of flat_pool.members, its members in the first len
    offset::Int32
    len::Int32
    cap::Int32
    flat_pool::FlatSettingPool
    contact_sampling_method::ContactSamplingMethod
    ags::AGS # 4 bytes
    # if closed, no contacts can happen here
    isopen::Bool

    # upper bound on its members' scales
    scale_bound::Float32
    # members at the end of `individuals` who have died
    deceased::Int32
end

function Municipality(; id, individuals = nothing, flat_pool = nothing, offset = 1, len = 0, cap = len,
        contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0), ags = AGS(), isopen = true,
        scale_bound = 1, deceased = 0)
    flat_pool, offset, len, cap = _flat_storage(individuals, flat_pool, offset, len, cap)
    return Municipality(id, offset, len, cap, flat_pool, contact_sampling_method, ags, isopen, scale_bound, deceased)
end

# The settings no container holds. Each keeps its members in slots of its type's FlatSettingPool.
const FlatSetting = Union{GlobalSetting, Household, Municipality}

# What a flat setting's keyword constructor stores: its own `individuals` in a pool of their own,
# or slots of a shared pool.
function _flat_storage(individuals, flat_pool, offset, len, cap)
    if flat_pool === nothing
        pool = FlatSettingPool(individuals === nothing ? Individual[] : individuals)
        return pool, 1, length(pool.members), length(pool.members)
    end
    individuals === nothing || throw(ArgumentError("pass either `individuals` or `flat_pool`, not both"))
    return flat_pool, offset, len, cap
end

# The default would print the whole pool
Base.show(io::IO, s::FlatSetting) = print(io, nameof(typeof(s)), "(id = ", id(s), ", ", s.len, " individuals)")

###
### SCHOOLCLASS
###

"""
    SchoolClass <: Geolocated

A type to represent school classes. Should always be part of a school.

# Instantiation

The instantiation requires at least an `id` that be supplied
as a keyword argument. All other fields are optional parameters.

```julia
c1 = SchoolClass(id = 1)
c2 = SchoolClass(id = 2, individuals = [i1, i2, i3])
```

# Parameters

- `id::Int32`: Unique identifier of the school class
- `type::Int32 = -1` *(optional)*: Type of school class (e.g. grade)
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*: Parent setting id (`SchoolYear`)
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `ags::Int32 = AGS()` *(optional)*: The Amtlicher Gemeindeschlüssel (AGS) of the schoolclass.
- `lon::Float32 = NaN` *(optional)*: Longitude of the schoolclass
- `lat::Float32 = NaN` *(optional)*: Latitude of the schoolclass
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage. Members are held there rather
    than in this setting, so its containers can address them without a copy.
- `pool_offset`, `pool_length` *(internal)*: Where this setting's members sit in that pool.
    `individuals(s)` is a view of exactly that span.
- `pool_leaf` *(internal)*: This setting's index in `pool.leaves`, which is how a member edit
    finds the block it has to dirty.
- `individuals::Vector{Individual} = []` *(optional)*: The members, held here until the pool is built
    and while an edit waits for a repack, `nothing` otherwise. Read them with `individuals(s)`.
- `scale_bound` *(internal)*: Upper bound on its members' scales.
- `deceased` *(internal)*: How many members at the end of `individuals` have died.
"""
@with_kw mutable struct SchoolClass <: Geolocated
    id::Int32 # 4 bytes
    type::Int32 = -1 # 1 byte
    contained::Int32 = DEFAULT_SETTING_ID # 4 bytes
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS= AGS() # 4 bytes
    lon::Float32 = NaN # 4 bytes
    lat::Float32 = NaN # 4 bytes

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's HierarchicalSettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    # index in pool.leaves, so an edit finds the block it dirties without a search
    pool_leaf::Int32 = 0
    # the members until the pool is built, or while an edit waits for a repack; nothing otherwise
    individuals::Union{Nothing, Vector{Individual}} = Vector{Individual}()
    pool::Union{Nothing, HierarchicalSettingPool} = nothing
    # upper bound on its members' scales
    scale_bound::Float32 = 1
    # members at the end of `individuals` who have died
    deceased::Int32 = 0

end

###
### SCHOOL YEAR
###

"""
    SchoolYear <: ContainerSetting

A type to represent a schoolyear (which has classes).

# Instantiation

The instantiation requires at least an `id` that be supplied
as a keyword argument. All other fields are optional parameters.

```julia
y1 = SchoolYear(id = 1)
y2 = SchoolYear(id = 2, contains = [13, 14, 15]) # contains IDs of school classes
```

# Parameters

- `id::Int32`: Unique identifier of the schoolyear
- `contains::Vector{Int32} = []` *(optional)*: List of associated `SchoolClass`es
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*:  Parent setting id (`School`)
- `type::Int32 = -1` *(optional)*: Type of school year (e.g. grade)
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*: Sampling Method, defining how contacts are drawn.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
- `pool_runs` *(internal)*: The frame when a member sits in two leaves below or something
    below is closed or deceased, `nothing` when the span already covers each present member once.
- `scale_bound` *(internal)*: Upper bound on the scales of the members below.
"""
@with_kw mutable struct SchoolYear <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contained::Int32 = DEFAULT_SETTING_ID
    type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's HierarchicalSettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    # set when a member sits in two leaves below or something below is closed or deceased
    pool_runs::Union{Nothing, MemberRuns} = nothing
    pool::Union{Nothing, HierarchicalSettingPool} = nothing
    # upper bound on the scales of the members below, refreshed with the span
    scale_bound::Float32 = 1

end

###
### SCHOOL
###
"""
    School <: ContainerSetting

A type to represent a school (which has years and classes).

# Instantiation

The instantiation requires at least an `id` that be supplied
as a keyword argument. All other fields are optional parameters.

```julia
s1 = School(id = 1)
s2 = School(id = 2, contains = [13, 14, 15]) # contains IDs of school years
```

# Parameters

- `id::Int32`: Unique identifier of the school
- `contains::Vector{Int32} = []` *(optional)*: List of associated `SchoolYears`s
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*:  Parent setting id (`SchoolComplex`)
- `type::Int32 = -1` *(optional)*: Type of school (e.g. primary, highschool, ...)
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*: Sampling Method, defining how contacts are drawn.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
- `pool_runs` *(internal)*: The frame when a member sits in two leaves below or something
    below is closed or deceased, `nothing` when the span already covers each present member once.
- `scale_bound` *(internal)*: Upper bound on the scales of the members below.
"""
@with_kw mutable struct School <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contained::Int32 = DEFAULT_SETTING_ID
    type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()
    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's HierarchicalSettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    # set when a member sits in two leaves below or something below is closed or deceased
    pool_runs::Union{Nothing, MemberRuns} = nothing
    pool::Union{Nothing, HierarchicalSettingPool} = nothing
    # upper bound on the scales of the members below, refreshed with the span
    scale_bound::Float32 = 1

end

###
### SCHOOL COMPLEX
###
"""
    SchoolComplex <: ContainerSetting

A type to represent a school complex (which has schools).

# Instantiation

The instantiation requires at least an `id` that be supplied
as a keyword argument. All other fields are optional parameters.

```julia
sc1 = SchoolComplex(id = 1)
sc2 = SchoolComplex(id = 2, contains = [13, 14, 15]) # contains IDs of schools
```

# Parameters

- `id::Int32`: Unique identifier of the school complex
- `contains::Vector{Int32} = []` *(optional)*: List of associated `School`s
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*: Sampling Method, defining how contacts are drawn.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
- `pool_runs` *(internal)*: The frame when a member sits in two leaves below or something
    below is closed or deceased, `nothing` when the span already covers each present member once.
- `scale_bound` *(internal)*: Upper bound on the scales of the members below.
"""
@with_kw mutable struct SchoolComplex <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
     type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's HierarchicalSettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    # set when a member sits in two leaves below or something below is closed or deceased
    pool_runs::Union{Nothing, MemberRuns} = nothing
    pool::Union{Nothing, HierarchicalSettingPool} = nothing
    # upper bound on the scales of the members below, refreshed with the span
    scale_bound::Float32 = 1

end

###
### WORKPLACE
###

"""
    WorkplaceSite <: ContainerSetting

Represents a Workplace site in the simulation.

# Instantiation

The instantiation requires at least an `id` that be supplied
as a keyword argument. All other fields are optional parameters.

```julia
ws1 = WorkplaceSite(id = 1)
ws2 = WorkplaceSite(id = 2, contains = [13, 14, 15]) # contains IDs of Workplaces
```

# Parameters

- `id::Int32`: Unique identifier of the workplace.
- `contains::Vector{Int32} = []` *(optional)*: List of associated `Workplace`s
- `type::Int32 = -1` *(optional)*: Numerical code representing the type of workplace site.
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*: Sampling Method, defining how contacts are drawn.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
- `pool_runs` *(internal)*: The frame when a member sits in two leaves below or something
    below is closed or deceased, `nothing` when the span already covers each present member once.
- `scale_bound` *(internal)*: Upper bound on the scales of the members below.
"""
@with_kw mutable struct WorkplaceSite <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's HierarchicalSettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    # set when a member sits in two leaves below or something below is closed or deceased
    pool_runs::Union{Nothing, MemberRuns} = nothing
    pool::Union{Nothing, HierarchicalSettingPool} = nothing
    # upper bound on the scales of the members below, refreshed with the span
    scale_bound::Float32 = 1

end

"""
    Workplace <: ContainerSetting

Represents a workplace in the simulation.

# Instantiation

The instantiation requires at least an `id` that be supplied
as a keyword argument. All other fields are optional parameters.

```julia
ws1 = Workplace(id = 1)
ws2 = Workplace(id = 2, contains = [13, 14, 15]) # contains IDs of Departments
```

# Parameters

- `id::Int32`: Unique identifier of the workplace.
- `contains::Vector{Int32} = []` *(optional)*: List of associated `Department`s
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*: Parent setting id (`WorkplaceSite`)
- `type::Int32 = -1` *(optional)*: Numerical code representing the type of workplace (e.g., farm, office).
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
- `pool_runs` *(internal)*: The frame when a member sits in two leaves below or something
    below is closed or deceased, `nothing` when the span already covers each present member once.
- `scale_bound` *(internal)*: Upper bound on the scales of the members below.
"""
@with_kw mutable struct Workplace <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contained::Int32 = DEFAULT_SETTING_ID
    type::Int32 = -1 # 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()
    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's HierarchicalSettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    # set when a member sits in two leaves below or something below is closed or deceased
    pool_runs::Union{Nothing, MemberRuns} = nothing
    pool::Union{Nothing, HierarchicalSettingPool} = nothing
    # upper bound on the scales of the members below, refreshed with the span
    scale_bound::Float32 = 1

end

"""
    Department <: ContainerSetting

Represents a department within a workplace in the simulation.

# Instantiation

The instantiation requires at least an `id` that be supplied
as a keyword argument. All other fields are optional parameters.

```julia
d1 = Department(id = 1)
d2 = Department(id = 2, contains = [13, 14, 15]) # contains IDs of Offices
```

# Parameters

- `id::Int32`: Unique identifier of the department.
- `contains::Vector{Int32} = []` *(optional)*: List of associated `Office`s
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*: Parent setting id (`Workplace`)
- `type::Int32 = -1` *(optional)*: Numerical code representing the type of department.
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
- `pool_runs` *(internal)*: The frame when a member sits in two leaves below or something
    below is closed or deceased, `nothing` when the span already covers each present member once.
- `scale_bound` *(internal)*: Upper bound on the scales of the members below.
"""
@with_kw mutable struct Department <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contained::Int32 = DEFAULT_SETTING_ID
    type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    
    
    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's HierarchicalSettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    # set when a member sits in two leaves below or something below is closed or deceased
    pool_runs::Union{Nothing, MemberRuns} = nothing
    pool::Union{Nothing, HierarchicalSettingPool} = nothing
    # upper bound on the scales of the members below, refreshed with the span
    scale_bound::Float32 = 1

end


"""
    Office <: Geolocated    

Represents an office within a department in the simulation.

# Instantiation

The instantiation requires at least an `id` that be supplied
as a keyword argument. All other fields are optional parameters.

```julia
o1 = Office(id = 1)
o2 = Office(id = 2, individuals = [i1, i2, i3])
```

# Parameters

- `id::Int32`: Unique identifier of the office.
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*: Parent setting id (`Department`) 
- `contained_type::DataType = Department` *(optional)*: Parent setting tye (`Department`)
- `type::Int32 = -1` *(optional)*: Numerical code representing the type of office
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn
- `ags::AGS = AGS()` *(optional)*: The Amtlicher Gemeindeschlüssel (AGS) of the office
- `inroom::Int8 = -1` *(optional)*: Describes the amount of indoor work done in the office
- `workhome::Int8 = -1` *(optional)*: Describes the amount of work done from home
- `lon::Float32 = NaN` *(optional)*: Longitude of the office
- `lat::Float32 = NaN` *(optional)*: Latitude of the office
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts
- `pool` *(internal)*: The hierarchy's shared member storage. Members are held there rather
    than in this setting, so its containers can address them without a copy.
- `pool_offset`, `pool_length` *(internal)*: Where this setting's members sit in that pool.
    `individuals(s)` is a view of exactly that span.
- `pool_leaf` *(internal)*: This setting's index in `pool.leaves`, which is how a member edit
    finds the block it has to dirty.
- `individuals::Vector{Individual} = []` *(optional)*: The members, held here until the pool is built
    and while an edit waits for a repack, `nothing` otherwise. Read them with `individuals(s)`.
- `scale_bound` *(internal)*: Upper bound on its members' scales.
- `deceased` *(internal)*: How many members at the end of `individuals` have died.
"""
@with_kw mutable struct Office <: Geolocated
    id::Int32 # 4 bytes
    contained::Int32 = DEFAULT_SETTING_ID
    type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS= AGS() # 4 bytes
    inroom::Int8 = -1 # 1 byte
    workhome::Int8 = -1 # 1 byte
    lon::Float32 = NaN # 4 bytes
    lat::Float32 = NaN # 4 bytes


    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's HierarchicalSettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    # index in pool.leaves, so an edit finds the block it dirties without a search
    pool_leaf::Int32 = 0
    # the members until the pool is built, or while an edit waits for a repack; nothing otherwise
    individuals::Union{Nothing, Vector{Individual}} = Vector{Individual}()
    pool::Union{Nothing, HierarchicalSettingPool} = nothing
    # upper bound on its members' scales
    scale_bound::Float32 = 1
    # members at the end of `individuals` who have died
    deceased::Int32 = 0

end
###
### SETTING UTILS
###
"""
    settingchar(setting::Setting)

Returns a character that represents the type of setting.
"""
function settingchar(setting::Setting)::Char
    # fallback for all unknown Settings
    return '?'
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
the function `settingchar`.
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
        return "Unknown"
    end
end 

###
### GENERAL SETTING INTERFACE
###
#   You can override the functions for different settings, but this is the default behaviour   
#   A Setting should thus have the following fields by default
#       id, individuals, contact_sampling_method, isopen

"""
    id(setting::Setting)

Returns the unique identifier of the setting.
"""
function id(setting::Setting)::Int32
    return setting.id
end

"""
    contact_sampling_method(setting::Setting)

Returns `ContactSamplingMethod` of this setting.
"""
function contact_sampling_method(setting::Setting)
    return setting.contact_sampling_method
end

"""
    contact_sampling_method(setting::Setting, csm::ContactSamplingMethod)

Sets the `ContactSamplingMethod` of this setting to the provided method.
"""
function contact_sampling_method!(setting::Setting, csm::ContactSamplingMethod)
    # deepcopy: settings must not share a mutable sampling-method cache
    setting.contact_sampling_method = deepcopy(csm)
end

"""
    add_member!(setting::IndividualSetting, individual::Individual, pop::Population; primary::Bool = false, scale::Real = 1.0)

Adds the given individual to the setting and the matching entry at `scale` to their activity
plan, as their primary setting of that type if `primary`. Throws if they already belong to it.
Must not be called while the threaded transmission phase is running.
"""
function add_member!(setting::IndividualSetting, individual::Individual, pop::Population; primary::Bool = false, scale::Real = 1.0)
    plans = activity_plans(pop)
    # checked before the member list is touched, so a refusal leaves both sides as they were
    plan_slot(plans, individual, typeof(setting), id(setting)) == 0 || throw(ArgumentError(
        "individual $(id(individual)) is already a member of $(typeof(setting)) $(id(setting))"))
    _store_member!(setting, individual, plans)
    plan_add!(plans, individual,
              PlanEntry(typeof(setting), id(setting), length(individuals(setting)), scale); primary = primary)
    # a newcomer joins the living members, ahead of the deceased
    _deceased(setting) > 0 && _swap_members!(setting, length(individuals(setting)), _alive(setting), plans)
    # the bound must use the scale as rounded into the entry's Float16
    stored = Float32(Float16(scale))
    stored > _scale_bound(setting) && _set_scale_bound!(setting, stored)
    membership_changed!(contact_sampling_method(setting), setting)
    return nothing
end

"""
    remove_member!(setting::IndividualSetting, individual::Individual, pop::Population)

Removes the given individual from the setting and their matching plan entry, or does nothing
if they are not a member. Must not be called while the threaded transmission phase is running.
"""
function remove_member!(setting::IndividualSetting, individual::Individual, pop::Population)
    plans = activity_plans(pop)
    members = individuals(setting)
    idx = findfirst(i -> i === individual, members)
    isnothing(idx) && return nothing
    if _is_deceased(setting, idx)
        _add_deceased!(setting, -1)
    elseif _deceased(setting) > 0
        # swap-with-last would pull a deceased member forward, so move to the last living slot first
        _swap_members!(setting, idx, _alive(setting), plans)
        idx = _alive(setting)
    end
    # the member that swap-with-last will move into `idx`
    displaced = @inbounds members[end]
    _unstore_member!(setting, individual, idx, plans)

    T = typeof(setting)
    sid = id(setting)
    slot = plan_slot(plans, individual, T, sid)
    slot != 0 && plan_remove!(plans, individual, slot)
    if displaced !== individual
        dslot = plan_slot(plans, displaced, T, sid)
        dslot != 0 && plan_set_member_index!(plans, dslot, idx)
    end
    # the removed member may have held the bound
    _scale_bound(setting) > 1 && _refresh_scale_bound!(plans, setting)
    membership_changed!(contact_sampling_method(setting), setting)
    return nothing
end

"""
    mark_deceased!(setting::IndividualSetting, individual::Individual, pop::Population)

Takes a member out of the setting's contacts but keeps the membership. Does nothing if they
are not a member or have already been marked.
"""
function mark_deceased!(setting::T, individual::Individual, pop::Population) where {T<:IndividualSetting}
    hasfield(T, :deceased) || return nothing
    plans = activity_plans(pop)
    _check_indexed(plans)
    slot = plan_slot(plans, individual, T, id(setting))
    slot == 0 && return nothing
    idx = Int(member_index(@inbounds plans.entries[slot]))
    _is_deceased(setting, idx) && return nothing
    _swap_members!(setting, idx, _alive(setting), plans)
    _add_deceased!(setting, 1)
    # the deceased member may have held the bound
    _scale_bound(setting) > 1 && _refresh_scale_bound!(plans, setting)
    membership_changed!(contact_sampling_method(setting), setting)
    return nothing
end

# Swaps two members and repoints their plan entries.
function _swap_members!(s::T, i::Int, j::Int, plans) where {T<:IndividualSetting}
    i == j && return nothing
    v = individuals(s)
    @inbounds a, b = v[i], v[j]
    @inbounds v[i], v[j] = b, a
    sa = plan_slot(plans, a, T, id(s))
    sa == 0 || plan_set_member_index!(plans, sa, j)
    sb = plan_slot(plans, b, T, id(s))
    sb == 0 || plan_set_member_index!(plans, sb, i)
    return nothing
end

# returns the deceased to the setting's frame, for a simulation that is reset
function _clear_deceased!(s::IndividualSetting, plans)
    _deceased(s) == 0 && return nothing
    _add_deceased!(s, -_deceased(s))
    _refresh_scale_bound!(plans, s)
    membership_changed!(contact_sampling_method(s), s)
    return nothing
end

# changes the deceased count, dirtying the pool so its frames follow
function _add_deceased!(s::IndividualSetting, n::Int)
    s.deceased += Int32(n)
    pool = _pool(s)
    if pool !== nothing
        pool.deceased += n
        _mark_dirty!(pool, s)
    end
    return nothing
end

# The GlobalSetting is the whole population by definition, so its membership is not editable -
# and an individual holds no plan entry for it, since `setting_id` answers from the constant.
add_member!(::GlobalSetting, ::Individual, ::Population; primary::Bool = false, scale::Real = 1.0) =
    throw(ArgumentError("GlobalSetting always holds the entire population; membership cannot be edited"))
remove_member!(::GlobalSetting, ::Individual, ::Population) =
    throw(ArgumentError("GlobalSetting always holds the entire population; membership cannot be edited"))


"""
    contains(setting::ContainerSetting)

Returns the `contains` value of the given `ContainerSetting`.

"""
function contains(setting::ContainerSetting)
    return setting.contains
end

"""
    contains_type(::Type{T}) where {T<:ContainerSetting}

Returns the concrete setting type contained by a `ContainerSetting` of type `T`.
Encoded in the type domain (not stored as a field) so it is recovered by dispatch as a
compile-time constant, enabling type-stable recursion into the contained settings.
"""
contains_type(::Type{SchoolYear}) = SchoolClass
contains_type(::Type{School}) = SchoolYear
contains_type(::Type{SchoolComplex}) = School
contains_type(::Type{Department}) = Office
contains_type(::Type{Workplace}) = Department
contains_type(::Type{WorkplaceSite}) = Workplace

"""
    contains_type(setting::ContainerSetting)

Returns the `contains_type` of the given `ContainerSetting` instance. Forwards to the
type-based trait on `typeof(setting)`.
"""
contains_type(setting::ContainerSetting) = contains_type(typeof(setting))

"""
    contained(setting::Setting)

Returns the `contained` value of the given `Setting`.

"""
function contained(setting::Setting)
    return setting.contained
end

"""
    contained_type(::Type{T}) where {T<:Setting}

Returns the concrete setting type that contains a setting of type `T` (its parent in the
hierarchy). Encoded in the type domain (not stored as a field). Defined only for non-root
types; the root containers (`SchoolComplex`, `WorkplaceSite`) have no parent and no method.
"""
contained_type(::Type{SchoolClass}) = SchoolYear
contained_type(::Type{SchoolYear}) = School
contained_type(::Type{School}) = SchoolComplex
contained_type(::Type{Office}) = Department
contained_type(::Type{Department}) = Workplace
contained_type(::Type{Workplace}) = WorkplaceSite

"""
    contained_type(setting::Setting)

Returns the `contained_type` of the given `Setting` instance. Forwards to the type-based
trait on `typeof(setting)`.
"""
contained_type(setting::Setting) = contained_type(typeof(setting))

# The individual-setting type at the bottom of `T`'s hierarchy, `T` itself for an individual setting.
_leaf_type(::Type{T}) where {T<:IndividualSetting} = T
_leaf_type(::Type{T}) where {T<:ContainerSetting} = _leaf_type(contains_type(T))

"""
    individuals(setting::IndividualSetting)

Returns the individuals associated with the given setting, as a view of wherever they are stored.
"""
function individuals(setting::IndividualSetting)
    v = setting.individuals
    # a view in both cases: a union return would box the view it builds
    v === nothing || return view(v, 1:length(v))
    # a pooled leaf holds no members itself unless an edit detached them
    lo = Int(setting.pool_offset)
    return view((setting.pool::HierarchicalSettingPool).members, lo:(lo + Int(setting.pool_length) - 1))
end

individuals(s::FlatSetting) = view(s.flat_pool.members, _flat_range(s))

# the setting's positions in its flat pool
_flat_range(s::FlatSetting) = Int(s.offset):(Int(s.offset) + Int(s.len) - 1)


Base.size(setting::IndividualSetting) = setting |> individuals |> length


### CREATION OF SETTINGS

"""
    construct_and_add_settings!(container_vec::Vector, pairs::Vector{Tuple{Int32, Int32, Individual}}, settingtype::Type{T}, plans, default_sampling) where {T <: Setting}

Helper function to construct settings from a sorted list of (setting id, plan slot, individual)
triples without dynamic dispatch. Sets each entry's `member_index` and each setting's scale bound
on the way, since pooling keeps a leaf's member order. Returns the `FlatSettingPool` the new
settings share, or `nothing` for a type that is not flat.
"""
function construct_and_add_settings!(
    container_vec::Vector,
    pairs::Vector{Tuple{Int32, Int32, Individual}},
    settingtype::Type{T},
    plans::AbstractActivityPlanStore,
    default_sampling
) where {T <: Setting}
    n = length(pairs)
    n == 0 && return nothing

    # chunk starts moved forward to the start of a setting, so no setting is split between chunks
    nchunks = min(n, 8 * Threads.nthreads())
    step = cld(n, nchunks)
    bounds = Vector{Int}(undef, nchunks + 1)
    bounds[1] = 1
    @inbounds for c in 2:nchunks
        b = max(bounds[c - 1], 1 + (c - 1) * step)
        while b <= n && pairs[b][1] == pairs[b - 1][1]
            b += 1
        end
        bounds[c] = min(b, n + 1)
    end
    bounds[end] = n + 1

    # settings per chunk, counted in parallel, give each chunk the position of its first setting
    nsettings = zeros(Int, nchunks + 1)
    Threads.@threads for c in 1:nchunks
        m = 0
        @inbounds for k in bounds[c]:(bounds[c + 1] - 1)
            (k == bounds[c] || pairs[k][1] != pairs[k - 1][1]) && (m += 1)
        end
        @inbounds nsettings[c + 1] = m
    end
    # read through an abstract slot, so every setting stores this one box instead of boxing its own
    sampling = Ref{ContactSamplingMethod}(default_sampling)
    # settings no container holds share one pool, which holds each member at its position in `pairs`
    flat = _new_flat_pool(T, n)
    first_position = length(container_vec) + 1
    nsettings[1] = first_position
    cumsum!(nsettings, nsettings)
    resize!(container_vec, nsettings[end] - 1)

    Threads.@threads for c in 1:nchunks
        @inbounds _construct_settings_chunk!(container_vec, pairs, settingtype, plans, sampling, flat,
            bounds[c], bounds[c + 1] - 1, nsettings[c])
    end
    return flat
end

# Builds the settings for `pairs[lo:hi]` from `container_vec[at]`, setting member indices and scale bounds.
function _construct_settings_chunk!(container_vec::Vector, pairs::Vector{Tuple{Int32, Int32, Individual}},
        settingtype::Type{T}, plans::AbstractActivityPlanStore, sampling::Base.RefValue{ContactSamplingMethod},
        flat::Union{Nothing, FlatSettingPool}, lo::Int, hi::Int, at::Int) where {T <: Setting}
    i = lo
    @inbounds while i <= hi
        current_id = pairs[i][1]
        j = i
        while j <= hi && pairs[j][1] == current_id
            j += 1
        end

        bound = 1.0f0
        for k in i:(j - 1)
            slot = pairs[k][2]
            plan_set_member_index!(plans, Int(slot), k - i + 1)
            bound = max(bound, Float32(entry_scale(plans.entries[slot])))
        end

        setting = _make_setting(settingtype, current_id, pairs, i, j, flat, sampling[])
        hasfield(T, :scale_bound) && (setting.scale_bound = bound)
        container_vec[at] = setting
        at += 1
        i = j
    end
    return nothing
end

_new_flat_pool(::Type{<:FlatSetting}, n::Int) = FlatSettingPool(Vector{Individual}(undef, n))
_new_flat_pool(::Type{<:Setting}, ::Int) = nothing

# A setting holding the individuals of `pairs[i:(j - 1)]`: at those same positions of the flat
# pool, or in a vector of its own.
function _make_setting(::Type{T}, sid::Int32, pairs::Vector{Tuple{Int32, Int32, Individual}}, i::Int, j::Int,
        flat::FlatSettingPool, csm::ContactSamplingMethod) where {T <: Setting}
    @inbounds for k in i:(j - 1)
        flat.members[k] = pairs[k][3]
    end
    return T(id = sid, flat_pool = flat, offset = i, len = j - i, contact_sampling_method = csm)
end

function _make_setting(::Type{T}, sid::Int32, pairs::Vector{Tuple{Int32, Int32, Individual}}, i::Int, j::Int,
        ::Nothing, csm::ContactSamplingMethod) where {T <: Setting}
    members = Vector{Individual}(undef, j - i)
    @inbounds for k in i:(j - 1)
        members[k - i + 1] = pairs[k][3]
    end
    return T(id = sid, individuals = members, contact_sampling_method = csm)
end

"""
    settings_from_population(population::Population, global_setting::Bool = false)

Creates all settings defined by the attributes of the individuals inside a given population.
Return a dictionary with all known concrete setting types as keys and a vector of created
settings.
"""
function settings_from_population(population::Population, global_setting::Bool = false)::Tuple{SettingsContainer, Dict}
    # Set keys for every concrete type of Setting
    settings = SettingsContainer()
    renaming = Dict()
    default_sampling = ContactparameterSampling(0)

    # Get all concrete subtypes of IndividualSetting
    stngtypes = _concrete_subtypes(IndividualSetting)
    if !global_setting
        stngtypes = filter(x -> x != GlobalSetting, stngtypes)
    end

    inds = individuals(population)

    # Buffers reused across every setting type, grown by the largest one
    # (setting id, plan slot, individual): the two Int32s side by side keep it at 16 bytes
    pairs_buffer = Tuple{Int32, Int32, Individual}[]
    sorted_buffer = Tuple{Int32, Int32, Individual}[]
    # chunks of individuals every type collects its entries in, with their buffers
    chunks = _thread_chunks(eachindex(inds))
    parts = [Tuple{Int32, Int32, Individual}[] for _ in chunks]

    for stngType in stngtypes
        # everyone is in the one GlobalSetting, so it is built here rather than from plan entries
        if stngType === GlobalSetting
            _build_global_setting!(settings, inds, default_sampling)
        else
            _settings_for_type!(settings, renaming, stngType, population, inds, chunks, parts, pairs_buffer, sorted_buffer, default_sampling)
        end
    end

    return settings, renaming
end

# The GlobalSetting holds every individual under the constant id; nobody carries a plan entry
# for it. An empty population gets none, as when it was built from pairs.
function _build_global_setting!(settings, inds::Vector{Individual}, default_sampling)
    isempty(inds) && return nothing
    add_type!(settings, GlobalSetting)
    add!(settings, GlobalSetting(id = GLOBAL_SETTING_ID, individuals = copy(inds),
        contact_sampling_method = default_sampling))
    return nothing
end


# Pushes the (setting id, slot, individual) of each type-`T` entry in `r` onto `out`; returns the id range.
function _collect_entry_triples!(out::Vector{Tuple{Int32, Int32, Individual}}, plans::AbstractActivityPlanStore,
                                 inds::Vector{Individual}, r::UnitRange{Int}, ::Type{T}) where {T <: Setting}
    # reused across types: keep the capacity, most types hold at most one entry per individual
    empty!(out)
    sizehint!(out, length(r); shrink = false)
    min_id = typemax(Int32)
    max_id = typemin(Int32)
    @inbounds for i in r
        ind = inds[i]
        for slot in plan_slots(plans, ind, T)
            sid = setting_id(plans.entries[slot])
            push!(out, (sid, Int32(slot), ind))
            min_id = min(min_id, sid)
            max_id = max(max_id, sid)
        end
    end
    return min_id, max_id
end

"""
    _settings_for_type!(settings, renaming, ::Type{T}, population, inds, chunks, parts, pairs_buffer, sorted_buffer, default_sampling) where {T <: Setting}

Function barrier for the per-type body of [`settings_from_population`](@ref), keeping the
per-individual loops type-stable and allocation-free.
"""
function _settings_for_type!(
    settings,
    renaming::Dict,
    ::Type{T},
    population::Population,
    inds::Vector{Individual},
    chunks::Vector{UnitRange{Int}},
    parts::Vector{Vector{Tuple{Int32, Int32, Individual}}},
    pairs_buffer::Vector{Tuple{Int32, Int32, Individual}},
    sorted_buffer::Vector{Tuple{Int32, Int32, Individual}},
    default_sampling
) where {T <: Setting}

    plans = activity_plans(population)

    # chunks collect one triple per entry in parallel; reading them in order keeps the serial order
    min_ids = fill(typemax(Int32), length(chunks))
    max_ids = fill(typemin(Int32), length(chunks))
    Threads.@threads for c in eachindex(chunks)
        @inbounds min_ids[c], max_ids[c] = _collect_entry_triples!(parts[c], plans, inds, chunks[c], T)
    end

    valid_count = sum(length, parts; init = 0)
    valid_count == 0 && return
    min_id = minimum(min_ids)
    max_id = maximum(max_ids)
    id_range = Int64(max_id) - Int64(min_id) + 1

    # Counting Sort, read straight from the chunks
    if id_range <= valid_count * 5
        counts = zeros(Int, id_range + 1)
        @inbounds for part in parts, t in part
            counts[t[1] - min_id + 2] += 1
        end
        @inbounds for i in 2:length(counts)
            counts[i] += counts[i-1]
        end
        resize!(sorted_buffer, valid_count)
        @inbounds for part in parts, t in part
            idx = t[1] - min_id + 1
            sorted_buffer[counts[idx] + 1] = t
            counts[idx] += 1
        end
        sorted = sorted_buffer
    else
        resize!(pairs_buffer, valid_count)
        at = 0
        for part in parts
            copyto!(pairs_buffer, at + 1, part, 1, length(part))
            at += length(part)
        end
        sort!(pairs_buffer, by = first)
        sorted = pairs_buffer
    end

    add_type!(settings, T)
    setting_vec = get(settings, T)

    flat = construct_and_add_settings!(setting_vec, sorted, T, plans, default_sampling)
    # registered so `repack_dirty_pools!` can compact it
    flat === nothing || (settings.flat_pools[T] = flat)

    # Sort the vector of settings by ID and check if the ids are continuous and start from 1
    if !isempty(setting_vec) && (setting_vec[1].id != 1 || setting_vec[end].id != length(setting_vec))
        @warn "Setting ids of type $(T) are not continuous or do not start from 1. Ids will be reassigned, containers might not be correctly linked."

        type_renaming = Dict{Int32, Int32}()
        renaming[T] = type_renaming

        # ascending old ids, and every new id is <= its old one, so a rename never collides
        # with an id the individual still holds
        for (i, setting) in enumerate(setting_vec)
            old_id = setting.id
            type_renaming[old_id] = i
            setting.id = i
            for individual in individuals(setting)
                slot = plan_slot(plans, individual, T, old_id)
                slot != 0 && plan_set_setting_id!(plans, slot, Int32(i))
            end
        end
    end

    return
end