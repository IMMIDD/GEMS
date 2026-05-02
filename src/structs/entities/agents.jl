###
### AGENTS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###

# EXPORTS
# types
export Agent
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
# disease progression
export exposure, exposure!
export infectiousness_onset, infectiousness_onset!
export symptom_onset, symptom_onset!
export severeness_onset, severeness_onset!
export severeness_offset, severeness_offset!
export hospital_admission, hospital_admission!
export icu_admission, icu_admission!
export icu_discharge, icu_discharge!
export ventilation_admission, ventilation_admission!
export ventilation_discharge, ventilation_discharge!
export hospital_discharge, hospital_discharge!
export recovery, recovery!
export death, death!
export get_active_pathogens, infection_id, infection_id!
export infectiousness
export number_of_infections
export inc_number_of_infections!
# testing
export last_test, last_test!
export last_test_result, last_test_result!
export last_reported_at, last_reported_at!
export isdetected
# vaccination
export vaccination_tick, vaccine_id, isvaccinated, number_of_vaccinations
#quarantine
export quarantine_release_tick, quarantine_release_tick!
export quarantine_tick, quarantine_tick!
export quarantine_status, home_quarantine!, end_quarantine!
export is_quarantined, isquarantined, quarantined, quarantined!

export update_immunity!
export progress_disease!


###
### ABSTRACT TYPES
###
"Supertype for simulation agents"
abstract type Agent <: Entity end

###
### INDIVIDUALS
###
"""
    Individual <: Agent

A type to represent individuals, that act as agents inside the simulation.

# Fields
- General
    - `id::Int32`: Unique identifier of the individual
    - `sex::Int8`: Sex  (Female (1), Male(2), Diverse (3))
    - `age::Int8`: Age
    - `education::Int8`: Education class (i.e. highest degree)
    - `occupation::Int16`: Occupation class (i.e. manual labour, office job, etc...)

- Behaviour
    - `social_factor::Float32`: Parameter for the risk-willingness. Can be anywhere between
       -1 and 1 with neutral infections is 0.
    - `mandate_compliance::Float32`. Paremeter which influences the probability of complying
        to mandates. Can be anywhere between -1 and 1 with neutral infections is 0.

- Health Status (Proxy Flags)
    - `comorbidities::UInt16`: Indicating prevalence of certain health conditions.
    - `dead::Bool`: Flag indicating individual's decease
    - `infected::Bool`: Flag indicating individual's infection status
    - `symptomatic::Bool`: Flag indicating individual is showing symptoms
    - `severe::Bool`: Flag indicating individual is experiencing severe symptoms
    - `hospitalized::Bool`: Flag indicating individual is in the hospital
    - `icu::Bool`: Flag indicating individual is in the ICU
    - `ventilated::Bool`: Flag indicating individual is on a ventilator
    - `detected::Bool`: Flag indicating individual tested positive

- Associated Settings
    - `household::Int32`: Reference to household id
    - `office::Int32`: Reference to office id
    - `schoolclass::Int32`: Reference to schoolclass id
    - `municipality::Int32`: Reference to municipality id

- Pathogen Memory
    - `number_of_infections::Int8`: Lifetime infection count
    - `active_pathogens::NTuple{N, Int8}`: pathogen id occupying slot `s`
    - `infectiousness::NTuple{N, Int8}`: current shedding level for that pathogen 
    - `infection_ids::NTuple{N, Int32}`: `infection_id` of the active infection in slot `s` 

- Immunity Memory
    - `immune_pathogens::NTuple{N, Int8}`: pathogen id with non-zero immunity in slot `s`; packed from index 1, trailing zeros unused
    - `immunity_level::NTuple{N, Int8}`: current immunity level (0–100) for the pathogen in slot `s`

- Testing
    - `last_test::Int16`: Tick of last test for pathogen
    - `last_test_result::Bool`: Flag for positivity of last test
    - `last_reported_at::Int16`: Tick at which this individual was last reported

- Interventions
    - `quarantine_status::Int8`: Status to indicate quarantine 
        (none, household_quarantined, hospitalized, etc...)
    - `quarantine_tick::Int16`: Start tick of quarantine
    - `quarantine_release_tick::Int16`: End tick of quarantine
"""
@with_kw_noshow mutable struct Individual <: Agent
    # GENERAL
    id::Int32  # 4 bytes
    sex::Int8  # 1 byte
    age::Int8  # 1 byte
    education::Int8 = DEFAULT_SETTING_ID # 1 byte
    occupation::Int16 = DEFAULT_SETTING_ID # 2 byte

    # BEHAVIOR
    social_factor::Float32 = 0 # 4 bytes
    mandate_compliance::Float32 = 0 # 4 bytes

    # HEALTH STATUS
    comorbidities::UInt16 = 0 # 2 bytes
    infected::Bool = false # 1 byte
    symptomatic::Bool = false # 1 byte
    severe::Bool = false # 1 byte
    hospitalized::Bool = false # 1 byte
    icu::Bool = false # 1 byte
    ventilated::Bool = false # 1 byte
    dead:: Bool = false # 1 byte
    detected::Bool = false # 1 byte

    # ASSIGNED SETTINGS
    household::Int32 = DEFAULT_SETTING_ID # 4 bytes
    office::Int32 = DEFAULT_SETTING_ID # 4 bytes
    schoolclass::Int32 = DEFAULT_SETTING_ID # 4 bytes
    municipality::Int32 = DEFAULT_SETTING_ID # 4 bytes

    # PATHOGEN MEMORY
    number_of_infections::Int8 = 0 # 1 byte
    active_pathogens::NTuple{MAX_CONCURRENT_INFECTIONS, Int8} = ntuple(_ -> Int8(0), MAX_CONCURRENT_INFECTIONS)
    infectiousness::NTuple{MAX_CONCURRENT_INFECTIONS, Int8} = ntuple(_ -> Int8(0), MAX_CONCURRENT_INFECTIONS)
    infection_ids::NTuple{MAX_CONCURRENT_INFECTIONS, Int32} = ntuple(_ -> DEFAULT_INFECTION_ID, MAX_CONCURRENT_INFECTIONS)

    # IMMUNITY MEMORY
    immune_pathogens::NTuple{MAX_TRACKED_IMMUNITIES, Int8} = ntuple(_ -> Int8(0), MAX_TRACKED_IMMUNITIES)
    immunity_level ::NTuple{MAX_TRACKED_IMMUNITIES, Int8} = ntuple(_ -> Int8(0), MAX_TRACKED_IMMUNITIES)
    needs_immunity_update::Bool = false
    
    # TESTING
    last_test::Int16 = DEFAULT_TICK # 2 bytes
    last_test_result::Bool = false # 1 byte
    last_reported_at::Int16 = DEFAULT_TICK # 2 bytes

    # INTERVENTIONS
    quarantine_status::Int8 = QUARANTINE_STATE_NO_QUARANTINE # 1 bytes
    quarantine_tick::Int16 = DEFAULT_TICK
    quarantine_release_tick::Int16 = DEFAULT_TICK
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
@inline function is_infectious(individual::Individual)::Bool
    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        individual.infectiousness[s] != 0 && return true
    end
    return false
end
isinfectious(individual::Individual) = is_infectious(individual)
infectious(individual::Individual) = is_infectious(individual)

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
    dead!(individual::Individual, dead::Bool)

Set the `dead` flag of the individual.
"""
function dead!(individual::Individual, dead::Bool)
    individual.dead = dead
    if dead 
        infected!(individual, false)
        individual.symptomatic = false
        individual.severe = false
        individual.hospitalized = false
        individual.icu = false
        individual.ventilated = false
        individual.detected = false
        individual.active_pathogens = ntuple(_ -> Int8(0), MAX_CONCURRENT_INFECTIONS)
        individual.infectiousness = ntuple(_ -> Int8(0), MAX_CONCURRENT_INFECTIONS)
        individual.infection_ids = ntuple(_ -> DEFAULT_INFECTION_ID, MAX_CONCURRENT_INFECTIONS)
    end
end

"""
    is_detected(individual::Individual)

Returns `true` if the individual is currently infected and has been detected (i.e. tested positive).
"""
is_detected(individual::Individual) = individual.detected
isdetected(individual::Individual) = is_detected(individual)
detected(individual::Individual) = is_detected(individual)

"""
    detected!(individual::Individual, detected::Bool)

Sets the `detected` flag of the individual.
"""
function detected!(individual::Individual, detected::Bool)
    individual.detected = detected
end


"""
    find_infection_index(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns the index of the infection for the given pathogen, or 0 if not infected.
"""
@inline function find_infection_index(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8)::Int
    return find_infection_index(infections, ind.id, pathogen_id)
end

"""
    get_infection_index(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Instant lookup to find the row index of an individual's active infection in the global `InfectionRegistry` arrays for a specific pathogen.
Throws an ArgumentError if not found.
"""
@inline function get_infection_index(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8)::Int
    idx = find_infection_index(infections, ind.id, pathogen_id)
    idx == 0 && throw(ArgumentError("Individual $(ind.id) is not currently infected with pathogen $(pathogen_id)."))
    return idx
end

# --- PATHOGEN ATTRIBUTES ---

"""
    get_active_pathogens(individual::Individual)::NTuple{MAX_CONCURRENT_INFECTIONS, Int8}

Returns an individual's active pathogens.
"""
@inline get_active_pathogens(ind::Individual) = ind.active_pathogens

"""
    infection_id(individual::Individual, pathogen_id::Int8)::Int32

Returns the `infection_id` of the individual's currently active infection
with `pathogen_id`, or `DEFAULT_INFECTION_ID` if no such infection exists.
"""
@inline function infection_id(individual::Individual, pathogen_id::Int8)::Int32
    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        if individual.active_pathogens[s] == pathogen_id
            return individual.infection_ids[s]
        end
    end
    return DEFAULT_INFECTION_ID
end

"""
    infectiousness(individual::Individual, pathogen_id::Int8)::Int8

Returns the individual's current infectiousness for the given pathogen
(`Int8`, 0–127). Returns `0` if the individual is not currently infected
with that pathogen, or is in the exposed-but-not-yet-infectious window,
or has recovered.
"""
@inline function infectiousness(individual::Individual, pathogen_id::Int8)::Int8
    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        if individual.active_pathogens[s] == pathogen_id
            return individual.infectiousness[s]
        end
    end
    return Int8(0)
end

"""
    immunity_level(individual::Individual, pathogen_id::Int8)::Int8

Returns the current cached immunity level (0-100) against `pathogen_id`,
or 0 if the individual has no immunity record for that pathogen.
"""
@inline function immunity_level(individual::Individual, pathogen_id::Int8)::Int8
    @inbounds for s in 1:MAX_TRACKED_IMMUNITIES
        individual.immune_pathogens[s] == Int8(0) && break   # packed: first 0 -> done
        individual.immune_pathogens[s] == pathogen_id && return individual.immunity_level[s]
    end
    return Int8(0)
end


### NATURAL DISEASE HISTORY ###

"""
    exposure(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last exposure tick for the given pathogen.
Return -1 if never exposed or not in active infection infections.
"""
function exposure(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].exposure
end

"""
    exposure!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's exposure tick for the given pathogen.
"""
function exposure!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:exposure), tick)
end

"""
    infectiousness_onset(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last infectiousness onset tick for the given pathogen.
Return -1 if never infectious.
"""
function infectiousness_onset(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].infectiousness_onset
end

"""
    infectiousness_onset!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's infectiousness onset tick for the given pathogen.
"""
function infectiousness_onset!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:infectiousness_onset), tick)
end

"""
    symptom_onset(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last symptom onset tick for the given pathogen.
Return -1 if never symptomatic.
"""
function symptom_onset(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].symptom_onset
end

"""
    symptom_onset!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's symptom onset tick for the given pathogen.
"""
function symptom_onset!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:symptom_onset), tick)
end

"""
    severeness_onset(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last severeness onset tick for the given pathogen.
Return -1 if never severe.
"""
function severeness_onset(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].severeness_onset
end

"""
    severeness_onset!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's severeness onset tick for the given pathogen.
"""
function severeness_onset!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:severeness_onset), tick)
end

"""
    severeness_offset(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last severeness offset tick for the given pathogen.
Return -1 if never severe.
"""
function severeness_offset(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].severeness_offset
end

"""
    severeness_offset!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's severeness offset tick for the given pathogen.
"""
function severeness_offset!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:severeness_offset), tick)
end

"""
    hospital_admission(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last hospital admission tick for the given pathogen.
Return -1 if never hospitalized.
"""
function hospital_admission(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].hospital_admission
end

"""
    hospital_admission!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's hospital admission tick for the given pathogen.
"""
function hospital_admission!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:hospital_admission), tick)
end

"""
    icu_admission(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last icu admission tick for the given pathogen.
Return -1 if never admitted to icu.
"""
function icu_admission(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].icu_admission
end

"""
    icu_admission!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's icu admission tick for the given pathogen.
"""
function icu_admission!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:icu_admission), tick)
end

"""
    icu_discharge(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last icu discharge tick for the given pathogen.
Return -1 if never discharged from icu.
"""
function icu_discharge(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].icu_discharge
end

"""
    icu_discharge!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's icu discharge tick for the given pathogen.
"""
function icu_discharge!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:icu_discharge), tick)
end

"""
    ventilation_admission(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last ventilation admission tick for the given pathogen.
Return -1 if never admitted to ventilation.
"""
function ventilation_admission(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].ventilation_admission
end

"""
    ventilation_admission!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's ventilation admission tick for the given pathogen.
"""
function ventilation_admission!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:ventilation_admission), tick)
end

"""
    ventilation_discharge(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last ventilation discharge tick for the given pathogen.
Return -1 if never discharged from ventilation.
"""
function ventilation_discharge(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].ventilation_discharge
end

"""
    ventilation_discharge!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's ventilation discharge tick for the given pathogen.
"""
function ventilation_discharge!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:ventilation_discharge), tick)
end

"""
    hospital_discharge(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last hospital discharge tick for the given pathogen.
Return -1 if never discharged from hospital.
"""
function hospital_discharge(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].hospital_discharge
end

"""
    hospital_discharge!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's hospital discharge tick for the given pathogen.
"""
function hospital_discharge!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:hospital_discharge), tick)
end

"""
    recovery(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last recovery tick for the given pathogen.
Return -1 if never recovered.
"""
function recovery(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].recovery
end

"""
    recovery!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's recovery tick for the given pathogen.
"""
function recovery!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:recovery), tick)
end

"""
    death(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Returns an individual's last death tick for the given pathogen.
Return -1 if never died.
"""
function death(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    idx = find_infection_index(individual, infections, pathogen_id)
    return idx == 0 ? Int16(-1) : infections.rows[idx].death
end

"""
    death!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)

Sets an individual's death tick for the given pathogen.
"""
function death!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, tick::Int16)
    idx = get_infection_index(individual, infections, pathogen_id)
    @inbounds infections.rows[idx] = _setrow(infections.rows[idx], Val(:death), tick)
end


### DISEASE STATUS ###

"""
    is_infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isinfected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is infected with the given pathogen at tick `t`.
"""
function is_infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    return exp >= 0 && exp <= t < max(rec, dea)
end
isinfected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_infected(individual, infections, pathogen_id, t)
infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_infected(individual, infections, pathogen_id, t)

"""
    is_infectious(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isinfectious(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    infectious(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is infectious with the given pathogen at tick `t`.
"""
function is_infectious(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    max_rec_dea = max(rec, dea)
    
    !(exp >= 0 && exp <= t < max_rec_dea) && return false
    
    @inbounds inf_onset = infections.rows[idx].infectiousness_onset
    return inf_onset <= t < max_rec_dea
end
isinfectious(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_infectious(individual, infections, pathogen_id, t)
infectious(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_infectious(individual, infections, pathogen_id, t)

"""
    is_exposed(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isexposed(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    exposed(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is exposed with the given pathogen at tick `t`.
Exposed means infected but not yet infectious.
"""
function is_exposed(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    
    !(exp >= 0 && exp <= t < max(rec, dea)) && return false
    
    @inbounds inf_onset = infections.rows[idx].infectiousness_onset
    return exp <= t < inf_onset
end
isexposed(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_exposed(individual, infections, pathogen_id, t)
exposed(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_exposed(individual, infections, pathogen_id, t)

"""
    is_presymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    ispresymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    presymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is presymptomatic with the given pathogen at tick `t`.
Presymptomatic means infected, will develop symptoms, but is not yet symptomatic.
"""
function is_presymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    
    !(exp >= 0 && exp <= t < max(rec, dea)) && return false
    
    @inbounds sym_onset = infections.rows[idx].symptom_onset
    return t < sym_onset
end
ispresymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_presymptomatic(individual, infections, pathogen_id, t)
presymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_presymptomatic(individual, infections, pathogen_id, t)

"""
    is_symptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    issymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    symptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is symptomatic with the given pathogen at tick `t`.
"""
function is_symptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    max_rec_dea = max(rec, dea)
    
    !(exp >= 0 && exp <= t < max_rec_dea) && return false
    
    @inbounds sym_onset = infections.rows[idx].symptom_onset
    return 0 <= sym_onset <= t < max_rec_dea
end
issymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_symptomatic(individual, infections, pathogen_id, t)
symptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_symptomatic(individual, infections, pathogen_id, t)

"""
    is_asymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isasymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    asymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is asymptomatic with the given pathogen at tick `t`.
Asymptomatic means infected and will not develop symptoms.
"""
function is_asymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    max_rec_dea = max(rec, dea)
    
    !(exp >= 0 && exp <= t < max_rec_dea) && return false
    
    @inbounds sym_onset = infections.rows[idx].symptom_onset
    is_symp = 0 <= sym_onset <= t < max_rec_dea
    return !is_symp && sym_onset < exp
end
isasymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_asymptomatic(individual, infections, pathogen_id, t)
asymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_asymptomatic(individual, infections, pathogen_id, t)

"""
    is_severe(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    issevere(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    severe(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is in a severe infections with the given pathogen at tick `t`.
"""
function is_severe(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    
    !(exp >= 0 && exp <= t < max(rec, dea)) && return false
    
    @inbounds sev_onset = infections.rows[idx].severeness_onset
    @inbounds sev_offset = infections.rows[idx].severeness_offset
    return 0 <= sev_onset <= t < sev_offset
end
issevere(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_severe(individual, infections, pathogen_id, t)
severe(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_severe(individual, infections, pathogen_id, t)

"""
    is_mild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    ismild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    mild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is in a mild infections with the given pathogen at tick `t`.
Mild means symptomatic but not severe.
"""
function is_mild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    max_rec_dea = max(rec, dea)
    
    !(exp >= 0 && exp <= t < max_rec_dea) && return false
    
    @inbounds sym_onset = infections.rows[idx].symptom_onset
    is_symp = 0 <= sym_onset <= t < max_rec_dea
    
    !is_symp && return false
    
    @inbounds sev_onset = infections.rows[idx].severeness_onset
    @inbounds sev_offset = infections.rows[idx].severeness_offset
    is_sev = 0 <= sev_onset <= t < sev_offset
    
    return !is_sev
end
ismild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_mild(individual, infections, pathogen_id, t)
mild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_mild(individual, infections, pathogen_id, t)

"""
    is_hospitalized(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)    
    ishospitalized(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    hospitalized(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is hospitalized with the given pathogen at tick `t`.
"""
function is_hospitalized(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    
    !(exp >= 0 && exp <= t < max(rec, dea)) && return false
    
    @inbounds hosp_adm = infections.rows[idx].hospital_admission
    @inbounds hosp_dis = infections.rows[idx].hospital_discharge
    return 0 <= hosp_adm <= t < hosp_dis
end
ishospitalized(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_hospitalized(individual, infections, pathogen_id, t)
hospitalized(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_hospitalized(individual, infections, pathogen_id, t)

"""
    is_icu(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isicu(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    icu(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is in ICU with the given pathogen at tick `t`.
"""
function is_icu(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    
    !(exp >= 0 && exp <= t < max(rec, dea)) && return false
    
    @inbounds hosp_adm = infections.rows[idx].hospital_admission
    @inbounds hosp_dis = infections.rows[idx].hospital_discharge
    
    !(0 <= hosp_adm <= t < hosp_dis) && return false
    
    @inbounds icu_adm = infections.rows[idx].icu_admission
    @inbounds icu_dis = infections.rows[idx].icu_discharge
    return 0 <= icu_adm <= t < icu_dis
end
isicu(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_icu(individual, infections, pathogen_id, t)
icu(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_icu(individual, infections, pathogen_id, t)

"""
    is_ventilated(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isventilated(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    ventilated(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is ventilated with the given pathogen at tick `t`.
"""
function is_ventilated(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    
    !(exp >= 0 && exp <= t < max(rec, dea)) && return false
    
    @inbounds hosp_adm = infections.rows[idx].hospital_admission
    @inbounds hosp_dis = infections.rows[idx].hospital_discharge
    
    !(0 <= hosp_adm <= t < hosp_dis) && return false
    
    @inbounds vent_adm = infections.rows[idx].ventilation_admission
    @inbounds vent_dis = infections.rows[idx].ventilation_discharge
    return 0 <= vent_adm <= t < vent_dis
end
isventilated(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_ventilated(individual, infections, pathogen_id, t)
ventilated(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_ventilated(individual, infections, pathogen_id, t)

"""
    is_recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isrecovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is recovered from the given pathogen at tick `t`.
"""
function is_recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds rec = infections.rows[idx].recovery
    return 0 <= rec <= t
end
isrecovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_recovered(individual, infections, pathogen_id, t)
recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_recovered(individual, infections, pathogen_id, t)

"""
    is_dead(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isdead(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    dead(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is dead from the given pathogen at tick `t`.
"""
function is_dead(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds dea = infections.rows[idx].death
    return 0 <= dea <= t
end
isdead(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_dead(individual, infections, pathogen_id, t)
dead(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_dead(individual, infections, pathogen_id, t)

"""
    is_detected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is currently infected with the given pathogen and has been detected (i.e. tested positive) prior to or at tick `t`.
"""
function is_detected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    idx = find_infection_index(individual, infections, pathogen_id)
    idx == 0 && return false
    @inbounds exp = infections.rows[idx].exposure
    @inbounds rec = infections.rows[idx].recovery
    @inbounds dea = infections.rows[idx].death
    
    !(exp >= 0 && exp <= t < max(rec, dea)) && return false
    
    return exp <= last_reported_at(individual)
end
isdetected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_detected(individual, infections, pathogen_id, t)
detected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_detected(individual, infections, pathogen_id, t)

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

"""
    set_progression!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)

Sets an individual's disease progression by pushing a new record to the global 
`InfectionRegistry` struct.
Note: it does not change the health status flags (e.g. infected, symptomatic).
"""
function set_progression!(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)
    # throw exception if agent is already dead
    is_dead(individual) && throw(ArgumentError("Cannot set disease progression of a dead individual (id=$(id(individual)))"))
    
    # Push to the Struct of Arrays
    push_infection!(infections, id(individual), pathogen_id, infection_id, dp)
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


### TESTING STATUS ###

"""
    last_test(individual::Individual)

Returns last test date (tick).
"""
function last_test(individual::Individual)
    return(individual.last_test)
end

"""
    last_test!(individual::Individual, tick::Int16)

Sets last test date (tick).
"""
function last_test!(individual::Individual, tick::Int16)
    individual.last_test = tick
end

"""
    last_test_result(individual::Individual)

Returns whether last test was positive.
Defaults to false.
"""
function last_test_result(individual::Individual)
    return(individual.last_test_result)
end

"""
    last_test_result!(individual::Individual, test_result::Bool)

Sets last test result.
"""
function last_test_result!(individual::Individual, test_result::Bool)
    individual.last_test_result = test_result
end

"""
    last_reported_at(individual::Individual)

Returns the last tick this individual was a reported case.
"""
function last_reported_at(individual::Individual)
    return(individual.last_reported_at)
end

"""
    last_reported_at!(individual::Individual, report_tick::Int16)

Sets last tick this individual was last reported.
"""
function last_reported_at!(individual::Individual, report_tick::Int16)
    individual.last_reported_at = report_tick
end



### VACCINATION STATUS ###

function vaccinate!(individual::Individual, vaccine::Vaccine, tick::Int16, registry::ImmunityRegistry)
    log!(logger(vaccine), id(individual), tick)
    push_immunity!(
        registry,
        id(individual),
        target_pathogen_id(vaccine),
        IMMUNITY_SOURCE_VACCINE,
        tick,
        id(vaccine),
    )
    individual.needs_immunity_update = true
end

"""
    isvaccinated(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns wether the individual is vaccinated.
"""
function isvaccinated(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Bool
    _, idx = _find_slot_and_row_ir(registry, individual.id, pathogen_id, IMMUNITY_SOURCE_VACCINE)
    return idx != 0
end
"""
    vaccine_id(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns the id of the vaccine the individual is vaccinated with.
"""
function vaccine_id(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Int8
    _, idx = _find_slot_and_row_ir(registry, individual.id, pathogen_id, IMMUNITY_SOURCE_VACCINE)
    idx == 0 && return DEFAULT_VACCINE_ID
    return registry.rows[idx].vaccine_id
end

"""
    vaccination_tick(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns the time of last vaccination.
"""
function vaccination_tick(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Int16
    _, idx = _find_slot_and_row_ir(registry, individual.id, pathogen_id, IMMUNITY_SOURCE_VACCINE)
    idx == 0 && return DEFAULT_TICK
    return registry.rows[idx].acquired_tick
end

"""
    number_of_vaccinations(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns the number of vaccinations.
"""
function number_of_vaccinations(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Int8
    _, idx = _find_slot_and_row_ir(registry, individual.id, pathogen_id, IMMUNITY_SOURCE_VACCINE)
    idx == 0 && return Int8(0)
    return registry.rows[idx].dose_number
end

"""
    _calculate_immunity(profile::P, state::ImmunityState, tick::Int16)::Int8 where {P <: ImmunityProfile}

Internal barrier function to ensure `calculate_immunity` is statically dispatched on the concrete profile type.
"""
@inline function _calculate_immunity(profile::P, state::ImmunityState, tick::Int16)::Int8 where {P <: ImmunityProfile}
    return calculate_immunity(profile, state, tick)
end

"""
    update_immunity!(individual, registry, pathogens, tick)

Refresh the per-individual immunity cache (`immune_pathogens`, `immunity_level`)
from the `ImmunityRegistry`. For each pathogen with at least one immunity record,
builds a combined `ImmunityState` (natural + vaccine) and calls `calculate_immunity`
once. The result is written to the per-individual NTuple cache; the contact loop
never touches the registry.
"""
function update_immunity!(
        individual::Individual,
        registry::ImmunityRegistry,
        pathogens::Dict{Int8, Pathogen},
        tick::Int16,
)
    _immune_pids = ntuple(_ -> Int8(0), MAX_TRACKED_IMMUNITIES)
    _immune_levels = ntuple(_ -> Int8(0), MAX_TRACKED_IMMUNITIES)
    _cache_slot = 1
    _processed = UInt8(0)
    _all_stable    = true

    @inbounds for s in 1:MAX_TRACKED_IMMUNITIES
        (_processed >> (s - 1)) & UInt8(1) == UInt8(1) && continue

        row_idx = registry.slot_to_row[s, individual.id]
        row_idx == 0 && continue

        pid = registry.rows[row_idx].pathogen_id
        _processed |= UInt8(1) << (s - 1)

        for s2 in (s + 1):MAX_TRACKED_IMMUNITIES
            row_idx2 = registry.slot_to_row[s2, individual.id]
            row_idx2 == 0 && continue
            if registry.rows[row_idx2].pathogen_id == pid
                _processed |= UInt8(1) << (s2 - 1)
                break
            end
        end

        state = get_immunity_state(registry, individual.id, pid)
        profile = immunity_profile(pathogens[pid])
        level = _calculate_immunity(profile, state, tick)
        _all_stable &= immunity_is_stable(profile, state, tick)

        level == Int8(0) && continue

        _immune_pids = Base.setindex(_immune_pids, pid, _cache_slot)
        _immune_levels = Base.setindex(_immune_levels, level, _cache_slot)
        _cache_slot += 1
    end

    individual.immune_pathogens = _immune_pids
    individual.immunity_level = _immune_levels

    if _all_stable
        individual.needs_immunity_update = false
    end

    return nothing
end


### UPDATE DISEASE PROGRESSION IN AGENTS ###

"""
    progress_disease!(individual::Individual, infections::InfectionRegistry, pathogens::Dict{Int8, Pathogen}, tick::Int16)

Updates the proxy disease progression status flags of the individual at the
given tick by reading from the global `InfectionRegistry`. Also populates the
three per-slot tuples on the individual (`active_pathogens`, `infectiousness`,
`infection_ids`) so that the spread/transmission phase later in the same tick
can read everything it needs directly from the individual — no row lookups
required.

`pathogens` is the simulation's pathogen registry; each active slot's
`InfectionState` is fed through that pathogen's `InfectiousnessProfile`
to compute the cached infectiousness level.
"""
function progress_disease!(individual::Individual, infections::InfectionRegistry, pathogens::Dict{Int8, Pathogen}, tick::Int16)
    if individual.dead
        return nothing
    end

    _is_inf, _is_symp, _is_sev = false, false, false
    _is_hosp, _is_icu, _is_vent, _is_det = false, false, false, false

    _active_pids = ntuple(_ -> Int8(0), MAX_CONCURRENT_INFECTIONS)
    _infectiousness = ntuple(_ -> Int8(0), MAX_CONCURRENT_INFECTIONS)
    _infection_ids = ntuple(_ -> DEFAULT_INFECTION_ID, MAX_CONCURRENT_INFECTIONS)
    _slot = 1

    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        row_idx = infections.slot_to_row[s, individual.id]
        row_idx == 0 && continue

        state = get_infection_state(infections, row_idx, individual.id)
        end_tick = max(state.recovery, state.death)

        if 0 <= state.death <= tick
            dead!(individual, true)
            return nothing
        end

        _active = state.exposure <= tick < end_tick
        if _active
            profile = infectiousness_profile(pathogens[state.pathogen_id])
            level = infectiousness(profile, state, tick)
            _active_pids = Base.setindex(_active_pids, state.pathogen_id, _slot)
            _infectiousness = Base.setindex(_infectiousness, level, _slot)
            _infection_ids = Base.setindex(_infection_ids, state.infection_id, _slot)
            _slot += 1
        end

        _is_inf |= _active
        _is_symp |= 0 <= state.symptom_onset <= tick < end_tick
        _is_sev |= 0 <= state.severeness_onset <= tick < state.severeness_offset
        _is_hosp |= 0 <= state.hospital_admission <= tick < state.hospital_discharge
        _is_icu |= 0 <= state.icu_admission <= tick < state.icu_discharge
        _is_vent |= 0 <= state.ventilation_admission <= tick < state.ventilation_discharge
        _is_det |= _active && state.exposure <= last_reported_at(individual)
    end

    # update individual's health status
    infected!(individual, _is_inf)
    symptomatic!(individual, _is_symp)
    severe!(individual, _is_sev)
    hospitalized!(individual, _is_hosp)
    icu!(individual, _is_icu)
    ventilated!(individual, _is_vent)
    detected!(individual, _is_det)

    individual.active_pathogens = _active_pids
    individual.infectiousness = _infectiousness
    individual.infection_ids = _infection_ids

    return nothing
end


### RESET DISEASE PROGRESSION ###
"""
    reset!(individual::Individual, infections::InfectionRegistry)

Resets all non-static values like the disease progression timing.
The individual will get back into a infections where it was never infected, vaccinated, tested, etc.
"""
function reset!(individual::Individual, infections::InfectionRegistry, registry::ImmunityRegistry)
    # health status proxy booleans
    individual.infected = false
    individual.symptomatic = false
    individual.severe = false
    individual.hospitalized = false
    individual.icu = false
    individual.ventilated = false
    individual.dead = false
    individual.detected = false

    # per-slot pathogen state
    individual.active_pathogens = ntuple(_ -> Int8(0), MAX_CONCURRENT_INFECTIONS)
    individual.infectiousness = ntuple(_ -> Int8(0), MAX_CONCURRENT_INFECTIONS)
    individual.infection_ids = ntuple(_ -> DEFAULT_INFECTION_ID, MAX_CONCURRENT_INFECTIONS)

    # immunity cache
    individual.immune_pathogens = ntuple(_ -> Int8(0), MAX_TRACKED_IMMUNITIES)
    individual.immunity_level = ntuple(_ -> Int8(0), MAX_TRACKED_IMMUNITIES)
    individual.needs_immunity_update = false

    # infection count
    individual.number_of_infections = 0

    # remove from global registries
    remove_infection!(infections, individual.id)
    remove_immunity!(registry, individual.id)

    # TESTING
    individual.last_test = DEFAULT_TICK
    individual.last_test_result = false
    individual.last_reported_at = DEFAULT_TICK

    # INTERVENTIONS
    individual.quarantine_status = QUARANTINE_STATE_NO_QUARANTINE
    individual.quarantine_release_tick = DEFAULT_TICK
    individual.quarantine_tick = DEFAULT_TICK
end




### printing

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

        "Last Test" => individual.last_test != DEFAULT_TICK ? individual.last_test : "n/a",
        "Last Test Result" => individual.last_test != DEFAULT_TICK ? individual.last_test_result : "n/a",
        "Last Reported At" => individual.last_reported_at != DEFAULT_TICK ? individual.last_reported_at : "n/a",
        
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