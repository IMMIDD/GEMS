###
### AGENTS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###

# EXPORTS
# types
export Agent
export Individual
# basic attributes
export birthday, age, id, education, occupation, sex
# behaviour
export mandate_compliance, mandate_compliance!, social_factor, social_factor!
# settings
export setting_id, setting_id!, household_id, class_id, office_id, municipality_id
export is_working, is_student, has_municipality
# health status
export comorbidities, dead, kill!, hospital_status
export hospitalized, hospitalize!, ventilated, ventilate!, icu, icu!
# disease progression
export pathogen_id, infection_id, disease_state, infectiousness, number_of_infections
export infected, exposed, infectious
export presymptomatic, presymptomatic!
export symptomatic, symptomatic!
export severe, severe!
export critical, critical!
export exposed_tick, infectious_tick, removed_tick, death_tick
export exposed_tick!, infectious_tick!, removed_tick!, death_tick!
export onset_of_symptoms, onset_of_severeness
export onset_of_symptoms!, onset_of_severeness!
export hospitalized_tick, ventilation_tick, icu_tick
export hospitalized_tick!, ventilation_tick!, icu_tick!
export infectiousness!, recover!
export symptom_category, symptom_category!
export progress_disease!
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
    - `birthday::Date`: Birthday
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
    - `hospital_status::Int8`: State in the hopsital
        (0 = not hospitalized, 1 = hospitalized, 2 = ventilation, 3 = ICU)

- Associated Settings
    - `household::Int32`: Reference to household id
    - `office::Int32`: Reference to office id
    - `schoolclass::Int32`: Reference to schoolclass id
    - `municipality::Int32`: Reference to municipality id

- Pathogen
    - `pathogen_id::Int8`: pathogen identifier
    - `infection_id::Int32`: Current infection id
    - `disease_state::Int8`: Current State in natural disease history 
        (0 = not infected, 1 = Presymptomatic, 2 = Symptomatic, 3 = Severe, 4 = Critical)
    - `symptom_category::Int8`: Endstate in current disease progression. The numbers should align 
        with `disease_state`, but can be interpreted as the symptom category of this case
        (0 = None, 1 = Asymptomatic, 2 = Mild, 3 = Severe, 4 = Critical)
    - `infectiousness::Int8`: an individuals infectiousness (1-127), i.e. for superspreaders
    - `number_of_infections::Int8`: infection count

- Natural Disease History
    - `exposed_tick::Int16`: Tick of most recent infection
    - `infectious_tick::Int16`: Tick of most recent change into "infectious" state (considered asymptomatic)
    - `onset_of_symptoms::Int16`: Tick of the onset of symptoms
    - `onset_of_severeness::Int16`: Tick of onset of severe symptoms
    - `hospitalized_tick::Int16`: Tick of hospitalization
    - `ventilation_tick::Int16`: Tick of ventilation
    - `icu_tick::Int16`: Tick of ICU (Intensive Care Unit)
    - `death_tick::Int16`: Tick of Death
    - `removed_tick::Int16`: Tick of most recent removal event

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
    birthday::Date
    education::Int8 = DEFAULT_SETTING_ID # 1 byte
    occupation::Int16 = DEFAULT_SETTING_ID # 2 byte

    # BEHAVIOR
    social_factor::Float32 = 0 # 4 bytes
    mandate_compliance::Float32 = 0 # 4 bytes

    # HEALTH STATUS
    comorbidities::Vector{Bool} = Vector{Bool}() # 40 + n bytes
    dead:: Bool = false # 1 byte
    hospital_status::Int8 = HOSPITAL_STATUS_NO_HOSPITAL # 0 = not hopsitalized, 1 = hospitalized, 2 = ventilation, 3 = ICU

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
    disease_state::Int8 = DISEASE_STATE_NOT_INFECTED # 1 byte current status of the disease
    symptom_category::Int8 = SYMPTOM_CATEGORY_NOT_INFECTED # 1 byte symptom category when infected
    infectiousness::Int8 = 0 # 1 byte
    number_of_infections::Int8 = 0 # 1 byte

    # NATURAL DISEASE HISTORY
    exposed_tick::Int16 = DEFAULT_TICK # 2 bytes
    infectious_tick::Int16 = DEFAULT_TICK # 2 bytes
    onset_of_symptoms::Int16 = DEFAULT_TICK # 2 bytes when symptoms start (might be unset in asymptomatic cases)
    onset_of_severeness::Int16 = DEFAULT_TICK # 2 bytes when severe symptoms start (might be unset)
    hospitalized_tick::Int16 = DEFAULT_TICK # 2 bytes when the individual should become hospitalized
    ventilation_tick::Int16 = DEFAULT_TICK # 2 bytes when the individual needs ventilation
    icu_tick::Int16 = DEFAULT_TICK # 2 bytes when the individual goes into ICU
    death_tick::Int16 = DEFAULT_TICK # 2 bytes when the individual dies
    removed_tick::Int16 = DEFAULT_TICK # 2 bytes when the individual is recovered

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

Return an individual's birthday.
"""
function birthday(individual::Individual)::birthday
    return individual.birthday
end

"""
    age(individual::Individual, sim::Simulation)

Calculates the age of an individual in days on the current simulation tick.
"""
function age(individual::Individual, sim::Simulation)::Int
    current_date = sim.startdate + Day(tick(sim))
    return (current_date - individual.birthday).value
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
    dead(individual::Individual)

Returns an individual's death flag.
"""
function dead(individual::Individual)::Bool
    return individual.dead
end

"""
    kill!(individual::Individual)

Kills the individual.
"""
function kill!(individual::Individual)
    individual.dead = true
end

"""
    hospital_status(individual::Individual)

Returns the hospital_status of the individual.
"""
function hospital_status(individual::Individual)::Int8
    return individual.hospital_status
end

"""
    hospitalized(individual::Individual)

Returns wether the individual is hospitalized.
"""
function hospitalized(individual::Individual)::Bool
    return individual.hospital_status != HOSPITAL_STATUS_NO_HOSPITAL
end

"""
    hospitalize!(individual::Individual)

Hospitalizes the individual.
"""
function hospitalize!(individual::Individual)
    individual.quarantine_status = QUARANTINE_STATE_HOSPITAL
    individual.hospital_status = HOSPITAL_STATUS_HOSPITALIZED
end

"""
    ventilated(individual::Individual)

Returns wether the individual needs ventilation.
"""
function ventilated(individual::Individual)::Bool
    return individual.hospital_status == HOSPITAL_STATUS_VENTILATION
end

"""
    ventilate!(individual::Individual)

Sets the individual to require ventilation.
"""
function ventilate!(individual::Individual)
    individual.hospital_status = HOSPITAL_STATUS_VENTILATION
end

"""
    icu(individual::Individual)

Returns wether the individual is in ICU.
"""
function icu(individual::Individual)::Bool
    return individual.hospital_status == HOSPITAL_STATUS_ICU
end

"""
    icu!(individual::Individual)

Sets the individual to be in ICU.
"""
function icu!(individual::Individual)
    individual.hospital_status = HOSPITAL_STATUS_ICU
end

### DISEASE STATUS ###

"""
    pathogen_id(individual::Individual)

Returns an individual's pathogen (currently infected).
"""
function pathogen_id(individual::Individual)::Int8
    return individual.pathogen_id
end


"""
    infection_id(individual::Individual)

Returns an individual's infection_id (currently infected).
"""
function infection_id(individual::Individual)::Int32
    return individual.infection_id
end

"""
    disease_state(individual::Individual)

Returns an individual's disease status (currently infected).
"""
function disease_state(individual::Individual)::Int8
    return individual.disease_state
end

"""
    symptom_category(individual::Individual)

Returns an infected individual's symptom category.
"""
function symptom_category(individual::Individual)::Int8
    return individual.symptom_category
end

"""
    symptom_category!(individual::Individual, category::Int8)

Sets an infected individuals symptom_category.
"""
function symptom_category!(individual::Individual, category::Int8)
    individual.symptom_category = category
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
    exposed_tick(individual::Individual)

Returns an individual's exposed tick (currently infected).
"""
function exposed_tick(individual::Individual)::Int16
    return individual.exposed_tick
end

"""
    exposed_tick!(individual::Individual, tick::Int16)

Sets an individual's exposed tick.
"""
function exposed_tick!(individual::Individual, tick::Int16)::Int16
    individual.exposed_tick = tick
end

"""
    infectious_tick(individual::Individual)

Returns an individual's infectious tick (currently infected).
"""
function infectious_tick(individual::Individual)::Int16
    return individual.infectious_tick
end

"""
    infectious_tick!(individual::Individual, tick::Int16)

Sets an individual's infectious tick.
"""
function infectious_tick!(individual::Individual, tick::Int16)
    individual.infectious_tick = tick
end

"""
    onset_of_symptoms(individual::Individual)

Returns an individual's tick for the onset of symptoms, if symptomatic.
"""
function onset_of_symptoms(individual::Individual)::Int16
    return individual.onset_of_symptoms
end

"""
    onset_of_symptoms!(individual::Individual, tick::Int16)

Sets an individual's tick for the onset of symptoms, if symptomatic.
"""
function onset_of_symptoms!(individual::Individual, tick::Int16)
    individual.onset_of_symptoms = tick
end

"""
    onset_of_severeness(individual::Individual)

Returns an individual's tick for the onset of severe symptoms, if it's a severe case.
"""
function onset_of_severeness(individual::Individual)::Int16
    return individual.onset_of_severeness
end

"""
    onset_of_severeness!(individual::Individual, tick::Int16)

Sets an individual's tick for the onset of severe symptoms, if it's a severe case.
"""
function onset_of_severeness!(individual::Individual, tick::Int16)
    individual.onset_of_severeness = tick
end

"""
    hospitalized_tick(individual::Individual)

Returns an individual's tick for when it gets hospitalized.
"""
function hospitalized_tick(individual::Individual)::Int16
    return individual.hospitalized_tick
end

"""
    hospitalized_tick!(individual::Individual, tick::Int16)

Sets an individual's tick for when it gets hospitalized.
"""
function hospitalized_tick!(individual::Individual, tick::Int16)
    individual.hospitalized_tick = tick
end

"""
    ventilation_tick(individual::Individual)

Returns an individual's tick when it gets ventilated.
"""
function ventilation_tick(individual::Individual)::Int16
    return individual.ventilation_tick
end

"""
    ventilation_tick!(individual::Individual, tick::Int16)

Sets an individual's tick for when it gets ventilated.
"""
function ventilation_tick!(individual::Individual, tick::Int16)
    individual.ventilation_tick = tick
end


"""
    icu_tick(individual::Individual)

Returns an individual's tick when it will be delivered into icu.
"""
function icu_tick(individual::Individual)::Int16
    return individual.icu_tick
end

"""
    icu_tick!(individual::Individual, tick::Int16)

Sets an individual's tick for when it will be delivered into icu.
"""
function icu_tick!(individual::Individual, tick::Int16)
    individual.icu_tick = tick
end

"""
    death_tick(individual::Individual)

Returns an individual's death tick.
"""
function death_tick(individual::Individual)::Int16
    return individual.death_tick
end

"""
    death_tick!(individual::Individual, tick::Int16)

Sets an individual's death tick.
"""
function death_tick!(individual::Individual, tick::Int16)
    individual.death_tick = tick
end

"""
    removed_tick(individual::Individual)

Returns an individual's removed tick (currently infected).
"""
function removed_tick(individual::Individual)::Int16
    return individual.removed_tick
end

"""
    removed_tick!(individual::Individual, tick::Int16)

Sets an individual's removed tick (currently infected).
"""
function removed_tick!(individual::Individual, tick::Int16)
    individual.removed_tick = tick
end

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

"""
    recover!(individual::Individual)

Recovers the individual from its infection.
"""
function recover!(individual::Individual)
    individual.hospital_status = HOSPITAL_STATUS_NO_HOSPITAL
    individual.disease_state = DISEASE_STATE_NOT_INFECTED
    individual.infectiousness = 0
end

"""
    infected(individual::Individual)

Returns whether an individual is currently infected.
"""
function infected(individual::Individual)::Bool
    return disease_state(individual) > DISEASE_STATE_NOT_INFECTED
end

"""
    infectious(individual::Individual)

Returns whether an individual is currently infectious.
"""
function infectious(individual::Individual)::Bool
    return infectiousness(individual) > 0
end

"""
    exposed(individual::Individual)

Returns wether the individual is exposed (infected, but not yet infectious).
"""
function exposed(individual::Individual)::Bool
    return infected(individual) & !infectious(individual)
end

"""
    presymptomatic(individual::Individual)

Returns if individual is asymptomatic.
"""
function presymptomatic(individual::Individual)::Bool
    return individual.disease_state == DISEASE_STATE_PRESYMPTOMATIC
end

"""
    presymptomatic!(individual::Individual)

Marks the individual as asymptomatic, but infectious.
"""
function presymptomatic!(individual::Individual)
    individual.disease_state = DISEASE_STATE_PRESYMPTOMATIC
end

"""
    symptomatic(individual::Individual)

Returns wether the individual is symptomatic.
"""
function symptomatic(individual::Individual)::Bool
    return individual.disease_state == DISEASE_STATE_SYMPTOMATIC
end

"""
    symptomatic!(individual::Individual)

Marks the individual as symptomatic.
"""
function symptomatic!(individual::Individual)
    individual.disease_state = DISEASE_STATE_SYMPTOMATIC
end

"""
    severe(individual::Individual)

Returns wether the individual's disease is severe.
"""
function severe(individual::Individual)::Bool
    return individual.disease_state == DISEASE_STATE_SEVERE
end

"""
    severe!(individual::Individual)

Marks the individual's disease to be severe.
"""
function severe!(individual::Individual)
    individual.disease_state = DISEASE_STATE_SEVERE
end

"""
    critical(individual::Individual)

Returns wether the individual's condition is critical.
"""
function critical(individual::Individual)
    return individual.disease_state == DISEASE_STATE_CRITICAL
end

"""
    critical!(individual::Individual)

Marks the individual's condition as critical.
"""
function critical!(individual::Individual)
    individual.disease_state = DISEASE_STATE_CRITICAL
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
    individual.dead = false
    individual.hospital_status = HOSPITAL_STATUS_NO_HOSPITAL
    # infections status
    individual.pathogen_id = DEFAULT_PATHOGEN_ID
    individual.disease_state = DISEASE_STATE_NOT_INFECTED
    individual.infectiousness = 0
    individual.number_of_infections = 0
    # reset disease progression
    individual.exposed_tick = DEFAULT_TICK
    individual.infectious_tick = DEFAULT_TICK
    individual.onset_of_symptoms = DEFAULT_TICK
    individual.onset_of_severeness = DEFAULT_TICK
    individual.hospitalized_tick = DEFAULT_TICK
    individual.ventilation_tick = DEFAULT_TICK
    individual.icu_tick = DEFAULT_TICK
    individual.death_tick = DEFAULT_TICK
    individual.removed_tick = DEFAULT_TICK
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
    sex_str = individual.sex == 1 ? "Female" : individual.sex == 2 ? "Male" : "Diverse"

    attributes = [
        "ID" => individual.id,
        "Birthday" => individual.birthday,
        "Sex" => sex_str,
        "Education" => individual.education,
        "Occupation" => individual.occupation,
        "Social Factor" => individual.social_factor,
        "Mandate Compliance" => individual.mandate_compliance,
        "Dead" => individual.dead,
        "Hospital Status" => individual.hospital_status,
        "Household ID" => individual.household,
        "Office ID" => individual.office,
        "School Class ID" => individual.schoolclass,
        "Municipality ID" => individual.municipality,
        "Pathogen ID" => individual.pathogen_id,
        "Infection ID" => individual.infection_id,
        "Disease State" => individual.disease_state,
        "Symptom Category" => individual.symptom_category,
        "Infectiousness" => individual.infectiousness,
        "Number of Infections" => individual.number_of_infections,
        "Exposed Tick" => individual.exposed_tick,
        "Infectious Tick" => individual.infectious_tick,
        "Onset of Symptoms" => individual.onset_of_symptoms,
        "Onset of Severeness" => individual.onset_of_severeness,
        "Hospitalized Tick" => individual.hospitalized_tick,
        "Ventilation Tick" => individual.ventilation_tick,
        "ICU Tick" => individual.icu_tick,
        "Death Tick" => individual.death_tick,
        "Removed Tick" => individual.removed_tick,
        "Last Test" => individual.last_test,
        "Last Test Result" => individual.last_test_result,
        "Last Reported At" => individual.last_reported_at,
        "Vaccine ID" => individual.vaccine_id,
        "Number of Vaccinations" => individual.number_of_vaccinations,
        "Vaccination Tick" => individual.vaccination_tick,
        "Quarantine Status" => individual.quarantine_status,
        "Quarantine Tick" => individual.quarantine_tick,
        "Quarantine Release Tick" => individual.quarantine_release_tick
    ]

    max_label_length = maximum(length ∘ first, attributes)

    println(io, "Individual")
    for (label, value) in attributes
        println(io, "  ", rpad(label * ":", max_label_length + 3), value)
    end
end

function Base.show(io::IO, ::MIME"text/plain", individuals::Vector{Individual})
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