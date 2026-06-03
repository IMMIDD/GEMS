###
### AGENTS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###

# EXPORTS
# types
export Individual
# basic attributes
export age, id, education, occupation, sex
# behaviour
export mandate_compliance, mandate_compliance!, social_factor, social_factor!
# settings
export setting_id, setting_id!, household_id, class_id, office_id, municipality_id, settings_tuple
export is_working, is_student, has_municipality
# health status
export comorbidities, has_comorbidity
export is_infected, isinfected, infected, infected!
export is_infectious, isinfectious, infectious
export is_exposed, isexposed, exposed
export is_presymptomatic, ispresymptomatic, presymptomatic
export is_symptomatic, issymptomatic, symptomatic, symptomatic!
export is_asymptomatic, isasymptomatic, asymptomatic
export is_severe, issevere, severe, severe!
export is_mild, ismild, mild
export is_hospitalized, ishospitalized, hospitalized, hospitalized!
export is_icu, isicu, icu, icu!
export is_ventilated, isventilated, ventilated, ventilated!
export is_recovered, isrecovered, recovered
export is_dead, isdead, dead, dead!
export is_detected, isdetected, detected, detected!
export get_active_pathogens
export number_of_infections
export inc_number_of_infections!
#quarantine
export quarantine_release_tick, quarantine_release_tick!
export quarantine_tick, quarantine_tick!
export quarantine_status, home_quarantine!, end_quarantine!
export is_quarantined, isquarantined, quarantined, quarantined!




###
### INDIVIDUALS
###
"""
    Individual

A type to represent individuals that act as agents inside the simulation.

# Fields
- General
    - `id::Int32`: Unique identifier of the individual
    - `sex::Int8`: Sex (Female (1), Male(2), Diverse (3))
    - `age::Int8`: Age
    - `occupation::Int16`: Occupation class (i.e. manual labour, office job, etc...)
    - `education::Int8`: Education class (i.e. highest degree)

- Health Status
    - `killing_pathogen_id::Int8`: Pathogen that killed the agent
    - `infected::Bool`: Flag indicating individual's infection status
    - `infectious::Bool`: Flag indicating if individual is infectious with any pathogen
    - `symptomatic::Bool`: Flag indicating individual is showing symptoms
    - `severe::Bool`: Flag indicating individual is experiencing severe symptoms
    - `hospitalized::Bool`: Flag indicating individual is in the hospital
    - `icu::Bool`: Flag indicating individual is in the ICU
    - `ventilated::Bool`: Flag indicating individual is on a ventilator
    - `dead::Bool`: Flag indicating individual's decease
    - `comorbidities::UInt16`: Bitmask indicating prevalence of certain health conditions

- Behaviour
    - `social_factor::Float32`: Parameter for risk-willingness (-1 to 1)
    - `mandate_compliance::Float32`: Probability of complying to mandates (-1 to 1)

- Associated Settings
    - `household::Int32`: Reference to household id
    - `office::Int32`: Reference to office id
    - `schoolclass::Int32`: Reference to schoolclass id
    - `municipality::Int32`: Reference to municipality id

- Pathogen Memory
    - `infection_cache::NTuple{N, InfectionState}`: Fixed-size cache of current infections
    - `infection_head::Int32`: Pointer to the first overflow node in the InfectionRegistry
    - `active_pathogens_mask::UInt32`: Bitmask of currently active pathogen types
    - `detected_mask::UInt32`: Bitmask of pathogens for which an infection is detected
    - `number_of_infections::Int8`: Lifetime infection count

- Immunity Memory
    - `immunity_cache::NTuple{N, ImmunityState}`: Fixed-size cache of pathogen immunities
    - `immunity_head::Int32`: Pointer to the first overflow node in the ImmunityRegistry
    - `needs_immunity_update::Bool`: Flag for deferred immunity calculations

- Interventions
    - `quarantine_tick::Int16`: Start tick of quarantine
    - `quarantine_release_tick::Int16`: End tick of quarantine
    - `quarantine_status::Int8`: Status indicator (none, household, etc.)
"""
@with_kw_noshow mutable struct Individual
    # GENERAL
    id::Int32                               # 4 bytes
    sex::Int8                               # 1 byte
    age::Int8                               # 1 byte
    occupation::Int16 = DEFAULT_SETTING_ID  # 2 bytes
    education::Int8 = DEFAULT_SETTING_ID    # 1 byte

    # HEALTH STATUS
    killing_pathogen_id::Int8 = DEFAULT_PATHOGEN_ID # 1 byte
    infected::Bool = false                  # 1 byte
    infectious::Bool = false                  # 1 byte
    symptomatic::Bool = false               # 1 byte
    severe::Bool = false                    # 1 byte
    hospitalized::Bool = false              # 1 byte
    icu::Bool = false                       # 1 byte
    ventilated::Bool = false                # 1 byte
    dead::Bool = false                      # 1 byte
    comorbidities::UInt16 = 0               # 2 bytes

    # BEHAVIOR
    social_factor::Float32 = 0              # 4 bytes
    mandate_compliance::Float32 = 0         # 4 bytes

    # ASSIGNED SETTINGS
    household::Int32 = DEFAULT_SETTING_ID   # 4 bytes
    office::Int32 = DEFAULT_SETTING_ID      # 4 bytes
    schoolclass::Int32 = DEFAULT_SETTING_ID # 4 bytes
    municipality::Int32 = DEFAULT_SETTING_ID # 4 bytes

    # PATHOGEN MEMORY
    infection_cache::NTuple{INFECTIONS_CACHE_SIZE, InfectionState} = ntuple(_ -> InfectionState(), INFECTIONS_CACHE_SIZE) # INFECTIONS_CACHE_SIZE * sizeof(InfectionState)
    infection_head::Int32 = 0               # 4 byte
    active_pathogens_mask::UInt32 = 0       # 4 bytes
    detected_mask::UInt32 = 0               # 4 bytes
    number_of_infections::Int8 = 0          # 1 byte

    # IMMUNITY MEMORY
    immunity_cache::NTuple{IMMUNITY_CACHE_SIZE, ImmunityState} = ntuple(_ -> ImmunityState(), IMMUNITY_CACHE_SIZE) # IMMUNITY_CACHE_SIZE * sizeof(ImmunityState)
    immunity_head::Int32 = 0                # 4 byte
    needs_immunity_update::Bool = false     # 1 byte

    # INTERVENTIONS
    quarantine_tick::Int16 = DEFAULT_TICK           # 2 bytes
    quarantine_release_tick::Int16 = DEFAULT_TICK   # 2 bytes
    quarantine_status::Int8 = QUARANTINE_STATE_NO_QUARANTINE # 1 byte
end

# CONSTRUCTOR
"""
    Individual(properties::Dict)

Create an individual with the provided properties. Properties must *have at least* keys
`id`, `sex`, `age`.
"""
function Individual(properties::Dict)::Individual
    ind = Individual(id=properties["id"], sex=properties["sex"], age=properties["age"])

    # set every field that is provided by properties
    for field in fieldnames(Individual)
        if haskey(properties, String(field))
            setproperty!(ind, field, properties[String(field)])
        end
    end

    return ind
end


"""
    Individual(properties::DataFrameRow)

Create an individual with the provided properties. Properties must *have at least* keys
`id`, `sex`, `age`.
"""
function Individual(properties::DataFrameRow)::Individual
    return Individual(; (Symbol(k) => v for (k, v) in pairs(properties))...)
end


### GETTER OF BASIC ATTRIBUTES ###

"""
    id(individual::Individual)

Return the unique identifier of the individual.
"""
function id(individual::Individual)::Int32
    return individual.id
end

"""
    sex(individual::Individual)

Return an individual's sex.
"""
function sex(individual::Individual)::Int8
    return individual.sex
end

"""
    age(individual::Individual)

Return an individual's age.
"""
function age(individual::Individual)::Int8
    return individual.age
end

"""
    education(individual::Individual)

Return an individual's education class
"""
function education(individual::Individual)::Int8
    return individual.education
end

"""
    occupation(individual::Individual)

Returns an individual's occupation class.
"""
function occupation(individual::Individual)::Int16
    return individual.occupation
end

### BEHAVIOUR ###

"""
    social_factor(individual::Individual)

Returns an individual's `social_factor` value.
"""
function social_factor(individual::Individual)::Float32
    return individual.social_factor
end

"""
    social_factor!(individual::Individual, val::Float32)

Overwrites the individual's `social_factor` attribute.
"""
function social_factor!(individual::Individual, val::Float32)
    individual.social_factor = val
end

social_factor!(individual::Individual, val::Float64) = social_factor!(individual, Float32(val))

"""
    mandate_compliance(individual::Individual)

Return an individual's `mandate_compliance` value.
"""
function mandate_compliance(individual::Individual)::Float32
    return individual.mandate_compliance
end

"""
    mandate_compliance!(individual::Individual, val::Float32)

Overwrites the individual's `mandate_compliance` attribute.
"""
function mandate_compliance!(individual::Individual, val::Float32)
    individual.mandate_compliance = val
end

mandate_compliance!(individual::Individual, val::Float64) = mandate_compliance!(individual, Float32(val))

### SETTINGS ###

"""
    household_id(individual::Individual)

Returns an individual's associated household's ID.
"""
function household_id(individual::Individual)::Int32
    return individual.household
end

"""
    office_id(individual::Individual)

Returns an individual's associated office's ID.
"""
function office_id(individual::Individual)::Int32
    return individual.office
end

"""
    class_id(individual::Individual)

Returns an individual's associated class's ID.
"""
function class_id(individual::Individual)::Int32
    return individual.schoolclass
end

"""
    municipality_id(individual::Individual)

Returns an individual's associated municipalities ID.
"""
function municipality_id(individual::Individual)::Int32
    return individual.municipality
end

"""
    settings_tuple(individual::Individual)

Returns all individual's associated setting IDs as a Tuple.
"""
function settings_tuple(individual::Individual)
    return (
        (Household, individual.household),
        (Office, individual.office),
        (SchoolClass, individual.schoolclass),
        (Municipality, individual.municipality)
    )
end

"""
    setting_id(individual::Individual, type::DataType)

Returns the id of the setting of `type` associated with the individual. If the settingtype
is unknown or the agent isn't part of a setting of that type, -1 will be returned.
"""
function setting_id(individual::Individual, type::DataType)::Int32
    if type==Household
        return individual.household
    elseif type==Office
        return individual.office
    elseif type == SchoolClass
        return individual.schoolclass
    elseif type == Municipality
        return individual.municipality
    elseif type==GlobalSetting
        return GLOBAL_SETTING_ID # there is only one GlobalSetting
    else
        # in any other case it defaults to -1 as this means no ID
        return DEFAULT_SETTING_ID
    end
end

"""
    setting_id!(individual::Individual, type::DataType, id::Int32)

Changes the assigned setting id of the individual for the given type of setting to `id`.
"""
function setting_id!(individual::Individual, type::DataType, id::Int32)
    if type==Household
        individual.household = id
    elseif type==Office
        individual.office = id
    elseif type==SchoolClass
        individual.schoolclass = id
    elseif type==Municipality
        individual.municipality = id
    end

    return nothing
end

"""
    is_working(individual::Individual)

Returns `true` if individual is assigned to an  instance of type `Office`.
"""
is_working(individual::Individual) = office_id(individual) != DEFAULT_SETTING_ID

"""
    is_student(individual::Individual)

Returns `true` if individual is assigned to an  instance of type `SchoolClass`.
"""
is_student(individual::Individual) = class_id(individual) != DEFAULT_SETTING_ID

"""
    has_municipality(individual::Individual)

Returns `true` if individual is assigned to an instance of type `Municipality`.
"""
has_municipality(individual::Individual) = municipality_id(individual) != DEFAULT_SETTING_ID


### HEALTH STATUS ###

"""
    comorbidities(individual::Individual)

Returns an individual's comorbidities.
"""
function comorbidities(individual::Individual)::UInt16
    return individual.comorbidities
end

"""
    has_comorbidity(individual::Individual, n::Int16)

Returns `true` if the individual has the `n`-th comorbidity flag set.
`n` is 1-indexed and should be between 1 and 16.
"""
function has_comorbidity(individual::Individual, n::Int16)
    # Ensure n is in the valid range for a UInt16
    if !(1 <= n <= 16)
        throw(ArgumentError("Comorbidity index must be between 1 and 16."))
    end
    
    # Shift a bit to the (n-1)th position and apply bitwise AND
    return (individual.comorbidities & (UInt16(1) << (n - 1))) != 0
end

"""
    is_infected(individual::Individual)
    isinfected(individual::Individual)
    infected(individual::Individual)

Returns the `infected` flag of the individual.
"""
is_infected(individual::Individual) = individual.infected
isinfected(individual::Individual) = is_infected(individual)
infected(individual::Individual) = is_infected(individual)

"""
    infected!(individual::Individual, infected::Bool)

Sets the `infected` flag of the individual.
"""
infected!(individual::Individual, infected::Bool) = (individual.infected = infected)

"""
    is_infectious(individual::Individual)
    isinfectious(individual::Individual)
    infectious(individual::Individual)

Returns `true` iff the individual currently has nonzero shedding for at least one of their active pathogens.
"""
is_infectious(individual::Individual) = individual.infectious
isinfectious(individual::Individual) = is_infectious(individual)
infectious(individual::Individual) = is_infectious(individual)

"""
    infectious!(individual::Individual, infectious::Bool)

Sets the `infectious` flag of the individual.
"""
infectious!(individual::Individual, infectious::Bool) = (individual.infectious = infectious)

"""
    is_exposed(individual::Individual)
    isexposed(individual::Individual)
    exposed(individual::Individual)

Returns `true` if the individual is exposed at the current tick.
Exposed means infected but not yet infectious.
"""
is_exposed(individual::Individual) = is_infected(individual) && !is_infectious(individual)
isexposed(individual::Individual) = is_exposed(individual)
exposed(individual::Individual) = is_exposed(individual)



"""
    is_symptomatic(individual::Individual)
    issymptomatic(individual::Individual)
    symptomatic(individual::Individual)

Returns the `symptomatic` flag of the individual.
"""
is_symptomatic(individual::Individual) = individual.symptomatic
issymptomatic(individual::Individual) = is_symptomatic(individual)
symptomatic(individual::Individual) = is_symptomatic(individual)

"""
    symptomatic!(individual::Individual, symptomatic::Bool)

Sets the `symptomatic` flag of the individual.
"""
symptomatic!(individual::Individual, symptomatic::Bool) = (individual.symptomatic = symptomatic)

"""
    is_severe(individual::Individual)
    issevere(individual::Individual)
    severe(individual::Individual)

Returns the `severe` flag of the individual.
"""
is_severe(individual::Individual) = individual.severe
issevere(individual::Individual) = is_severe(individual)
severe(individual::Individual) = is_severe(individual)

"""
    severe!(individual::Individual, severe::Bool)

Sets the `severe` flag of the individual.
"""
severe!(individual::Individual, severe::Bool) = (individual.severe = severe)

"""
    is_hospitalized(individual::Individual)
    ishospitalized(individual::Individual)
    hospitalized(individual::Individual)

Returns the `hospitalized` flag of the individual.
"""
is_hospitalized(individual::Individual) = individual.hospitalized
ishospitalized(individual::Individual) = is_hospitalized(individual)
hospitalized(individual::Individual) = is_hospitalized(individual)

"""
    hospitalized!(individual::Individual, hospitalized::Bool)

Sets the `hospitalized` flag of the individual.
"""
hospitalized!(individual::Individual, hospitalized::Bool) = (individual.hospitalized = hospitalized)

"""
    is_icu(individual::Individual)
    isicu(individual::Individual)
    isicu(individual::Individual)

Returns the `icu` flag of the individual.
"""
is_icu(individual::Individual) = individual.icu
isicu(individual::Individual) = is_icu(individual)
icu(individual::Individual) = is_icu(individual)

"""
    icu!(individual::Individual, isicu::Bool)

Sets the `icu` flag of the individual.
"""
icu!(individual::Individual, icu::Bool) = (individual.icu = icu)

"""
    is_ventilated(individual::Individual)
    isventilated(individual::Individual)
    ventilated(individual::Individual)

Returns the `ventilated` flag of the individual.
"""
is_ventilated(individual::Individual) = individual.ventilated
isventilated(individual::Individual) = is_ventilated(individual)
ventilated(individual::Individual) = is_ventilated(individual)

"""
    ventilated!(individual::Individual, ventilated::Bool)

Sets the `ventilated` flag of the individual.
"""
ventilated!(individual::Individual, ventilated::Bool) = (individual.ventilated = ventilated)

"""
    is_dead(individual::Individual)
    isdead(individual::Individual)
    dead(individual::Individual)

Returns `true` if the individual is dead.
"""
is_dead(individual::Individual) = individual.dead
isdead(individual::Individual) = is_dead(individual)
dead(individual::Individual) = is_dead(individual)

"""
    dead!(individual::Individual, pathogen_id::Int8, dead::Bool)

Set the `dead` flag of the individual.
"""
function dead!(individual::Individual, pathogen_id::Int8, dead::Bool)
    individual.dead = dead
end

"""
    is_detected(individual::Individual)
 
Returns `true` if the individual has been detected for any currently active pathogen.
"""
is_detected(individual::Individual) = individual.detected_mask != 0
isdetected(individual::Individual) = is_detected(individual)
detected(individual::Individual) = is_detected(individual)
 
"""
    is_detected(individual::Individual, pathogen_id::Int8)
 
Returns `true` if the individual has been detected for the specific `pathogen_id`.
"""
is_detected(individual::Individual, pathogen_id::Int8) = (individual.detected_mask & (UInt32(1) << (pathogen_id - 1))) != 0
isdetected(individual::Individual, pathogen_id::Int8) = is_detected(individual, pathogen_id)
detected(individual::Individual, pathogen_id::Int8) = is_detected(individual, pathogen_id) 
"""
    detected!(individual::Individual, pathogen_id::Int8, val::Bool)
 
Sets or clears the detected bit for `pathogen_id` on the individual.
"""
function detected!(individual::Individual, pathogen_id::Int8, val::Bool)
    if val
        individual.detected_mask |= (UInt32(1) << (pathogen_id - 1))
    else
        individual.detected_mask &= ~(UInt32(1) << (pathogen_id - 1))
    end
end


# --- PATHOGEN ATTRIBUTES ---

"""
    get_active_pathogens(individual::Individual)::NTuple{MAX_CONCURRENT_INFECTIONS, Int8}

Returns an individual's active pathogens.
"""
@inline function get_active_pathogens(ind::Individual)
    ntuple(i -> ind.infection_cache[i].active ? ind.infection_cache[i].pathogen_id : Int8(0), INFECTIONS_CACHE_SIZE)
end

"""
    infected(individual::Individual, pathogen_id::Int8)::Bool

Returns `true` if the individual currently has an active infection with the given
`pathogen_id`. Uses the per-individual `active_pathogens_mask`.

This is the preferred overload for use in `IStrategy` conditions, as the condition
function only receives an `Individual`:

```julia
IStrategy("isolate-pathogen-a", sim, condition = ind -> infected(ind, Int8(1)))
```
"""
@inline function infected(individual::Individual, pathogen_id::Int8)::Bool
    return (individual.active_pathogens_mask & (UInt32(1) << (pathogen_id - 1))) != 0
end



"""
    number_of_infections(individual::Individual)

Returns an individual's number of infections (currently infected).
"""
function number_of_infections(individual::Individual)::Int8
    return individual.number_of_infections
end

"""
    inc_number_of_infections!(individual::Individual)

Increments an individual's number of infections by one.
"""
function inc_number_of_infections!(individual::Individual)
    individual.number_of_infections += 1
end


### QUARANTINE STATUS ###


"""
    quarantine_status(individual::Individual)

Returns an individuals quarantine status.
"""
function quarantine_status(individual::Individual)::Int8
    return individual.quarantine_status
end

"""
    quarantine_tick(individual::Individual)

Returns an individual's quarantine tick.
"""
function quarantine_tick(individual::Individual)::Int16
    return individual.quarantine_tick
end

"""
    quarantine_tick!(individual::Individual, tick::Int16)

Sets an individual's quarantine tick.
"""
function quarantine_tick!(individual::Individual, tick::Int16)
    individual.quarantine_tick = tick
end

"""
    quarantine_release_tick(individual::Individual)

Returns an individual's quarantine release tick.
"""
function quarantine_release_tick(individual::Individual)::Int16
    return individual.quarantine_release_tick
end

"""
    quarantine_release_tick!(individual::Individual, tick::Int16)

Sets an individual's quarantine release tick.
"""
function quarantine_release_tick!(individual::Individual, tick::Int16)
    individual.quarantine_release_tick = tick
end

"""
    is_quarantined(individual::Individual)
    isquarantined(individual::Individual)
    quarantined(individual::Individual)

Returns wether the individual is in quarantine or not.
"""
is_quarantined(individual::Individual) = individual.quarantine_status != QUARANTINE_STATE_NO_QUARANTINE
isquarantined(individual::Individual) = is_quarantined(individual)
quarantined(individual::Individual) = is_quarantined(individual)

"""
    is_quarantined(individual::Individual, tick::Int16)
    isquarantined(individual::Individual, tick::Int16)
    quarantined(individual::Individual, tick::Int16)

Returns wether the individual is in quarantine at tick `tick`.
"""
is_quarantined(individual::Individual, tick::Int16) = quarantine_tick(individual) <= tick < quarantine_release_tick(individual)
isquarantined(individual::Individual, tick::Int16) = is_quarantined(individual, tick)
quarantined(individual::Individual, tick::Int16) = is_quarantined(individual, tick)


"""
    quarantined!(individual::Individual, quarantined::Bool)

Sets an individual's quarantine status to either home quarantine or no quarantine.
"""
function quarantined!(individual::Individual, quarantined::Bool)
    individual.quarantine_status = quarantined ? QUARANTINE_STATE_HOUSEHOLD_QUARANTINE : QUARANTINE_STATE_NO_QUARANTINE
end

"""
    home_quarantine!(individual::Individual)

Quarantines an individual in their household.
"""
function home_quarantine!(individual::Individual)
    individual.quarantine_status = QUARANTINE_STATE_HOUSEHOLD_QUARANTINE
end

"""
    end_quarantine!(individual::Individual)

Ends an individuals quarantine.
"""
function end_quarantine!(individual::Individual)
    @debug "Individual $(id(individual)) ending quarantine"
    individual.quarantine_status = QUARANTINE_STATE_NO_QUARANTINE
end


### PRINTING ###

function Base.show(io::IO, individual::Individual)
    sex_str = individual.sex == 1 ? "female" : individual.sex == 2 ? "male" : "diverse"

    attributes = [
        "ID" => individual.id,
        "Age" => individual.age,
        "Sex" => sex_str,
        "Education" => individual.education != DEFAULT_SETTING_ID ? individual.education : "n/a",
        "Occupation" => individual.occupation != DEFAULT_SETTING_ID ? individual.occupation : "n/a",
        "Social Factor" => individual.social_factor,
        "Mandate Compliance" => individual.mandate_compliance,
        
        "Is Infected" => individual.infected,
        "Is Infectious" => individual.infectious,
        "Is Symptomatic" => individual.symptomatic,
        "Is Severe" => individual.severe,
        "Is Hospitalized" => individual.hospitalized,
        "Is ICU'd" => individual.icu,
        "Is Ventilated" => individual.ventilated,
        "Is Dead" => individual.dead,

        "Household ID" => individual.household,
        "Office ID" => individual.office != DEFAULT_SETTING_ID ? individual.office : "n/a",
        "School Class ID" => individual.schoolclass != DEFAULT_SETTING_ID ? individual.schoolclass : "n/a",
        "Municipality ID" => individual.municipality != DEFAULT_SETTING_ID ? individual.municipality : "n/a",

        "Number of Infections" => individual.number_of_infections,
        
        "Quarantine Status" => individual.quarantine_status,
        "Quarantine Tick" => individual.quarantine_tick != DEFAULT_TICK ? individual.quarantine_tick : "n/a",
        "Quarantine Release Tick" => individual.quarantine_release_tick != DEFAULT_TICK ? individual.quarantine_release_tick : "n/a"
    ]

    max_label_length = maximum(length ∘ first, attributes)

    println(io, "Individual")
    for (label, value) in attributes
        println(io, "  ", rpad(label * ":", max_label_length + 3), value)
    end
end

function Base.show(io::IO, #=::MIME"text/plain",=# individuals::Vector{Individual})
    n = length(individuals)
    println(io, "$(n)-element Vector{Individual}:")
    
    if n <= 50
        for individual in individuals
            sex_str = individual.sex == 1 ? "female" : individual.sex == 2 ? "male" : "diverse"
            println(io, "  Individual[ID: $(individual.id), $sex_str, $(individual.age)y]")
        end
    else
        for individual in individuals[1:20]
            sex_str = individual.sex == 1 ? "female" : individual.sex == 2 ? "male" : "diverse"
            println(io, "  Individual[ID: $(individual.id), $sex_str, $(individual.age)y]")
        end
        
        println(io, "  ⋮")
        
        for individual in individuals[end-19:end]
            sex_str = individual.sex == 1 ? "female" : individual.sex == 2 ? "male" : "diverse"
            println(io, "  Individual[ID: $(individual.id), $sex_str, $(individual.age)y]")
        end
    end
end