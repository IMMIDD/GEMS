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
    - `detected::Bool`: Flag indicating individual tested positive
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
    - `number_of_infections::Int8`: Lifetime infection count

- Immunity Memory
    - `immunity_cache::NTuple{N, ImmunityState}`: Fixed-size cache of pathogen immunities
    - `immunity_head::Int32`: Pointer to the first overflow node in the ImmunityRegistry
    - `needs_immunity_update::Bool`: Flag for deferred immunity calculations

- Testing
    - `last_test::Int16`: Tick of last test
    - `last_test_result::Bool`: Flag for positivity of last test
    - `last_reported_at::Int16`: Tick at which this individual was last reported

- Interventions
    - `quarantine_tick::Int16`: Start tick of quarantine
    - `quarantine_release_tick::Int16`: End tick of quarantine
    - `quarantine_status::Int8`: Status indicator (none, household, etc.)
"""
@with_kw_noshow mutable struct Individual <: Agent
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
    detected::Bool = false                  # 1 byte
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
    number_of_infections::Int8 = 0          # 1 byte

    # IMMUNITY MEMORY
    immunity_cache::NTuple{IMMUNITY_CACHE_SIZE, ImmunityState} = ntuple(_ -> ImmunityState(), IMMUNITY_CACHE_SIZE) # IMMUNITY_CACHE_SIZE * sizeof(ImmunityState)
    immunity_head::Int32 = 0                # 4 byte
    needs_immunity_update::Bool = false     # 1 byte
    
    # TESTING
    last_test::Int16 = DEFAULT_TICK         # 2 bytes
    last_test_result::Bool = false          # 1 byte
    last_reported_at::Int16 = DEFAULT_TICK  # 2 bytes

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

Returns (is_cache::Bool, idx::Int32).
"""
@inline function find_infection_index(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8)::Tuple{Bool, Int32}
    @inbounds for i in 1:INFECTIONS_CACHE_SIZE
        s = ind.infection_cache[i]
        s.active && s.pathogen_id == pathogen_id && return (true, Int32(i))
    end
    ind.infection_head != 0 || return (false, Int32(0))
    node = ind.infection_head
    while node != 0
        @inbounds s = infections.states[node]
        s.pathogen_id == pathogen_id && return (false, Int32(node))
        node = s.next
    end
    return (false, Int32(0))
end

"""
    get_infection_index(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8)

Like find_infection_index but throws if not found.
"""
@inline function get_infection_index(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8)::Tuple{Bool, Int32}
    result = find_infection_index(ind, infections, pathogen_id)
    result[2] == 0 && throw(ArgumentError("Individual $(ind.id) is not currently infected with pathogen $(pathogen_id)."))
    return result
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
    infection_id(individual::Individual, pathogen_id::Int8, infections::InfectionRegistry)::Int32

Returns the `infection_id` of the individual's currently active infection
with `pathogen_id`, or `DEFAULT_INFECTION_ID` if no such infection exists.
"""
@inline function infection_id(individual::Individual, pathogen_id::Int8, infections::InfectionRegistry)::Int32
    @inbounds for i in 1:INFECTIONS_CACHE_SIZE
        s = individual.infection_cache[i]
        s.active && s.pathogen_id == pathogen_id && return s.infection_id
    end
    individual.infection_head != 0 || return DEFAULT_INFECTION_ID
    node = individual.infection_head
    while node != 0
        @inbounds s = infections.states[node]
        s.active && s.pathogen_id == pathogen_id && return s.infection_id
        node = s.next
    end
    return DEFAULT_INFECTION_ID
end

"""
    infection_id(individual::Individual, pathogen_id::Int8, sim::Simulation)::Int32

Convenience wrapper that safely routes to the correct `InfectionRegistry` shard for the given individual.
"""
@inline function infection_id(individual::Individual, pathogen_id::Int8, sim)::Int32
    return infection_id(individual, pathogen_id, infection_registry(sim, individual))
end


"""
    infectiousness(individual::Individual, pathogen_id::Int8, infections::InfectionRegistry)::Int8

Returns the individual's current infectiousness for the given pathogen
(`Int8`, 0–100). Returns `0` if the individual is not currently infected
with that pathogen, or is in the exposed-but-not-yet-infectious window,
or has recovered.
"""
@inline function infectiousness(individual::Individual, pathogen_id::Int8, infections::InfectionRegistry)::Int8
    @inbounds for i in 1:INFECTIONS_CACHE_SIZE
        s = individual.infection_cache[i]
        s.active && s.pathogen_id == pathogen_id && return s.infectiousness
    end
    individual.infection_head != 0 || return Int8(0)
    node = individual.infection_head
    while node != 0
        @inbounds s = infections.states[node]
        s.active && s.pathogen_id == pathogen_id && return s.infectiousness
        node = s.next
    end
    return Int8(0)
end

"""
    infectiousness(individual::Individual, pathogen_id::Int8, sim::Simulation)::Int8

Convenience wrapper that safely routes to the correct `InfectionRegistry` shard for the given individual.
"""
@inline function infectiousness(individual::Individual, pathogen_id::Int8, sim)::Int8
    return infectiousness(individual, pathogen_id, infection_registry(sim, individual))
end


"""
    immunity_level(individual::Individual, pathogen_id::Int8, immunities::ImmunityRegistry)::Int8

Returns the current cached immunity level (0-100) against `pathogen_id`,
or 0 if the individual has no immunity record for that pathogen.
"""
@inline function immunity_level(individual::Individual, pathogen_id::Int8, immunities::ImmunityRegistry)::Int8
    @inbounds for i in 1:IMMUNITY_CACHE_SIZE
        s = individual.immunity_cache[i]
        !_is_active_immunity(s) && continue
        s.pathogen_id == pathogen_id && return s.immunity_level
    end
    individual.immunity_head != 0|| return Int8(0)
    node = individual.immunity_head
    while node != 0
        @inbounds s = immunities.states[node]
        _is_active_immunity(s) && s.pathogen_id == pathogen_id && return s.immunity_level
        node = s.next
    end
    return Int8(0)
end

"""
    immunity_level(individual::Individual, pathogen_id::Int8, sim::Simulation)::Int8

Convenience wrapper that safely routes to the correct `ImmunityRegistry` shard for the given individual.
"""
@inline function immunity_level(individual::Individual, pathogen_id::Int8, sim)::Int8
    return immunity_level(individual, pathogen_id, immunity_registry(sim, individual))
end


### NATURAL DISEASE HISTORY ###

@inline function _get_infection_state(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8)
    is_cache, idx = find_infection_index(ind, infections, pathogen_id)
    idx == 0 && return nothing
    return is_cache ? ind.infection_cache[Int(idx)] : infections.states[idx]
end

@inline function _get_infection_field(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8, ::Val{field}) where {field}
    is_cache, idx = find_infection_index(ind, infections, pathogen_id)
    idx == 0 && return Int16(-1)
    is_cache && return getfield(ind.infection_cache[idx], field)
    return getfield(infections.states[idx], field)
end

@inline function _set_infection_field!(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8, ::Val{field}, value) where {field}
    is_cache, idx = get_infection_index(ind, infections, pathogen_id)
    if is_cache
        ind.infection_cache = Base.setindex(ind.infection_cache,
            _setstate(ind.infection_cache[idx], Val(field), value), Int(idx))
    else
        @inbounds infections.states[idx] = _setstate(infections.states[idx], Val(field), value)
    end
end

# Returns the infectiousness_onset tick for the first active infection (no pathogen_id needed for single-pathogen case).
function infectiousness_onset(individual::Individual, infections::InfectionRegistry)
    @inbounds for i in 1:INFECTIONS_CACHE_SIZE
        s = individual.infection_cache[i]
        s.active && return s.infectiousness_onset
    end
    individual.infection_head != 0 || return Int16(-1)
    h = individual.infection_head
    h == 0 && return Int16(-1)
    return infections.states[h].infectiousness_onset
end

exposure(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:exposure))
exposure!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:exposure), t)
infectiousness_onset(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:infectiousness_onset))
infectiousness_onset!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:infectiousness_onset), t)
symptom_onset(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:symptom_onset))
symptom_onset!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:symptom_onset), t)
severeness_onset(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:severeness_onset))
severeness_onset!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:severeness_onset), t)
severeness_offset(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:severeness_offset))
severeness_offset!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:severeness_offset), t)
hospital_admission(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:hospital_admission))
hospital_admission!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:hospital_admission), t)
icu_admission(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:icu_admission))
icu_admission!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:icu_admission), t)

icu_discharge(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:icu_discharge))
icu_discharge!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:icu_discharge), t)
ventilation_admission(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:ventilation_admission))
ventilation_admission!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:ventilation_admission), t)
ventilation_discharge(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:ventilation_discharge))
ventilation_discharge!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:ventilation_discharge), t)
hospital_discharge(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:hospital_discharge))
hospital_discharge!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:hospital_discharge), t)
recovery(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:recovery))
recovery!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:recovery), t)
death(ind::Individual, infections::InfectionRegistry, pid::Int8) = _get_infection_field(ind, infections, pid, Val(:death))
death!(ind::Individual, infections::InfectionRegistry, pid::Int8, t::Int16) = _set_infection_field!(ind, infections, pid, Val(:death), t)


### DISEASE STATUS ###

"""
    is_infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isinfected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is infected with the given pathogen at tick `t`.
"""
function is_infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    return state.exposure >= 0 && state.exposure <= t < max(state.recovery, state.death)
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    max_rec_dea = max(state.recovery, state.death)
    !(state.exposure >= 0 && state.exposure <= t < max_rec_dea) && return false
    return state.infectiousness_onset <= t < max_rec_dea
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    !(state.exposure >= 0 && state.exposure <= t < max(state.recovery, state.death)) && return false
    return state.exposure <= t < state.infectiousness_onset
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    !(state.exposure >= 0 && state.exposure <= t < max(state.recovery, state.death)) && return false
    return t < state.symptom_onset
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    max_rec_dea = max(state.recovery, state.death)
    !(state.exposure >= 0 && state.exposure <= t < max_rec_dea) && return false
    return 0 <= state.symptom_onset <= t < max_rec_dea
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    max_rec_dea = max(state.recovery, state.death)
    !(state.exposure >= 0 && state.exposure <= t < max_rec_dea) && return false
    is_symp = 0 <= state.symptom_onset <= t < max_rec_dea
    return !is_symp && state.symptom_onset < state.exposure
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    !(state.exposure >= 0 && state.exposure <= t < max(state.recovery, state.death)) && return false
    return 0 <= state.severeness_onset <= t < state.severeness_offset
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    max_rec_dea = max(state.recovery, state.death)
    !(state.exposure >= 0 && state.exposure <= t < max_rec_dea) && return false
    is_symp = 0 <= state.symptom_onset <= t < max_rec_dea
    !is_symp && return false
    return !(0 <= state.severeness_onset <= t < state.severeness_offset)
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    !(state.exposure >= 0 && state.exposure <= t < max(state.recovery, state.death)) && return false
    return 0 <= state.hospital_admission <= t < state.hospital_discharge
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    !(state.exposure >= 0 && state.exposure <= t < max(state.recovery, state.death)) && return false
    !(0 <= state.hospital_admission <= t < state.hospital_discharge) && return false
    return 0 <= state.icu_admission <= t < state.icu_discharge
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    !(state.exposure >= 0 && state.exposure <= t < max(state.recovery, state.death)) && return false
    !(0 <= state.hospital_admission <= t < state.hospital_discharge) && return false
    return 0 <= state.ventilation_admission <= t < state.ventilation_discharge
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    return 0 <= state.recovery <= t
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
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    return 0 <= state.death <= t
end
isdead(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_dead(individual, infections, pathogen_id, t)
dead(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_dead(individual, infections, pathogen_id, t)

"""
    is_detected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is currently infected with the given pathogen and has been detected (i.e. tested positive) prior to or at tick `t`.
"""
function is_detected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    state = _get_infection_state(individual, infections, pathogen_id)
    state === nothing && return false
    !(state.exposure >= 0 && state.exposure <= t < max(state.recovery, state.death)) && return false
    return state.exposure <= last_reported_at(individual)
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
    is_dead(individual) && throw(ArgumentError("Cannot set disease progression of a dead individual (id=$(id(individual)))"))
    # flush_pending_infections! handles the actual write
    return nothing
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
    push_immunity_to_individual!(individual, registry, target_pathogen_id(vaccine), IMMUNITY_SOURCE_VACCINE, tick, id(vaccine))
    individual.needs_immunity_update = true
end

"""
    isvaccinated(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns wether the individual is vaccinated.
"""
function isvaccinated(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Bool
    state = get_immunity_state(registry, individual, pathogen_id)
    return state.vaccine_id != DEFAULT_VACCINE_ID
end
"""
    vaccine_id(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns the id of the vaccine the individual is vaccinated with.
"""
function vaccine_id(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Int8
    state = get_immunity_state(registry, individual, pathogen_id)
    return state.vaccine_id
end

"""
    vaccination_tick(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns the time of last vaccination.
"""
function vaccination_tick(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Int16
    state = get_immunity_state(registry, individual, pathogen_id)
    return state.vaccine_acquired_tick
end

"""
    number_of_vaccinations(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns the number of vaccinations.
"""
function number_of_vaccinations(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Int8
    state = get_immunity_state(registry, individual, pathogen_id)
    return state.dose_number
end

"""
    _immunity_level_and_stable(pathogen, state, individual, tick, rng)

Function barrier that extracts the `ImmunityProfile` from `pathogen` and calls `calculate_immunity` and `immunity_is_stable`. 
"""
function _immunity_level_and_stable(pathogen, state::ImmunityState, individual::Individual, tick::Int16, rng::Xoshiro)::Tuple{Int8, Bool}
    profile = immunity_profile(pathogen)
    level = calculate_immunity(profile, state, individual, tick, rng)
    stable = immunity_is_stable(profile, state, individual, tick)
    return level, stable
end

"""
    update_immunity!(individual::Individual, registry::ImmunityRegistry, pathogens::P, tick::Int16, rng::Xoshiro) where {P<:Tuple}

Refresh the per-individual immunity cache (`immune_pathogens`, `immunity_level`)
from the `ImmunityRegistry`. For each pathogen with at least one immunity record,
builds a combined `ImmunityState` (natural + vaccine) and calls `calculate_immunity`
once. The result is written to the per-individual NTuple cache.
"""
function update_immunity!(
    individual::Individual,
    registry::ImmunityRegistry,
    pathogens::P,
    tick::Int16,
    rng::Xoshiro,
) where {P<:Tuple}
    _all_stable = true

    # Cache slots
    @inbounds for i in 1:IMMUNITY_CACHE_SIZE
        state = individual.immunity_cache[i]
        _is_active_immunity(state) || continue

        pat = get_pathogen(pathogens, state.pathogen_id)
        new_level, stable = _immunity_level_and_stable(pat, state, individual, tick, rng)
        _all_stable &= stable

        if new_level != state.immunity_level
            individual.immunity_cache = Base.setindex(individual.immunity_cache,
                ImmunityState(state.next, state.natural_acquired_tick, state.vaccine_acquired_tick,
                    new_level, state.pathogen_id, state.vaccine_id, state.dose_number),
                i)
        end
    end

    # Overflow slots
    if individual.immunity_head != 0
        node = individual.immunity_head
        while node != 0
            @inbounds state = registry.states[node]
            next_node = state.next
            pat = get_pathogen(pathogens, state.pathogen_id)
            new_level, stable = _immunity_level_and_stable(pat, state, individual, tick, rng)
            _all_stable &= stable
            if new_level != state.immunity_level
                @inbounds registry.states[node] = ImmunityState(state.next, state.natural_acquired_tick,
                    state.vaccine_acquired_tick, new_level, state.pathogen_id, state.vaccine_id, state.dose_number)
            end
            node = next_node
        end
    end

    if _all_stable
        individual.needs_immunity_update = false
    end
    return nothing
end


### UPDATE DISEASE PROGRESSION IN AGENTS ###

"""
    _infectiousness_level(pathogen, state, individual, tick, rng)

Function barrier that extracts the `InfectiousnessProfile` from `pathogen` and calls `calculate_infectiousness`.
"""
function _infectiousness_level(pathogen, state::InfectionState, individual::Individual, tick::Int16, rng::Xoshiro)::Int8
    profile = infectiousness_profile(pathogen) 
    return calculate_infectiousness(profile, state, individual, tick, rng)
end

"""
    _process_death!(individual::Individual, pathogen_id::Int8, infections::InfectionRegistry, removal_buf::Vector{Tuple{Int32,Int32}})

Handles the health flags and memory-management when an individual dies.
"""
@inline function _process_death!(individual::Individual, pathogen_id::Int8, infections::InfectionRegistry, removal_buf::Vector{Tuple{Int32,Int32}})
    dead!(individual, pathogen_id, true)
    
    individual.killing_pathogen_id = pathogen_id
    individual.active_pathogens_mask = 0

    individual.infected = false
    individual.infectious = false
    individual.symptomatic = false
    individual.severe = false
    individual.hospitalized = false
    individual.icu = false
    individual.ventilated = false
    individual.detected = false

    # stage all active cache memory for removal
    @inbounds for c in 1:INFECTIONS_CACHE_SIZE
        if individual.infection_cache[c].active
            push!(removal_buf, (individual.id, Int32(-c)))
            # Clear it AFTER pushing to the buffer
            individual.infection_cache = Base.setindex(individual.infection_cache, InfectionState(), c)
        end
    end
    
    # stage all active overflow memory for removal
    if individual.infection_head != 0
        node_idx = individual.infection_head
        while node_idx != 0
            push!(removal_buf, (individual.id, Int32(node_idx)))
            node_idx = infections.states[node_idx].next
        end
    end
    
    return nothing
end

"""
    progress_disease!(individual::Individual, infections::InfectionRegistry, pathogens::P, tick::Int16, rng::Xoshiro) where {P<:Tuple}

Updates the proxy disease progression status flags of the individual at the
given tick by reading from the global `InfectionRegistry`. Also populates the
three per-slot tuples on the individual (`active_pathogens`, `infectiousness`,
`infection_ids`) so that the spread/transmission phase later in the same tick
can read everything it needs directly from the individual.

`pathogens` is the simulation's pathogen registry; each active slot's
`InfectionState` is fed through that pathogen's `InfectiousnessProfile`
to compute the cached infectiousness level.
"""
function progress_disease!(individual::Individual, infections::InfectionRegistry,
    pathogens::P, removal_buf::Vector{Tuple{Int32,Int32}},
    tick::Int16, rng::Xoshiro) where {P<:Tuple}
    
    individual.dead && return nothing

    # initialize trackers 
    _is_inf = _is_infectious = _is_symp = _is_sev = false
    _is_hosp = _is_icu = _is_vent = _is_det = false

    # process cache
    @inbounds for i in 1:INFECTIONS_CACHE_SIZE
        state = individual.infection_cache[i]
        !state.active && continue

        # check death
        if Int16(0) < state.death <= tick
            _process_death!(individual, state.pathogen_id, infections, removal_buf)
            return nothing
        end

        # check recovery
        if Int16(0) < state.recovery <= tick
            individual.active_pathogens_mask &= ~(UInt32(1) << (state.pathogen_id - 1))
            individual.infection_cache = Base.setindex(individual.infection_cache, InfectionState(), i)
            push!(removal_buf, (individual.id, Int32(-i)))
            continue
        end

        # update infectiousness
        end_tick = max(state.recovery, state.death)
        _active = state.exposure <= tick < end_tick
        
        if _active
            level = _infectiousness_level(get_pathogen(pathogens, state.pathogen_id), state, individual, tick, rng)
            if level != state.infectiousness
                state = _setstate(state, Val(:infectiousness), level)
                individual.infection_cache = Base.setindex(individual.infection_cache, state, i)
            end
        end

        # accumulate state flags
        _is_inf|= _active
        _is_infectious |= state.infectiousness_onset <= tick < end_tick
        _is_symp |= Int16(0) <= state.symptom_onset <= tick < end_tick
        _is_sev |= Int16(0) <= state.severeness_onset <= tick < state.severeness_offset
        _is_hosp |= Int16(0) <= state.hospital_admission <= tick < state.hospital_discharge
        _is_icu |= Int16(0) <= state.icu_admission <= tick < state.icu_discharge
        _is_vent |= Int16(0) <= state.ventilation_admission <= tick < state.ventilation_discharge
        _is_det |= _active && state.exposure <= last_reported_at(individual)
    end

    # process registry
    if individual.infection_head != 0
        node = individual.infection_head
        while node != 0
            @inbounds state = infections.states[node]
            next_node = state.next

            # check death
            if Int16(0) < state.death <= tick
                _process_death!(individual, state.pathogen_id, infections, removal_buf)
                return nothing 
            end

            # check recovery
            if Int16(0) < state.recovery <= tick
                individual.active_pathogens_mask &= ~(UInt32(1) << (state.pathogen_id - 1))
                push!(removal_buf, (individual.id, Int32(node)))
                node = next_node
                continue
            end

            # update infectiousness
            end_tick = max(state.recovery, state.death)
            _active = state.exposure <= tick < end_tick
            
            if _active
                level = _infectiousness_level(get_pathogen(pathogens, state.pathogen_id), state, individual, tick, rng)
                if level != state.infectiousness
                    state = _setstate(state, Val(:infectiousness), level)
                    @inbounds infections.states[node] = state
                end
            end

            # accumulate state flags
            _is_inf |= _active
            _is_infectious |= state.infectiousness_onset <= tick < end_tick
            _is_symp |= Int16(0) <= state.symptom_onset <= tick < end_tick
            _is_sev |= Int16(0) <= state.severeness_onset <= tick < state.severeness_offset
            _is_hosp |= Int16(0) <= state.hospital_admission <= tick < state.hospital_discharge
            _is_icu |= Int16(0) <= state.icu_admission <= tick < state.icu_discharge
            _is_vent |= Int16(0) <= state.ventilation_admission <= tick < state.ventilation_discharge
            _is_det |= _active && state.exposure <= last_reported_at(individual)

            node = next_node
        end
    end

    # commit states
    infected!(individual, _is_inf)
    infectious!(individual, _is_infectious)
    symptomatic!(individual, _is_symp)
    severe!(individual, _is_sev)
    hospitalized!(individual, _is_hosp)
    icu!(individual, _is_icu)
    ventilated!(individual, _is_vent)
    detected!(individual, _is_det)
    
    return nothing
end



### RESET DISEASE PROGRESSION ###
"""
    reset!(individual::Individual, infections::InfectionRegistry)

Resets all non-static values like the disease progression timing.
The individual will get back into a infections where it was never infected, vaccinated, tested, etc.
"""
function reset!(individual::Individual, infections::InfectionRegistry, registry::ImmunityRegistry)
    individual.infected = false
    individual.infectious = false
    individual.symptomatic = false
    individual.severe = false
    individual.hospitalized = false
    individual.icu = false
    individual.ventilated = false
    individual.dead = false
    individual.detected = false

    # Clean overflow before clearing flags
    individual.infection_head != 0 && remove_infection!(infections, individual.id)
    individual.immunity_overflow != 0 && remove_immunity!(registry, individual.id)

    individual.infection_cache = ntuple(_ -> InfectionState(), INFECTIONS_CACHE_SIZE)
    individual.number_of_infections = 0
    individual.active_pathogens_mask = 0
    individual.killing_pathogen_id = DEFAULT_PATHOGEN_ID

    individual.immunity_cache = ntuple(_ -> ImmunityState(), IMMUNITY_CACHE_SIZE)
    individual.needs_immunity_update = false

    individual.last_test = DEFAULT_TICK
    individual.last_test_result = false
    individual.last_reported_at = DEFAULT_TICK

    individual.quarantine_status = QUARANTINE_STATE_NO_QUARANTINE
    individual.quarantine_tick = DEFAULT_TICK
    individual.quarantine_release_tick = DEFAULT_TICK
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