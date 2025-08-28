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
export setting_id, setting_id!, household_id, class_id, office_id, municipality_id
export is_working, is_student, has_municipality
# health status
export comorbidities
export is_infected, isinfected, infected, infect!
export is_infectious, isinfectious, infectious, infectious!
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
export quarantine_status, home_quarantine!, end_quarantine!, isquarantined


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

- Health Status
    - `comorbidities::Vector{Bool}`: Indicating prevalence of certain health conditions. True,
        if the individual is preconditioned with the comorbidity associated to the array index.
    - `dead::Bool`: Flag indicating individual's decease
    - `infected::Bool`: Flag indicating individual's infection status

- Associated Settings
    - `household::Int32`: Reference to household id
    - `office::Int32`: Reference to office id
    - `schoolclass::Int32`: Reference to schoolclass id
    - `municipality::Int32`: Reference to municipality id

- Pathogen
    - `pathogen_id::Int8`: pathogen identifier
    - `infection_id::Int32`: Current infection id
    - `infectiousness::Int8`: an individuals infectiousness (1-127), i.e. for superspreaders
    - `number_of_infections::Int8`: infection count

- Natural Disease History
    - `exposure::Int16`: Tick of most recent exposure
    - `infectiousness_onset::Int16`: Tick of most recent change into "infectious" state
    - `symptom_onset::Int16`: Tick of the onset of symptoms
    - `severeness_onset::Int16`: Tick of onset of severe symptoms
    - `hospital_admission::Int16`: Tick of hospitalization
    - `icu_admission::Int16`: Tick of ICU (Intensive Care Unit) admission
    - `icu_discharge::Int16`: Tick of ICU (Intensive Care Unit) discharge
    - `ventilation_admission::Int16`: Tick of ventilation admission
    - `ventilation_discharge::Int16`: Tick of ventilation discharge
    - `hospital_discharge::Int16`: Tick of hospital discharge
    - `recovery::Int16`: Tick of most recent recovery
    - `death::Int16`: Tick of Death

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
    comorbidities::Vector{Bool} = Vector{Bool}() # 40 + n bytes
    infected::Bool = false # 1 byte
    infectious::Bool = false # 1 byte
    symptomatic::Bool = false # 1 byte
    severe::Bool = false # 1 byte
    hospitalized::Bool = false # 1 byte
    icu::Bool = false # 1 byte
    ventilated::Bool = false # 1 byte
    dead:: Bool = false # 1 byte

    # ASSIGNED SETTINGS
    household::Int32 = DEFAULT_SETTING_ID # 4 bytes
    office::Int32 = DEFAULT_SETTING_ID # 4 bytes
    schoolclass::Int32 = DEFAULT_SETTING_ID # 4 bytes
    municipality::Int32 = DEFAULT_SETTING_ID # 4 bytes
    # PATHOGEN
    #= TODO this will have to be adapted for a multi-pathogen scenario.
    Either by making converting this in an indivial-pathogen information object
    and storing all of them in a vector, or, by making all attributes a vector and
    adress then via the index (large memory overhead), or, have a flat table for
    each attribute as a global lookup table (which would only require one vector per
    attribute and not per individual)=#
    pathogen_id::Int8 = DEFAULT_PATHOGEN_ID # 1 byte
    infection_id::Int32 = DEFAULT_INFECTION_ID # 4 bytes identifier of current infection in logger
    infectiousness::Int8 = 0 # 1 byte
    number_of_infections::Int8 = 0 # 1 byte

    # NATURAL DISEASE HISTORY
    exposure::Int16 = DEFAULT_TICK # 2 bytes
    infectiousness_onset::Int16 = DEFAULT_TICK # 2 bytes
    symptom_onset::Int16 = DEFAULT_TICK # 2 bytes when symptoms start (might be unset in asymptomatic cases)
    severeness_onset::Int16 = DEFAULT_TICK # 2 bytes when severe symptoms start (might be unset)
    hospital_admission::Int16 = DEFAULT_TICK # 2 bytes when the individual should become hospitalized
    icu_admission::Int16 = DEFAULT_TICK # 2 bytes when the individual should be admitted to ICU
    icu_discharge::Int16 = DEFAULT_TICK # 2 bytes when the individual is discharged from ICU
    ventilation_admission::Int16 = DEFAULT_TICK # 2 bytes when the individual should be admitted to ventilation
    ventilation_discharge::Int16 = DEFAULT_TICK # 2 bytes when the individual is discharged from ventilation
    hospital_discharge::Int16 = DEFAULT_TICK # 2 bytes when the individual is discharged from hospital
    severeness_offset::Int16 = DEFAULT_TICK # 2 bytes when the individual is no longer severe
    recovery::Int16 = DEFAULT_TICK # 2 bytes when the individual is recovered
    death::Int16 = DEFAULT_TICK # 2 bytes when the individual dies
    
    # TESTING
    last_test::Int16 = DEFAULT_TICK # 2 bytes
    last_test_result::Bool = false # 1 byte
    last_reported_at::Int16 = DEFAULT_TICK # 2 bytes

    # VACCINATION
    #= TODO this will have to be adapted for a multi-pathogen scenario.
    See "pathogen" (above) for explanation. Problem is the same=#
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
function comorbidities(individual::Individual)::Array{Bool}
    return individual.comorbidities
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
    infect!(individual::Individual, infected::Bool)

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


### NATURAL DIESEASE HISTORY ###

"""
    exposure(individual::Individual)

Returns an individual's last exposure tick.
Returun -1 if never exposed.
"""
exposure(individual::Individual) = individual.exposure

"""
    exposure!(individual::Individual, tick::Int16)

Sets an individual's exposure tick.
"""
exposure!(individual::Individual, tick::Int16) = (individual.exposure = tick)

"""
    infectiousness_onset(individual::Individual)

Returns an individual's last infectiousness onset tick.
Return -1 if never infectious.
"""
infectiousness_onset(individual::Individual) = individual.infectiousness_onset

"""
    infectiousness_onset!(individual::Individual, tick::Int16)

Sets an individual's infectiousness onset tick.
"""
infectiousness_onset!(individual::Individual, tick::Int16) = (individual.infectiousness_onset = tick)

"""
    symptom_onset(individual::Individual)

Returns an individual's last symptom onset tick.
Return -1 if never symptomatic.
"""
symptom_onset(individual::Individual) = individual.symptom_onset

"""
    symptom_onset!(individual::Individual, tick::Int16)

Sets an individual's symptom onset tick.
"""
symptom_onset!(individual::Individual, tick::Int16) = (individual.symptom_onset = tick)

"""
    severeness_onset(individual::Individual)

Returns an individual's last severeness onset tick.
Return -1 if never severe.
"""
severeness_onset(individual::Individual) = individual.severeness_onset

"""
    severeness_onset!(individual::Individual, tick::Int16)

Sets an individual's severeness onset tick.
"""
severeness_onset!(individual::Individual, tick::Int16) = (individual.severeness_onset = tick)

"""
    severeness_offset(individual::Individual)

Returns an individual's last severeness offset tick.
Return -1 if never severe.
"""
severeness_offset(individual::Individual) = individual.severeness_offset

"""
    severeness_offset!(individual::Individual, tick::Int16)

Sets an individual's severeness offset tick.
"""
severeness_offset!(individual::Individual, tick::Int16) = (individual.severeness_offset = tick)

"""
    hospital_admission(individual::Individual)

Returns an individual's last hospital admission tick.
Return -1 if never hospitalized.
"""
hospital_admission(individual::Individual) = individual.hospital_admission

"""
    hospital_admission!(individual::Individual, tick::Int16)

Sets an individual's hospital admission tick.
"""
hospital_admission!(individual::Individual, tick::Int16) = (individual.hospital_admission = tick)

"""
    icu_admission(individual::Individual)

Returns an individual's last icu admission tick.
Return -1 if never admitted to icu.
"""
icu_admission(individual::Individual) = individual.icu_admission

"""
    icu_admission!(individual::Individual, tick::Int16)

Sets an individual's icu admission tick.
"""
icu_admission!(individual::Individual, tick::Int16) = (individual.icu_admission = tick)

"""
    icu_discharge(individual::Individual)

Returns an individual's last icu discharge tick.
Return -1 if never discharged from icu.
"""
icu_discharge(individual::Individual) = individual.icu_discharge

"""
    icu_discharge!(individual::Individual, tick::Int16)

Sets an individual's icu discharge tick.
"""
icu_discharge!(individual::Individual, tick::Int16) = (individual.icu_discharge = tick)

"""
    ventilation_admission(individual::Individual)

Returns an individual's last ventilation admission tick.
Return -1 if never admitted to ventilation.
"""
ventilation_admission(individual::Individual) = individual.ventilation_admission

"""
    ventilation_admission!(individual::Individual, tick::Int16)

Sets an individual's ventilation admission tick.
"""
ventilation_admission!(individual::Individual, tick::Int16) = (individual.ventilation_admission = tick)

"""
    ventilation_discharge(individual::Individual)

Returns an individual's last ventilation discharge tick.
Return -1 if never discharged from ventilation.
"""
ventilation_discharge(individual::Individual) = individual.ventilation_discharge

"""
    ventilation_discharge!(individual::Individual, tick::Int16)

Sets an individual's ventilation discharge tick.
"""
ventilation_discharge!(individual::Individual, tick::Int16) = (individual.ventilation_discharge = tick)

"""
    hospital_discharge(individual::Individual)

Returns an individual's last hospital discharge tick.
Return -1 if never discharged from hospital.
"""
hospital_discharge(individual::Individual) = individual.hospital_discharge

"""
    hospital_discharge!(individual::Individual, tick::Int16)

Sets an individual's hospital discharge tick.
"""
hospital_discharge!(individual::Individual, tick::Int16) = (individual.hospital_discharge = tick)

"""
    recovery(individual::Individual)

Returns an individual's last recovery tick.
Return -1 if never recovered.
"""
recovery(individual::Individual) = individual.recovery

"""
    recovery!(individual::Individual, tick::Int16)

Sets an individual's recovery tick.
"""
recovery!(individual::Individual, tick::Int16) = (individual.recovery = tick)

"""
    death(individual::Individual)

Returns an individual's last death tick.
Return -1 if never died.
"""
death(individual::Individual) = individual.death

"""
    death!(individual::Individual, tick::Int16)

Sets an individual's death tick.
"""
death!(individual::Individual, tick::Int16) = (individual.death = tick)


### DISEASE STATUS ###


"""
    is_infected(individual::Individual, t::Int16)
    isinfected(individual::Individual, t::Int16)
    infected(individual::Individual, t::Int16)

Returns `true` if the individual is infected at tick `t`.
"""
is_infected(individual::Individual, t::Int16) = exposure(individual) >= 0 && exposure(individual) <= t < max(recovery(individual), death(individual))
isinfected(individual::Individual, t::Int16) = is_infected(individual, t)
infected(individual::Individual, t::Int16) = is_infected(individual, t)


"""
    is_infectious(individual::Individual, t::Int16)
    isinfectious(individual::Individual, t::Int16)
    infectious(individual::Individual, t::Int16)

Returns `true` if the individual is infectious at tick `t`.
"""
is_infectious(individual::Individual, t::Int16) = is_infected(individual, t) && infectiousness_onset(individual) <= t < max(recovery(individual), death(individual))
isinfectious(individual::Individual, t::Int16) = is_infectious(individual, t)
infectious(individual::Individual, t::Int16) = is_infectious(individual, t)

"""
    is_presymptomatic(individual::Individual, t::Int16)
    ispresymptomatic(individual::Individual, t::Int16)
    presymptomatic(individual::Individual, t::Int16)

Returns `true` if the individual is presymptomatic at tick `t`.
Presymptomatic means infected, will develop symptoms, but is not yet symptomatic.
"""
is_presymptomatic(individual::Individual, t::Int16) = is_infected(individual, t) && t < symptom_onset(individual)
ispresymptomatic(individual::Individual, t::Int16) = is_presymptomatic(individual, t)
presymptomatic(individual::Individual, t::Int16) = is_presymptomatic(individual, t)

"""
    is_symptomatic(individual::Individual, t::Int16)
    issymptomatic(individual::Individual, t::Int16)
    symptomatic(individual::Individual, t::Int16)

Returns `true` if the individual is symptomatic at tick `t`.
"""
is_symptomatic(individual::Individual, t::Int16) = is_infected(individual, t) && 0 <= symptom_onset(individual) <= t < max(recovery(individual), death(individual))
issymptomatic(individual::Individual, t::Int16) = is_symptomatic(individual, t)
symptomatic(individual::Individual, t::Int16) = is_symptomatic(individual, t)

"""
    is_asymptomatic(individual::Individual, t::Int16)
    isasymptomatic(individual::Individual, t::Int16)
    asymptomatic(individual::Individual, t::Int16)

Returns `true` if the individual is asymptomatic at tick `t`.
Asymptomatic means infected and will not develop symptoms.
"""
is_asymptomatic(individual::Individual, t::Int16) = is_infected(individual, t) && !is_symptomatic(individual, t) && symptom_onset(individual) >= 0
isasymptomatic(individual::Individual, t::Int16) = is_asymptomatic(individual, t)
asymptomatic(individual::Individual, t::Int16) = is_asymptomatic(individual, t)

"""
    is_severe(individual::Individual, t::Int16)
    issevere(individual::Individual, t::Int16)
    severe(individual::Individual, t::Int16)

Returns `true` if the individual is in a severe state at tick `t`.
"""
is_severe(individual::Individual, t::Int16) = is_infected(individual, t) && 0 <= severeness_onset(individual) <= t < severeness_offset(individual)
issevere(individual::Individual, t::Int16) = is_severe(individual, t)
severe(individual::Individual, t::Int16) = is_severe(individual, t)

"""
    is_mild(individual::Individual, t::Int16)
    ismild(individual::Individual, t::Int16)
    mild(individual::Individual, t::Int16)

Returns `true` if the individual is in a mild state at tick `t`.
Mild means symptomatic but not severe.
"""
is_mild(individual::Individual, t::Int16) = is_symptomatic(individual, t) && !is_severe(individual, t)
ismild(individual::Individual, t::Int16) = is_mild(individual, t)
mild(individual::Individual, t::Int16) = is_mild(individual, t)

"""
    is_hospitalized(individual::Individual, t::Int16)    
    ishospitalized(individual::Individual, t::Int16)
    hospitalized(individual::Individual, t::Int16)

Returns `true` if the individual is hospitalized at tick `t`.
"""
is_hospitalized(individual::Individual, t::Int16) = is_infected(individual, t) && 0 <= hospital_admission(individual) <= t < hospital_discharge(individual)
ishospitalized(individual::Individual, t::Int16) = is_hospitalized(individual, t)
hospitalized(individual::Individual, t::Int16) = is_hospitalized(individual, t)

"""
    is_icu(individual::Individual, t::Int16)
    isicu(individual::Individual, t::Int16)
    icu(individual::Individual, t::Int16)

Returns `true` if the individual is in ICU at tick `t`.
"""
is_icu(individual::Individual, t::Int16) = is_hospitalized(individual, t) && 0 <= icu_admission(individual) <= t < icu_discharge(individual)
isicu(individual::Individual, t::Int16) = is_icu(individual, t)
icu(individual::Individual, t::Int16) = is_icu(individual, t)

"""
    is_ventilated(individual::Individual, t::Int16)
    isventilated(individual::Individual, t::Int16)
    ventilated(individual::Individual, t::Int16)

Returns `true` if the individual is ventilated at tick `t`.
"""
is_ventilated(individual::Individual, t::Int16) = is_hospitalized(individual, t) && 0 <= ventilation_admission(individual) <= t < ventilation_discharge(individual)
isventilated(individual::Individual, t::Int16) = is_ventilated(individual, t)
ventilated(individual::Individual, t::Int16) = is_ventilated(individual, t)

"""
    is_recovered(individual::Individual, t::Int16)
    isrecovered(individual::Individual, t::Int16)
    recovered(individual::Individual, t::Int16)

Returns `true` if the individual is recovered at tick `t`.
"""
is_recovered(individual::Individual, t::Int16) = 0 <= recovery(individual) <= t
isrecovered(individual::Individual, t::Int16) = is_recovered(individual, t)
recovered(individual::Individual, t::Int16) = is_recovered(individual, t)

"""
    is_dead(individual::Individual, t::Int16)
    isdead(individual::Individual, t::Int16)
    dead(individual::Individual, t::Int16)

Returns `true` if the individual is dead at tick `t`.
"""
is_dead(individual::Individual, t::Int16) = 0 <= death(individual) <= t
isdead(individual::Individual, t::Int16) = is_dead(individual, t)
dead(individual::Individual, t::Int16) = is_dead(individual, t)

"""
    pathogen_id(individual::Individual)

Returns an individual's pathogen (currently infected).
"""
function pathogen_id(individual::Individual)::Int8
    return individual.pathogen_id
end

"""
    pathogen_id!(individual::Individual, pathogen_id::Int8)

Sets an individual's pathogen (currently infected).
"""
function pathogen_id!(individual::Individual, pathogen_id::Int8)
    individual.pathogen_id = pathogen_id
end


"""
    infection_id(individual::Individual)

Returns an individual's infection_id (currently infected).
"""
function infection_id(individual::Individual)::Int32
    return individual.infection_id
end

"""
    infection_id!(individual::Individual, infection_id::Int32)

Sets an individual's infection_id (currently infected).
"""
function infection_id!(individual::Individual, infection_id::Int32)
    individual.infection_id = infection_id
end

"""
    infectiousness(individual::Individual)

Returns an individual's infectiousness (currently infected).
"""
function infectiousness(individual::Individual)::Int8
    return individual.infectiousness
end

"""
    infectiousness!(individual::Individual, infectiousness)

Assigns a specified infectiousness (0-127) to an individual.
"""
function infectiousness!(individual::Individual, infectiousness)
    individual.infectiousness = Int8(infectiousness)
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

"""
    set_progression!(individual::Individual, dp::DiseaseProgression)

Sets an individual's disease progression according to the provided `DiseaseProgression` object.
Note: it only sets the fields but does not change the health status flags (e.g. infected, symptomatic, etc...).
"""
function set_progression!(individual::Individual, dp::DiseaseProgression)
    # throw exception if agent is already dead
    is_dead(individual) && throw(ArgumentError("Cannot set disease progression of a dead individual (id=$(id(individual)))"))

    # set all fields of the disease progression
    exposure!(individual, exposure(dp))
    infectiousness_onset!(individual, infectiousness_onset(dp))
    symptom_onset!(individual, symptom_onset(dp))
    severeness_onset!(individual, severeness_onset(dp))
    hospital_admission!(individual, hospital_admission(dp))
    icu_admission!(individual, icu_admission(dp))
    icu_discharge!(individual, icu_discharge(dp))
    ventilation_admission!(individual, ventilation_admission(dp))
    ventilation_discharge!(individual, ventilation_discharge(dp))
    hospital_discharge!(individual, hospital_discharge(dp))
    recovery!(individual, recovery(dp))
    death!(individual, death(dp))
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
    isquarantined(individual::Individual)

Returns wether the individual is in quarantine or not.
"""
function isquarantined(individual::Individual)::Bool
    return individual.quarantine_status != QUARANTINE_STATE_NO_QUARANTINE
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

"""
    isdetected(individual::Individual)

Returns true if an individual was currently infected and already reported.
"""
function isdetected(individual::Individual)
    return infected(individual) && exposed_tick(individual) <= last_reported_at(individual) <= removed_tick(individual)
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

### RESET DISEASE PROGRESSION ###
"""
    reset!(individual::Individual)

Resets all non-static values like the disease progression timing. The individual will get
back into a state where it was never infected, vaccinated, tested, etc.
"""
function reset!(individual::Individual)
    # health status
    individual.infected = false
    individual.infectious = false
    individual.symptomatic = false
    individual.severe = false
    individual.hospitalized = false
    individual.isicu = false
    individual.ventilated = false
    individual.dead = false
    # infections status
    individual.pathogen_id = DEFAULT_PATHOGEN_ID
    individual.disease_state = DISEASE_STATE_NOT_INFECTED
    individual.infectiousness = 0
    individual.number_of_infections = 0
    # reset disease progression
    individual.exposure = DEFAULT_TICK
    individual.infectiousness_onset = DEFAULT_TICK
    individual.symptom_onset = DEFAULT_TICK
    individual.severeness_onset = DEFAULT_TICK
    individual.hospital_admission = DEFAULT_TICK
    individual.icu_admission = DEFAULT_TICK
    individual.icu_discharge = DEFAULT_TICK
    individual.ventilation_admission = DEFAULT_TICK
    individual.ventilation_discharge = DEFAULT_TICK
    individual.hospital_discharge = DEFAULT_TICK
    individual.recovery = DEFAULT_TICK
    individual.death = DEFAULT_TICK
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

        "Pathogen ID" => individual.pathogen_id != DEFAULT_PATHOGEN_ID ? individual.pathogen_id : "n/a",
        "Infection ID" => individual.infection_id != DEFAULT_INFECTION_ID ? individual.infection_id : "n/a",
        "Infectiousness" => individual.infectiousness,
        "Number of Infections" => individual.number_of_infections,

        "Exposure Tick" => individual.exposure != DEFAULT_TICK ? individual.exposure : "n/a",
        "Infectiousness Onset Tick" => individual.infectiousness_onset != DEFAULT_TICK ? individual.infectiousness_onset : "n/a",
        "Symptom Onset Tick" => individual.symptom_onset != DEFAULT_TICK ? individual.symptom_onset : "n/a",
        "Severeness Onset Tick" => individual.severeness_onset != DEFAULT_TICK ? individual.severeness_onset : "n/a",
        "Hospital Admission Tick" => individual.hospital_admission != DEFAULT_TICK ? individual.hospital_admission : "n/a",
        "ICU Admission Tick" => individual.icu_admission != DEFAULT_TICK ? individual.icu_admission : "n/a",
        "ICU Discharge Tick" => individual.icu_discharge != DEFAULT_TICK ? individual.icu_discharge : "n/a",
        "Ventilation Admission Tick" => individual.ventilation_admission != DEFAULT_TICK ? individual.ventilation_admission : "n/a",
        "Ventilation Discharge Tick" => individual.ventilation_discharge != DEFAULT_TICK ? individual.ventilation_discharge : "n/a",
        "Hospital Discharge Tick" => individual.hospital_discharge != DEFAULT_TICK ? individual.hospital_discharge : "n/a",
        "Death Tick" => individual.death != DEFAULT_TICK ? individual.death : "n/a",
        "Recovery Tick" => individual.recovery != DEFAULT_TICK ? individual.recovery : "n/a",

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