###
### SETTINGS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
import Base.contains
export Setting, Geolocated, IndividualSetting, ContainerSetting
export GlobalSetting, Household, Municipality, Setting
export SchoolComplex, School, SchoolYear, SchoolClass
export Department, Office, WorkplaceSite, Workplace
export settingchar, settingstring
export contact_sampling_method, contact_sampling_method!
export add!, remove!
export add_member!, remove_member!
export id, individuals
export activate!, deactivate!, isactive
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

###
### MEMBER STORAGE
### Here rather than in setting_pool.jl because the setting types below use them as field
### types, and that file is included later.
###

# A contiguous view into a `SettingPool`'s member vector.
const MemberSlice = SubArray{Individual, 1, Vector{Individual}, Tuple{UnitRange{Int64}}, true}

# What an `individuals` field may hold. A setting outside a hierarchy owns its members
# outright; one inside a pooled hierarchy holds a slice of that pool, so its members are not
# duplicated and its containers can address them as a range. Both alternatives are concrete,
# so reading the field splits a two-way union rather than dispatching dynamically.
const MemberStorage = Union{Vector{Individual}, MemberSlice}

"""
    SettingPool

Backing storage for one setting hierarchy. Holds every member of every leaf, leaves laid out
in DFS order over `contains`, so any container's members form a contiguous range of it.

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
end

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
- `isactive::Bool`: A flag to represent if the setting is considered active for simulation
- `isopen::Bool`: Whether the setting is open for contacts.
    conditions
"""
@with_kw mutable struct GlobalSetting <: IndividualSetting
    id::Int32 = GLOBAL_SETTING_ID # ONLY ONE GLOBALSETTING SHOULD EXIST!!!
    individuals::Vector{Individual} = Vector{Individual}()
    contact_sampling_method::ContactSamplingMethod   
    ags::AGS= AGS() # 4 bytes

    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(true)

    # if closed, no contacts can happen here
    isopen::Bool = true
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
- `last_infectious::Int16 = -1` *(optional)*: Tick indicating the last presence of an infected individual
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `ags::AGS = AGS()` *(optional)*: The Amtlicher Gemeindeschlüssel (AGS) of the Household.
- `lon::Float32 = NaN` *(optional)*: Longitude of the household
- `lat::Float32 = NaN`: Latitude of the household
- `isactive::Bool = false` *(optional)*: A flag to represent if the setting is considered active for simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
"""
@with_kw mutable struct Household <: Geolocated
    id::Int32 # 4 bytes
    individuals::Vector{Individual} = Vector{Individual}() # 40 + n*8 bytes
    income::Int8 = -1 # 1 byte
    dwelling::Int8 = -1 # 1 byte
    last_infectious::Int16 = -1 # 2 bytes
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS= AGS() # 4 bytes
    lon::Float32 = NaN # 4 bytes
    lat::Float32 = NaN # 4 bytes


    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true
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
- `isactive::Bool = false` *(optional)*: A flag to represent if the setting is considered active for simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
"""
@with_kw mutable struct Municipality <: IndividualSetting
    id::Int32 # 4 bytes // Municipality identifier
    individuals::Vector{Individual} = [] # 40 + n*8 bytes // List of associated individuals
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS= AGS() # 4 bytes
    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true
end

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
- `individuals::MemberStorage = []` *(optional)*: List of associated individuals
- `type::Int32 = -1` *(optional)*: Type of school class (e.g. grade)
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*: Parent setting id (`SchoolYear`)
- `last_infectious::Int16 = -1` *(optional)*: Tick indicating the last presence of an infected individual
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `ags::Int32 = AGS()` *(optional)*: The Amtlicher Gemeindeschlüssel (AGS) of the schoolclass.
- `lon::Float32 = NaN` *(optional)*: Longitude of the schoolclass
- `lat::Float32 = NaN` *(optional)*: Latitude of the schoolclass
- `isactive::Bool = false` *(optional)*: A flag to represent if the setting is considered active for simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage. Members are held there rather
    than in this setting, so its containers can address them without a copy.
- `pool_offset`, `pool_length` *(internal)*: Where this setting's members sit in that pool.
    `individuals` is a view of exactly that span.
"""
@with_kw mutable struct SchoolClass <: Geolocated
    id::Int32 # 4 bytes
    individuals::MemberStorage = Vector{Individual}() # a slice of the hierarchy pool once built
    type::Int32 = -1 # 1 byte
    contained::Int32 = DEFAULT_SETTING_ID # 4 bytes
    last_infectious::Int16 = -1 # 2 bytes
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS= AGS() # 4 bytes
    lon::Float32 = NaN # 4 bytes
    lat::Float32 = NaN # 4 bytes

    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's SettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    pool::Union{Nothing, SettingPool} = nothing

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
- `isactive::Bool = false` *(optional)*: A flag to represent if the setting is considered active for simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
"""
@with_kw mutable struct SchoolYear <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contained::Int32 = DEFAULT_SETTING_ID
    type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's SettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    pool::Union{Nothing, SettingPool} = nothing

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
- `isactive::Bool = false` *(optional)*: A flag to represent if the setting is considered active for simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
"""
@with_kw mutable struct School <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contained::Int32 = DEFAULT_SETTING_ID
    type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()
    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's SettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    pool::Union{Nothing, SettingPool} = nothing

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
- `isactive::Bool = false` *(optional)*: A flag to represent if the setting is considered active for simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
"""
@with_kw mutable struct SchoolComplex <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
     type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's SettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    pool::Union{Nothing, SettingPool} = nothing

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
- `last_infectious::Int16 = -1` *(optional)*: The last simulation tick when an infectious individual was present.
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*: Sampling Method, defining how contacts are drawn.
- `isactive::Bool = false` *(optional)*: Whether the workplace is active in the simulation.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
"""
@with_kw mutable struct WorkplaceSite <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    type::Int32 = -1# 1 byte
    last_infectious::Int16 = -1 # 2 bytes
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's SettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    pool::Union{Nothing, SettingPool} = nothing

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
- `last_infectious::Int16 -1` *(optional)*: The last simulation tick when an infectious individual was present.
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `isactive::Bool = false` *(optional)*: Whether the workplace is active in the simulation.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
"""
@with_kw mutable struct Workplace <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contained::Int32 = DEFAULT_SETTING_ID
    type::Int32 = -1 # 1 byte
    last_infectious::Int16 = -1 # 2 bytes
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()
    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's SettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    pool::Union{Nothing, SettingPool} = nothing

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
- `last_infectious::Int16 = -1` *(optional)*: The last simulation tick when an infectious individual was present.
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `isactive::Bool = false` *(optional)*: Whether the department is active in the simulation.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
- `pool` *(internal)*: The hierarchy's shared member storage, holding the members of every
    leaf below this container.
- `pool_offset`, `pool_length` *(internal)*: The span of that pool covering this container's
    members. A container stores no members itself, so `present_members` hands back this span
    instead of collecting them; it is set at build time and holds until an edit leaves a gap.
"""
@with_kw mutable struct Department <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contained::Int32 = DEFAULT_SETTING_ID
    type::Int32 = -1# 1 byte
    last_infectious::Int16 = -1 # 2 bytes
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    
    
    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's SettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    pool::Union{Nothing, SettingPool} = nothing

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
- `individuals::MemberStorage = []` *(optional)*: List of individuals associated with this office
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*: Parent setting id (`Department`) 
- `contained_type::DataType = Department` *(optional)*: Parent setting tye (`Department`)
- `type::Int32 = -1` *(optional)*: Numerical code representing the type of office
- `last_infectious::Int16 = -1` *(optional)*: The last simulation tick when an infectious individual was present
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn
- `ags::AGS = AGS()` *(optional)*: The Amtlicher Gemeindeschlüssel (AGS) of the office
- `inroom::Int8 = -1` *(optional)*: Describes the amount of indoor work done in the office
- `workhome::Int8 = -1` *(optional)*: Describes the amount of work done from home
- `lon::Float32 = NaN` *(optional)*: Longitude of the office
- `lat::Float32 = NaN` *(optional)*: Latitude of the office
- `isactive::Bool = false` *(optional)*: Whether the office is active in the simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts
- `pool` *(internal)*: The hierarchy's shared member storage. Members are held there rather
    than in this setting, so its containers can address them without a copy.
- `pool_offset`, `pool_length` *(internal)*: Where this setting's members sit in that pool.
    `individuals` is a view of exactly that span.
"""
@with_kw mutable struct Office <: Geolocated
    id::Int32 # 4 bytes
    individuals::MemberStorage = Vector{Individual}() # a slice of the hierarchy pool once built
    contained::Int32 = DEFAULT_SETTING_ID
    type::Int32 = -1# 1 byte
    last_infectious::Int16 = -1 # 2 bytes
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS= AGS() # 4 bytes
    inroom::Int8 = -1 # 1 byte
    workhome::Int8 = -1 # 1 byte
    lon::Float32 = NaN # 4 bytes
    lat::Float32 = NaN # 4 bytes


    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true

    # position of this setting's members in its hierarchy's SettingPool (0 = not pooled)
    pool_offset::Int32 = 0
    pool_length::Int32 = 0
    pool::Union{Nothing, SettingPool} = nothing

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
#       id, individuals, infected_individuals, isactive

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
    add_member!(setting::IndividualSetting, individual::Individual)

Adds the given individual to the setting and records the membership on the individual.
`setting_id!` is a no-op for setting types without an id field on `Individual` (`GlobalSetting`).

Must not be called while the threaded transmission phase is running.
"""
function add_member!(setting::IndividualSetting, individual::Individual)
    if _pool(setting) === nothing
        push!(setting.individuals, individual)
    else
        _pool_add_member!(setting, individual)
    end
    setting_id!(individual, typeof(setting), id(setting))
    membership_changed!(contact_sampling_method(setting), setting)
    return nothing
end

"""
    remove_member!(setting::IndividualSetting, individual::Individual)

Removes the given individual from the setting and clears the membership on the individual.
Does nothing if it is not a member.

The member is swapped with the last element, so member order is not preserved.

Must not be called while the threaded transmission phase is running.
"""
function remove_member!(setting::IndividualSetting, individual::Individual)
    if _pool(setting) === nothing
        inds = setting.individuals
        idx = findfirst(i -> i === individual, inds)
        isnothing(idx) && return nothing
        @inbounds inds[idx] = inds[end]
        pop!(inds)
    else
        _pool_remove_member!(setting, individual) || return nothing
    end
    setting_id!(individual, typeof(setting), DEFAULT_SETTING_ID)
    membership_changed!(contact_sampling_method(setting), setting)
    return nothing
end

"""
    isactive(setting::Setting)

Returns whether the setting is considered active for simulation, e.g. an infection could
spread in the setting.
"""
function isactive(setting::Setting)::Bool
    return setting.isactive[]
end

"""
    activate!(setting::Setting)

Sets the setting active for simulation.
"""
function activate!(setting::Setting)
    if hasproperty(setting, :contains) || setting |> individuals |> length > 1
        Threads.atomic_xchg!(setting.isactive, true)
    end
end

"""
    deactivate!(setting::Setting)

Sets the setting as inactive for simulation.
"""
function deactivate!(setting::Setting)
    Threads.atomic_xchg!(setting.isactive, false)
end

"""
    deactivate!(setting::GlobalSetting)

Deactivating GlobalSetting is a no-op
"""
function deactivate!(setting::GlobalSetting)
    return nothing
end

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

"""
    individuals(setting::IndividualSetting)

Returns the individuals associated with the given setting.
"""
function individuals(setting::IndividualSetting)
    return setting.individuals
end


Base.size(setting::IndividualSetting) = setting |> individuals |> length


### CREATION OF SETTINGS

"""
    construct_and_add_settings!(container_vec::Vector, pairs::Vector{Tuple{Int32, Individual}}, settingtype::Type{T}, default_sampling) where {T <: Setting}

Helper function to construct settings from a sorted list of ID-Individual pairs without dynamic dispatch.
"""
function construct_and_add_settings!(
    container_vec::Vector,
    pairs::Vector{Tuple{Int32, Individual}},
    settingtype::Type{T},
    default_sampling
) where {T <: Setting}
    n = length(pairs)

    # Pre-calculate the number of unique settings to avoid push! reallocations
    if n > 0
        num_unique = 1
        for k in 2:n
            if pairs[k][1] != pairs[k-1][1]
                num_unique += 1
            end
        end
        # Pre-allocate the memory needed
        sizehint!(container_vec, length(container_vec) + num_unique)
    end

    i = 1
    # Iterate through the sorted pairs
    while i <= n
        current_id = pairs[i][1]

        # Find the block of individuals sharing this ID
        j = i
        while j <= n && pairs[j][1] == current_id
            j += 1
        end

        # Exact pre-allocation for the members array
        count = j - i
        members = Vector{Individual}(undef, count)
        for k in 0:(count-1)
            members[k+1] = pairs[i+k][2]
        end
        
        setting = settingtype(id=current_id, individuals=members, contact_sampling_method=default_sampling)
        push!(container_vec, setting)
        
        i = j # Move to the next unique ID
    end
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
    max_inds = length(inds)

    # Buffers are allocated once and reused across every setting type
    pairs_buffer = Vector{Tuple{Int32, Individual}}(undef, max_inds)
    # Pre-allocate another buffer for Counting Sort
    sorted_buffer = Vector{Tuple{Int32, Individual}}(undef, max_inds)

    for stngType in stngtypes
        _settings_for_type!(settings, renaming, stngType, inds, pairs_buffer, sorted_buffer, default_sampling)
    end

    return settings, renaming
end

"""
    _settings_for_type!(settings, renaming, ::Type{T}, inds, pairs_buffer, sorted_buffer, default_sampling) where {T <: Setting}

Function barrier for the per-type body of [`settings_from_population`](@ref): with `T` static,
`setting_id(ind, T)` resolves to an inlined `Int32` field load instead of a dynamic dispatch,
keeping the per-individual loops allocation-free.
"""
function _settings_for_type!(
    settings,
    renaming::Dict,
    ::Type{T},
    inds::Vector{Individual},
    pairs_buffer::Vector{Tuple{Int32, Individual}},
    sorted_buffer::Vector{Tuple{Int32, Individual}},
    default_sampling
) where {T <: Setting}

    max_inds = length(inds)
    resize!(pairs_buffer, max_inds)

    valid_count = 0
    min_id = typemax(Int32)
    max_id = typemin(Int32)

    # Iterate over all individuals and add them to the buffer
    for i in 1:max_inds
        ind = inds[i]
        id = setting_id(ind, T)
        if id != DEFAULT_SETTING_ID
            valid_count += 1

            # Track ID bounds for Counting Sort
            min_id = id < min_id ? id : min_id
            max_id = id > max_id ? id : max_id

            @inbounds pairs_buffer[valid_count] = (id, ind)
        end
    end

    if valid_count == 0
        return
    end

    resize!(pairs_buffer, valid_count)

    id_range = Int64(max_id) - Int64(min_id) + 1

    # Counting Sort
    if id_range <= valid_count * 5
        counts = zeros(Int, id_range + 1)

        # Count occurrences
        @inbounds for i in 1:valid_count
            counts[pairs_buffer[i][1] - min_id + 2] += 1
        end

        # Accumulate offsets
        @inbounds for i in 2:length(counts)
            counts[i] += counts[i-1]
        end

        # Place elements directly into their sorted positions
        resize!(sorted_buffer, valid_count)
        @inbounds for i in 1:valid_count
            val = pairs_buffer[i]
            idx = val[1] - min_id + 1
            sorted_buffer[counts[idx] + 1] = val
            counts[idx] += 1
        end

        # Transfer back to original buffer
        copyto!(pairs_buffer, sorted_buffer)
    else
        sort!(pairs_buffer, by = first)
    end

    add_type!(settings, T)
    setting_vec = get(settings, T)

    construct_and_add_settings!(setting_vec, pairs_buffer, T, default_sampling)

    # Sort the vector of settings by ID and check if the ids are continuous and start from 1
    if !isempty(setting_vec) && (setting_vec[1].id != 1 || setting_vec[end].id != length(setting_vec))
        @warn "Setting ids of type $(T) are not continuous or do not start from 1. Ids will be reassigned, containers might not be correctly linked."

        type_renaming = Dict{Int32, Int32}()
        renaming[T] = type_renaming

        for (i, setting) in enumerate(setting_vec)
            type_renaming[setting.id] = i
            setting.id = i
            for individual in setting.individuals
                setting_id!(individual, T, Int32(i))
            end
        end
    end

    return
end