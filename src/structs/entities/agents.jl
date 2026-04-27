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
export is_infectious, isinfectious, infectious, infectious!
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
export pathogen_id, pathogen_id!, infection_id, infection_id!
export infectiousness, infectiousness!
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
       -1 and 1 with neutral state is 0.
    - `mandate_compliance::Float32`. Paremeter which influences the probability of complying
        to mandates. Can be anywhere between -1 and 1 with neutral state is 0.

- Health Status (Proxy Flags)
    - `comorbidities::UInt16`: Indicating prevalence of certain health conditions.
    - `dead::Bool`: Flag indicating individual's decease
    - `infected::Bool`: Flag indicating individual's infection status
    - `infectious::Bool`: Flag indicating individual is infectious
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

- Testing
    - `last_test::Int16`: Tick of last test for pathogen
    - `last_test_result::Bool`: Flag for positivity of last test
    - `last_reported_at::Int16`: Tick at which this individual was last reported

- Vaccination
    - `vaccine_id::Int8`: Vaccine identifier
    - `number_of_vaccinations::Int8`: Individual's vaccination counter
    - `vaccination_tick::Int16`: Tick of most recent vaccination

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
    infectious::Bool = false # 1 byte
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
    
    # TESTING
    last_test::Int16 = DEFAULT_TICK # 2 bytes
    last_test_result::Bool = false # 1 byte
    last_reported_at::Int16 = DEFAULT_TICK # 2 bytes

    # VACCINATION
    vaccine_id::Int8 = DEFAULT_VACCINE_ID # 1 byte
    number_of_vaccinations::Int8 = 0 # 1 byte
    vaccination_tick::Int16 = DEFAULT_TICK # 2 bytes

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

Returns the `infectious` flag of the individual.
"""
is_infectious(individual::Individual) = individual.infectious
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
    infectious!(individual::Individual, infectious::Bool)

Sets the `infectious` flag of the individual.
"""
infectious!(individual::Individual, infectious::Bool) = (individual.infectious = infectious)


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

### NATURAL DISEASE HISTORY ###

"""
    get_infection_index(ind::Individual, state::InfectionState)

Instant O(1) lookup to find the row index of an individual's active infection 
in the global `InfectionState` arrays.
"""
@inline function get_infection_index(ind::Individual, state::InfectionState)::Int
    @inbounds idx = state.id_to_index[ind.id]
    idx == 0 && throw(ArgumentError("Individual $(ind.id) is not currently in the active InfectionState."))
    return idx
end

# --- PATHOGEN ATTRIBUTES ---

"""
    pathogen_id(individual::Individual, state::InfectionState)

Returns an individual's pathogen (currently infected).
"""
function pathogen_id(individual::Individual, state::InfectionState)::Int8
    @inbounds idx = state.id_to_index[individual.id]
    return state.pathogen_id[idx]
end

"""
    infection_id(individual::Individual, state::InfectionState)

Returns an individual's infection_id (currently infected).
"""
function infection_id(individual::Individual, state::InfectionState)::Int32
    @inbounds idx = state.id_to_index[individual.id]
    return state.infection_id[idx]
end

"""
    infectiousness(individual::Individual, state::InfectionState)

Returns an individual's infectiousness (currently infected).
"""
function infectiousness(individual::Individual, state::InfectionState)::Int8
    @inbounds idx = state.id_to_index[individual.id]
    return state.infectiousness[idx]
end

"""
    infectiousness!(individual::Individual, state::InfectionState, infectiousness)

Assigns a specified infectiousness (0-127) to an individual.
"""
function infectiousness!(individual::Individual, state::InfectionState, infectiousness)
    idx = get_infection_index(individual, state)
    state.infectiousness[idx] = Int8(infectiousness)
end

"""
    exposure(individual::Individual, state::InfectionState)

Returns an individual's last exposure tick.
Return -1 if never exposed or not in active infection state.
"""
function exposure(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.exposure[idx]
end

"""
    exposure!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's exposure tick.
"""
function exposure!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.exposure[idx] = tick
end

"""
    infectiousness_onset(individual::Individual, state::InfectionState)

Returns an individual's last infectiousness onset tick.
Return -1 if never infectious.
"""
function infectiousness_onset(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.infectiousness_onset[idx]
end

"""
    infectiousness_onset!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's infectiousness onset tick.
"""
function infectiousness_onset!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.infectiousness_onset[idx] = tick
end

"""
    symptom_onset(individual::Individual, state::InfectionState)

Returns an individual's last symptom onset tick.
Return -1 if never symptomatic.
"""
function symptom_onset(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.symptom_onset[idx]
end

"""
    symptom_onset!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's symptom onset tick.
"""
function symptom_onset!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.symptom_onset[idx] = tick
end

"""
    severeness_onset(individual::Individual, state::InfectionState)

Returns an individual's last severeness onset tick.
Return -1 if never severe.
"""
function severeness_onset(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.severeness_onset[idx]
end

"""
    severeness_onset!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's severeness onset tick.
"""
function severeness_onset!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.severeness_onset[idx] = tick
end

"""
    severeness_offset(individual::Individual, state::InfectionState)

Returns an individual's last severeness offset tick.
Return -1 if never severe.
"""
function severeness_offset(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.severeness_offset[idx]
end

"""
    severeness_offset!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's severeness offset tick.
"""
function severeness_offset!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.severeness_offset[idx] = tick
end

"""
    hospital_admission(individual::Individual, state::InfectionState)

Returns an individual's last hospital admission tick.
Return -1 if never hospitalized.
"""
function hospital_admission(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.hospital_admission[idx]
end

"""
    hospital_admission!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's hospital admission tick.
"""
function hospital_admission!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.hospital_admission[idx] = tick
end

"""
    icu_admission(individual::Individual, state::InfectionState)

Returns an individual's last icu admission tick.
Return -1 if never admitted to icu.
"""
function icu_admission(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.icu_admission[idx]
end

"""
    icu_admission!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's icu admission tick.
"""
function icu_admission!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.icu_admission[idx] = tick
end

"""
    icu_discharge(individual::Individual, state::InfectionState)

Returns an individual's last icu discharge tick.
Return -1 if never discharged from icu.
"""
function icu_discharge(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.icu_discharge[idx]
end

"""
    icu_discharge!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's icu discharge tick.
"""
function icu_discharge!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.icu_discharge[idx] = tick
end

"""
    ventilation_admission(individual::Individual, state::InfectionState)

Returns an individual's last ventilation admission tick.
Return -1 if never admitted to ventilation.
"""
function ventilation_admission(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.ventilation_admission[idx]
end

"""
    ventilation_admission!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's ventilation admission tick.
"""
function ventilation_admission!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.ventilation_admission[idx] = tick
end

"""
    ventilation_discharge(individual::Individual, state::InfectionState)

Returns an individual's last ventilation discharge tick.
Return -1 if never discharged from ventilation.
"""
function ventilation_discharge(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.ventilation_discharge[idx]
end

"""
    ventilation_discharge!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's ventilation discharge tick.
"""
function ventilation_discharge!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.ventilation_discharge[idx] = tick
end

"""
    hospital_discharge(individual::Individual, state::InfectionState)

Returns an individual's last hospital discharge tick.
Return -1 if never discharged from hospital.
"""
function hospital_discharge(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.hospital_discharge[idx]
end

"""
    hospital_discharge!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's hospital discharge tick.
"""
function hospital_discharge!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.hospital_discharge[idx] = tick
end

"""
    recovery(individual::Individual, state::InfectionState)

Returns an individual's last recovery tick.
Return -1 if never recovered.
"""
function recovery(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.recovery[idx]
end

"""
    recovery!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's recovery tick.
"""
function recovery!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.recovery[idx] = tick
end

"""
    death(individual::Individual, state::InfectionState)

Returns an individual's last death tick.
Return -1 if never died.
"""
function death(individual::Individual, state::InfectionState)
    @inbounds idx = state.id_to_index[individual.id]
    return idx == 0 ? Int16(-1) : state.death[idx]
end

"""
    death!(individual::Individual, state::InfectionState, tick::Int16)

Sets an individual's death tick.
"""
function death!(individual::Individual, state::InfectionState, tick::Int16)
    idx = get_infection_index(individual, state)
    @inbounds state.death[idx] = tick
end


### DISEASE STATUS ###

"""
    is_infected(individual::Individual, state::InfectionState, t::Int16)
    isinfected(individual::Individual, state::InfectionState, t::Int16)
    infected(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is infected at tick `t`.
"""
is_infected(individual::Individual, state::InfectionState, t::Int16) = exposure(individual, state) >= 0 && exposure(individual, state) <= t < max(recovery(individual, state), death(individual, state))
isinfected(individual::Individual, state::InfectionState, t::Int16) = is_infected(individual, state, t)
infected(individual::Individual, state::InfectionState, t::Int16) = is_infected(individual, state, t)

"""
    is_infectious(individual::Individual, state::InfectionState, t::Int16)
    isinfectious(individual::Individual, state::InfectionState, t::Int16)
    infectious(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is infectious at tick `t`.
"""
is_infectious(individual::Individual, state::InfectionState, t::Int16) = is_infected(individual, state, t) && infectiousness_onset(individual, state) <= t < max(recovery(individual, state), death(individual, state))
isinfectious(individual::Individual, state::InfectionState, t::Int16) = is_infectious(individual, state, t)
infectious(individual::Individual, state::InfectionState, t::Int16) = is_infectious(individual, state, t)

"""
    is_exposed(individual::Individual, state::InfectionState, t::Int16)
    isexposed(individual::Individual, state::InfectionState, t::Int16)
    exposed(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is exposed at tick `t`.
Exposed means infected but not yet infectious.
"""
is_exposed(individual::Individual, state::InfectionState, t::Int16) = is_infected(individual, state, t) && exposure(individual, state) <= t < infectiousness_onset(individual, state)
isexposed(individual::Individual, state::InfectionState, t::Int16) = is_exposed(individual, state, t)
exposed(individual::Individual, state::InfectionState, t::Int16) = is_exposed(individual, state, t)

"""
    is_presymptomatic(individual::Individual, state::InfectionState, t::Int16)
    ispresymptomatic(individual::Individual, state::InfectionState, t::Int16)
    presymptomatic(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is presymptomatic at tick `t`.
Presymptomatic means infected, will develop symptoms, but is not yet symptomatic.
"""
is_presymptomatic(individual::Individual, state::InfectionState, t::Int16) = is_infected(individual, state, t) && t < symptom_onset(individual, state)
ispresymptomatic(individual::Individual, state::InfectionState, t::Int16) = is_presymptomatic(individual, state, t)
presymptomatic(individual::Individual, state::InfectionState, t::Int16) = is_presymptomatic(individual, state, t)

"""
    is_symptomatic(individual::Individual, state::InfectionState, t::Int16)
    issymptomatic(individual::Individual, state::InfectionState, t::Int16)
    symptomatic(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is symptomatic at tick `t`.
"""
is_symptomatic(individual::Individual, state::InfectionState, t::Int16) = is_infected(individual, state, t) && 0 <= symptom_onset(individual, state) <= t < max(recovery(individual, state), death(individual, state))
issymptomatic(individual::Individual, state::InfectionState, t::Int16) = is_symptomatic(individual, state, t)
symptomatic(individual::Individual, state::InfectionState, t::Int16) = is_symptomatic(individual, state, t)

"""
    is_asymptomatic(individual::Individual, state::InfectionState, t::Int16)
    isasymptomatic(individual::Individual, state::InfectionState, t::Int16)
    asymptomatic(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is asymptomatic at tick `t`.
Asymptomatic means infected and will not develop symptoms.
"""
is_asymptomatic(individual::Individual, state::InfectionState, t::Int16) = is_infected(individual, state, t) && !is_symptomatic(individual, state, t) && symptom_onset(individual, state) < exposure(individual, state)
isasymptomatic(individual::Individual, state::InfectionState, t::Int16) = is_asymptomatic(individual, state, t)
asymptomatic(individual::Individual, state::InfectionState, t::Int16) = is_asymptomatic(individual, state, t)

"""
    is_severe(individual::Individual, state::InfectionState, t::Int16)
    issevere(individual::Individual, state::InfectionState, t::Int16)
    severe(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is in a severe state at tick `t`.
"""
is_severe(individual::Individual, state::InfectionState, t::Int16) = is_infected(individual, state, t) && 0 <= severeness_onset(individual, state) <= t < severeness_offset(individual, state)
issevere(individual::Individual, state::InfectionState, t::Int16) = is_severe(individual, state, t)
severe(individual::Individual, state::InfectionState, t::Int16) = is_severe(individual, state, t)

"""
    is_mild(individual::Individual, state::InfectionState, t::Int16)
    ismild(individual::Individual, state::InfectionState, t::Int16)
    mild(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is in a mild state at tick `t`.
Mild means symptomatic but not severe.
"""
is_mild(individual::Individual, state::InfectionState, t::Int16) = is_symptomatic(individual, state, t) && !is_severe(individual, state, t)
ismild(individual::Individual, state::InfectionState, t::Int16) = is_mild(individual, state, t)
mild(individual::Individual, state::InfectionState, t::Int16) = is_mild(individual, state, t)

"""
    is_hospitalized(individual::Individual, state::InfectionState, t::Int16)    
    ishospitalized(individual::Individual, state::InfectionState, t::Int16)
    hospitalized(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is hospitalized at tick `t`.
"""
is_hospitalized(individual::Individual, state::InfectionState, t::Int16) = is_infected(individual, state, t) && 0 <= hospital_admission(individual, state) <= t < hospital_discharge(individual, state)
ishospitalized(individual::Individual, state::InfectionState, t::Int16) = is_hospitalized(individual, state, t)
hospitalized(individual::Individual, state::InfectionState, t::Int16) = is_hospitalized(individual, state, t)

"""
    is_icu(individual::Individual, state::InfectionState, t::Int16)
    isicu(individual::Individual, state::InfectionState, t::Int16)
    icu(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is in ICU at tick `t`.
"""
is_icu(individual::Individual, state::InfectionState, t::Int16) = is_hospitalized(individual, state, t) && 0 <= icu_admission(individual, state) <= t < icu_discharge(individual, state)
isicu(individual::Individual, state::InfectionState, t::Int16) = is_icu(individual, state, t)
icu(individual::Individual, state::InfectionState, t::Int16) = is_icu(individual, state, t)

"""
    is_ventilated(individual::Individual, state::InfectionState, t::Int16)
    isventilated(individual::Individual, state::InfectionState, t::Int16)
    ventilated(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is ventilated at tick `t`.
"""
is_ventilated(individual::Individual, state::InfectionState, t::Int16) = is_hospitalized(individual, state, t) && 0 <= ventilation_admission(individual, state) <= t < ventilation_discharge(individual, state)
isventilated(individual::Individual, state::InfectionState, t::Int16) = is_ventilated(individual, state, t)
ventilated(individual::Individual, state::InfectionState, t::Int16) = is_ventilated(individual, state, t)

"""
    is_recovered(individual::Individual, state::InfectionState, t::Int16)
    isrecovered(individual::Individual, state::InfectionState, t::Int16)
    recovered(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is recovered at tick `t`.
"""
is_recovered(individual::Individual, state::InfectionState, t::Int16) = 0 <= recovery(individual, state) <= t
isrecovered(individual::Individual, state::InfectionState, t::Int16) = is_recovered(individual, state, t)
recovered(individual::Individual, state::InfectionState, t::Int16) = is_recovered(individual, state, t)

"""
    is_dead(individual::Individual, state::InfectionState, t::Int16)
    isdead(individual::Individual, state::InfectionState, t::Int16)
    dead(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is dead at tick `t`.
"""
is_dead(individual::Individual, state::InfectionState, t::Int16) = 0 <= death(individual, state) <= t
isdead(individual::Individual, state::InfectionState, t::Int16) = is_dead(individual, state, t)
dead(individual::Individual, state::InfectionState, t::Int16) = is_dead(individual, state, t)

"""
    is_detected(individual::Individual, state::InfectionState, t::Int16)

Returns `true` if the individual is currently infected and has been detected (i.e. tested positive) prior to or at tick `t`.
"""
is_detected(individual::Individual, state::InfectionState, t::Int16) = is_infected(individual, state, t) && exposure(individual, state) <= last_reported_at(individual)
isdetected(individual::Individual, state::InfectionState, t::Int16) = is_detected(individual, state, t)
detected(individual::Individual, state::InfectionState, t::Int16) = is_detected(individual, state, t)

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
    set_progression!(individual::Individual, state::InfectionState, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)

Sets an individual's disease progression by pushing a new record to the global 
`InfectionState` struct.
Note: it does not change the health status flags (e.g. infected, symptomatic).
"""
function set_progression!(individual::Individual, state::InfectionState, pathogen_id::Int8, infection_id::Int32, dp::DiseaseProgression)
    # throw exception if agent is already dead
    is_dead(individual) && throw(ArgumentError("Cannot set disease progression of a dead individual (id=$(id(individual)))"))
    
    # Push to the Struct of Arrays
    push_infection!(state, id(individual), pathogen_id, infection_id, dp)
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

"""
    vaccinate!(individual::Individual, vaccine::Vaccine, tick::Int16)

Vaccinates the individual with the given vaccine at time `tick`.
"""
function vaccinate!(individual::Individual, vaccine::Vaccine, tick::Int16)
    individual.vaccination_tick = tick
    individual.number_of_vaccinations += 1
    individual.vaccine_id = id(vaccine)

    log!(
        logger(vaccine),
        id(individual),
        tick
    )
end

"""
    isvaccinated(individual::Individual)

Returns wether the individual is vaccinated.
"""
function isvaccinated(individual::Individual)::Bool
    return individual.number_of_vaccinations > 0
end

"""
    vaccine_id(individual::Individual)

Returns the id of the vaccine the individual is vaccinated with.
"""
function vaccine_id(individual::Individual)::Int8
    return individual.vaccine_id
end

"""
    vaccination_tick(individual::Individual)

Returns the time of last vaccination.
"""
function vaccination_tick(individual::Individual)::Int16
    return individual.vaccination_tick
end

"""
    number_of_vaccinations(individual::Individual)

Returns the number of vaccinations.
"""
function number_of_vaccinations(individual::Individual)::Int8
    return individual.number_of_vaccinations
end


### UPDATE DISEASE PROGRESSION IN AGENTS ###

"""
    progress_disease!(individual::Individual, state::InfectionState, tick::Int16)

Updates the proxy disease progression status flags of the individual at the given tick 
by reading from the global InfectionState.
"""
function progress_disease!(individual::Individual, state::InfectionState, tick::Int16)

    # do not update, if individual is dead
    if individual.dead
        return
    end

    # update disease progression proxy status flags in the individual
    infected!(individual, is_infected(individual, state, tick))
    infectious!(individual, is_infectious(individual, state, tick))
    symptomatic!(individual, is_symptomatic(individual, state, tick))
    severe!(individual, is_severe(individual, state, tick))
    hospitalized!(individual, is_hospitalized(individual, state, tick))
    icu!(individual, is_icu(individual, state, tick))
    ventilated!(individual, is_ventilated(individual, state, tick))
    dead!(individual, is_dead(individual, state, tick))
    detected!(individual, is_detected(individual, state, tick))
end


### RESET DISEASE PROGRESSION ###
"""
    reset!(individual::Individual, state::InfectionState)

Resets all non-static values like the disease progression timing.
The individual will get back into a state where it was never infected, vaccinated, tested, etc.
"""
function reset!(individual::Individual, state::InfectionState)
    # health status proxy booleans
    individual.infected = false
    individual.infectious = false
    individual.symptomatic = false
    individual.severe = false
    individual.hospitalized = false
    individual.icu = false
    individual.ventilated = false
    individual.dead = false
    individual.detected = false
    
    # infections status
    individual.number_of_infections = 0
 
    # remove from the global InfectionState registry if they are in it
    if state.id_to_index[individual.id] != 0
        remove_infection!(state, individual.id)
    end
    
    # TESTING
    individual.last_test = DEFAULT_TICK
    individual.last_test_result = false
    individual.last_reported_at = DEFAULT_TICK
    
    # VACCINATION
    individual.vaccine_id = DEFAULT_VACCINE_ID
    individual.number_of_vaccinations = 0
    individual.vaccination_tick = DEFAULT_TICK
    
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

        "Last Test" => individual.last_test != DEFAULT_TICK ? individual.last_test : "n/a",
        "Last Test Result" => individual.last_test != DEFAULT_TICK ? individual.last_test_result : "n/a",
        "Last Reported At" => individual.last_reported_at != DEFAULT_TICK ? individual.last_reported_at : "n/a",
        
        "Vaccine ID" => individual.vaccine_id != DEFAULT_VACCINE_ID ? individual.vaccine_id : "n/a",
        "Number of Vaccinations" => individual.number_of_vaccinations,
        "Vaccination Tick" => individual.vaccination_tick != DEFAULT_TICK ? individual.vaccination_tick : "n/a",
        
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