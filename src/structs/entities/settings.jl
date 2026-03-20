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
export add!
export id, individuals
export update_infected_agents!
export settings_from_population
export activate!, deactivate!, isactive
export open!, close!
export contained, contained_type, contains_type

###
### ABSTRACT TYPES
###
"""
Supertype for all simulation settings
"""
abstract type Setting <: Entity end

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
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

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
- `individuals::Vector{Individual} = []` *(optional)*: List of associated individuals
- `type::Int32 = -1` *(optional)*: Type of school class (e.g. grade)
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*: Parent setting id (`SchoolYear`) 
- `contained_type::DataType = SchoolYear` *(optional)*: Parent setting tye (`SchoolYear`)
- `last_infectious::Int16 = -1` *(optional)*: Tick indicating the last presence of an infected individual
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `ags::Int32 = AGS()` *(optional)*: The Amtlicher Gemeindeschlüssel (AGS) of the schoolclass.
- `lon::Float32 = NaN` *(optional)*: Longitude of the schoolclass
- `lat::Float32 = NaN` *(optional)*: Latitude of the schoolclass
- `isactive::Bool = false` *(optional)*: A flag to represent if the setting is considered active for simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
"""
@with_kw mutable struct SchoolClass <: Geolocated
    id::Int32 # 4 bytes
    individuals::Vector{Individual} = [] # 40 + n*8 bytes
    type::Int32 = -1 # 1 byte
    contained::Int32 = DEFAULT_SETTING_ID # 4 bytes
    contained_type::DataType = SchoolYear
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
- `contains_type::DataType = SchoolClass` *(optional)*: Type of contained settings (`SchoolClass`)
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*:  Parent setting id (`School`)
- `contained_type::DataType = School` *(optional)*: Parent setting tye (`School`)
- `type::Int32 = -1` *(optional)*: Type of school year (e.g. grade)
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*: Sampling Method, defining how contacts are drawn.
- `isactive::Bool = false` *(optional)*: A flag to represent if the setting is considered active for simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
"""
@with_kw mutable struct SchoolYear <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contains_type::DataType = SchoolClass
    contained::Int32 = DEFAULT_SETTING_ID
    contained_type::DataType = School
    type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true
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
- `contains_type::DataType = SchoolYear` *(optional)*: Type of contained settings (`SchoolYear`)
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*:  Parent setting id (`SchoolComplex`)
- `contained_type::DataType = School` *(optional)*: Parent setting tye (`SchoolComplex`)
- `type::Int32 = -1` *(optional)*: Type of school (e.g. primary, highschool, ...)
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*: Sampling Method, defining how contacts are drawn.
- `isactive::Bool = false` *(optional)*: A flag to represent if the setting is considered active for simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
"""
@with_kw mutable struct School <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contains_type::DataType = SchoolYear
    contained::Int32 = DEFAULT_SETTING_ID
    contained_type::DataType = SchoolComplex
    type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()
    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true
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
- `contains_type::DataType = SchoolYear` *(optional)*: Type of contained settings (`School`)
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*: Sampling Method, defining how contacts are drawn.
- `isactive::Bool = false` *(optional)*: A flag to represent if the setting is considered active for simulation
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
"""
@with_kw mutable struct SchoolComplex <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contains_type::DataType = School
     type::Int32 = -1# 1 byte
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true
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
- `contains_type::DataType = Workplace` *(optional)*: Type of contained settings (`Workplace`)
- `type::Int32 = -1` *(optional)*: Numerical code representing the type of workplace site.
- `last_infectious::Int16 = -1` *(optional)*: The last simulation tick when an infectious individual was present.
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*: Sampling Method, defining how contacts are drawn.
- `isactive::Bool = false` *(optional)*: Whether the workplace is active in the simulation.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
"""
@with_kw mutable struct WorkplaceSite <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contains_type::DataType = Workplace
    type::Int32 = -1# 1 byte
    last_infectious::Int16 = -1 # 2 bytes
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true
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
- `contains_type::DataType = Department` *(optional)*: Type of contained settings (`Department`)
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*: Parent setting id (`WorkplaceSite`)
- `contained_type::DataType = WorkplaceSite` *(optional)*: Parent setting type (`WorkplaceSite`)
- `type::Int32 = -1` *(optional)*: Numerical code representing the type of workplace (e.g., farm, office).
- `last_infectious::Int16 -1` *(optional)*: The last simulation tick when an infectious individual was present.
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `isactive::Bool = false` *(optional)*: Whether the workplace is active in the simulation.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
"""
@with_kw mutable struct Workplace <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contains_type::DataType = Department
    contained::Int32 = DEFAULT_SETTING_ID
    contained_type::DataType = WorkplaceSite
    type::Int32 = -1 # 1 byte
    last_infectious::Int16 = -1 # 2 bytes
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()
    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true
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
- `contains_type::DataType = Office` *(optional)*: Type of contained settings (`Office`)
- `contained::Int32 = DEFAULT_SETTING_ID` *(optional)*: Parent setting id (`Workplace`)
- `contained_type::DataType = Workplace` *(optional)*: Parent setting type (`Workplace`)
- `type::Int32 = -1` *(optional)*: Numerical code representing the type of department.
- `last_infectious::Int16 = -1` *(optional)*: The last simulation tick when an infectious individual was present.
- `contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)` *(optional)*:
    Sampling Method, defining how contacts are drawn.
- `isactive::Bool = false` *(optional)*: Whether the department is active in the simulation.
- `isopen::Bool = true` *(optional)*: Whether the setting is open for contacts.
"""
@with_kw mutable struct Department <: ContainerSetting
    id::Int32 # 4 bytes
    contains::Vector{Int32} = [] # 40 + n*4 bytes
    contains_type::DataType = Office
    contained::Int32 = DEFAULT_SETTING_ID
    contained_type::DataType = Workplace
    type::Int32 = -1# 1 byte
    last_infectious::Int16 = -1 # 2 bytes
    contact_sampling_method::ContactSamplingMethod = ContactparameterSampling(0)
    ags::AGS = AGS()

    
    
    # active settings approach
    isactive::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)

    # if closed, no contacts can happen here
    isopen::Bool = true
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
- `individuals::Vector{Individual} = []` *(optional)*: List of individuals associated with this office
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
"""
@with_kw mutable struct Office <: Geolocated
    id::Int32 # 4 bytes
    individuals::Vector{Individual} = Vector{Individual}() # 40 + n*8 bytes
    contained::Int32 = DEFAULT_SETTING_ID
    contained_type::DataType = Department
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
    setting.contact_sampling_method = csm
end

"""
    add!(setting::Setting, individual::Individual)

Adds the given individual to the setting.
"""
function add!(setting::Setting, individual::Individual)
    push!(setting.individuals, individual)
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
    if !isactive(setting)
        if hasproperty(setting, :contains) || setting |> individuals |> length > 1
            Threads.atomic_xchg!(setting.isactive, true)
        end
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
    contains(setting::ContainerSetting)

Returns the `contains` value of the given `ContainerSetting`.

"""
function contains(setting::ContainerSetting)
    return setting.contains
end

"""
    contains_type(setting::ContainerSetting)

Returns the `contains_type` value of the given `ContainerSetting`.

"""
function contains_type(setting::ContainerSetting)
    return setting.contains_type
end

"""
    contained(setting::Setting)

Returns the `contained` value of the given `Setting`.

"""
function contained(setting::Setting)
    return setting.contained
end

"""
    contained_type(setting::Setting)

Returns the `contained_type` value of the given `Setting`.

"""
function contained_type(setting::Setting)
    return setting.contained_type
end

"""
    individuals(setting::IndividualSetting)

Returns the individuals associated with the given setting.
"""
function individuals(setting::IndividualSetting)::Vector{Individual}
    return setting.individuals
end


Base.size(setting::IndividualSetting) = setting |> individuals |> length


### CREATION OF SETTINGS

"""
    construct_and_add_settings!(container_vec::Vector{Setting}, pairs::Vector{Tuple{Int32, Individual}}, ::Type{T}, default_sampling) where {T}

Helper function to construct settings from a sorted list of ID-Individual pairs without dynamic dispatch.
"""
function construct_and_add_settings!(
    container_vec::Vector{Setting}, 
    pairs::Vector{Tuple{Int32, Individual}}, 
    ::Type{T}, 
    default_sampling
) where {T}
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
        
        setting = T(id=current_id, individuals=members, contact_sampling_method=default_sampling)
        push!(container_vec, setting) # No longer triggers reallocations!
        
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
    
    # Default sampling method
    default_sampling = ContactparameterSampling(0)

    # Get all concrete subtypes of IndividualSetting as these may be contained in the population
    stngtypes = concrete_subtypes(IndividualSetting)
    
    # remove GlobalSetting if not wanted
    if !global_setting
        stngtypes = filter(x -> x != GlobalSetting, stngtypes)
    end

    inds = individuals(population)
    max_inds = length(inds)

    pairs_buffer = Vector{Tuple{Int32, Individual}}(undef, max_inds)

    # Iterate over all settingtypes in parallel
    #=Threads.@threads=# for stngType in stngtypes
        
        resize!(pairs_buffer, max_inds)
        
        # Create a buffer to store all individuals with the same setting id
        # Iterate over all individuals and add them to the buffer
        valid_count = 0
        for i in 1:max_inds
            ind = inds[i]
            id = setting_id(ind, stngType)
            if id != DEFAULT_SETTING_ID
                valid_count += 1
                @inbounds pairs_buffer[valid_count] = (id, ind)
            end
        end
        
        if valid_count == 0
            continue
        end

        resize!(pairs_buffer, valid_count)
        sort!(pairs_buffer, alg = Base.Sort.QuickSort, by = first)

        add_type!(settings, stngType)
        setting_vec = get(settings, stngType)
        
        construct_and_add_settings!(setting_vec, pairs_buffer, stngType, default_sampling)

        # Sort the vector of settings by ID and check if the ids are continuous and start from 1
        # Otherwise rename them and save the changes in a dictionary
        if !isempty(setting_vec) && (setting_vec[1].id != 1 || setting_vec[end].id != length(setting_vec))
            @warn "Setting ids of type $(stngType) are not continuous or do not start from 1. Ids will be reassigned, containers might not be correctly linked."
            
            type_renaming = Dict{Int32, Int32}() 
            renaming[stngType] = type_renaming
            
            for (i, setting) in enumerate(setting_vec)
                type_renaming[setting.id] = i
                setting.id = i
                for individual in setting.individuals
                    setting_id!(individual, stngType, Int32(i))
                end
            end
        end
    end

    return settings, renaming
end