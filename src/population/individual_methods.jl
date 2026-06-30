###
### INDIVIDUAL METHODS
### Methods on Individual that depend on Simulation (cannot be in individuals.jl
### due to include-order circular dependency) and the disease-progression engine.
###

# EXPORTS
# setting membership and lookup
export household, office, schoolclass, getsetting, settings_tuple
# registry-based getters
export get_infection_state, get_immunity_state
export infection_id
export infectiousness
export immunity_level
# disease progression timeline
export exposure, infectiousness_onset, symptom_onset, severeness_onset, severeness_offset
export hospital_admission, icu_admission, icu_discharge, ventilation_admission
export ventilation_discharge, hospital_discharge, recovery, death
# testing
export get_test_state
export last_test
export last_test_result
export was_reported
export record_test!
# vaccination
export vaccinate!
export vaccination_tick, vaccine_id, isvaccinated, number_of_vaccinations
# disease progression engine
export progress_disease!
export set_progression!



### INDIVIDUAL-SETTING MEMBERSHIP & SETTING LOOKUP ###

"""
    membership_setting_types(::Type{Individual})

The `IndividualSetting` types an `Individual` can be a member of via a dedicated `Int32` field.
"""
membership_setting_types(::Type{Individual}) = (Household, Office, SchoolClass, Municipality)

"""
    setting_id(individual::Individual, ::Type{T}) where {T<:Setting}

Returns the id of the setting of type `T` associated with the individual. Dispatched per
type (the type → field map); falls back to `DEFAULT_SETTING_ID` when the individual is not
part of a setting of that type.
"""
@inline setting_id(individual::Individual, ::Type{Household}) = individual.household
@inline setting_id(individual::Individual, ::Type{Office}) = individual.office
@inline setting_id(individual::Individual, ::Type{SchoolClass}) = individual.schoolclass
@inline setting_id(individual::Individual, ::Type{Municipality}) = individual.municipality
@inline setting_id(individual::Individual, ::Type{GlobalSetting}) = GLOBAL_SETTING_ID # there is only one GlobalSetting
@inline setting_id(individual::Individual, ::Type{<:Setting}) = DEFAULT_SETTING_ID

"""
    setting_id!(individual::Individual, ::Type{T}, id::Int32) where {T<:Setting}

Changes the assigned setting id of the individual for the given type of setting to `id`.
Types without a dedicated field (e.g. `GlobalSetting`) are a no-op.
"""
@inline setting_id!(individual::Individual, ::Type{Household}, id::Int32) = (individual.household = id; nothing)
@inline setting_id!(individual::Individual, ::Type{Office}, id::Int32) = (individual.office = id; nothing)
@inline setting_id!(individual::Individual, ::Type{SchoolClass}, id::Int32) = (individual.schoolclass = id; nothing)
@inline setting_id!(individual::Individual, ::Type{Municipality}, id::Int32) = (individual.municipality = id; nothing)
@inline setting_id!(individual::Individual, ::Type{<:Setting}, id::Int32) = nothing

"""
    settings_tuple(individual::Individual)

Returns all individual's associated setting IDs as a Tuple of `(type, id)` pairs.
Derived from `membership_setting_types(Individual)`.
"""
settings_tuple(individual::Individual) = map(T -> (T, setting_id(individual, T)), membership_setting_types(Individual))

"""
    activate_memberships!(c::Individual, sim::Simulation)

Activates every setting the individual `c` belongs to (and, recursively, their containers).
Unrolls over `membership_setting_types(Individual)` so each access is type-stable.
"""
@inline activate_memberships!(c::Individual, sim::Simulation) = _activate_memberships!(c, sim, membership_setting_types(Individual)...)
@inline _activate_memberships!(c::Individual, sim::Simulation) = nothing
@inline function _activate_memberships!(c::Individual, sim::Simulation, ::Type{T}, rest...) where {T<:IndividualSetting}
    sid = setting_id(c, T)
    if sid != DEFAULT_SETTING_ID
        activate!(settings(sim, T)[sid], sim)
    end
    _activate_memberships!(c, sim, rest...)
end


### setting extraction from individuals
"""
    household(i::Individual, sim::Simulation)::Household

Returns the `Household` instance referenced in an individual. 
"""
function household(i::Individual, sim::Simulation)::Household
    return sim |> settings |>
        x -> x[Household] |>
        x -> x[household_id(i)]
end

"""
    getsetting(i::Individual, sim::Simulation, ::Type{Household})::Household

Return the `Household` setting to which the individual `i` belongs, based on
their `household` ID.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{Household})
    return household(i, sim)
end

"""
    office(i::Individual, sim::Simulation)::Office

Returns the `Office` instance referenced in an individual. 
"""
function office(i::Individual, sim::Simulation)::Office
    !is_working(i) ? throw(ArgumentError("Individual $(id(i)) is not assigned to an Office")) :

    return sim |> settings |>
        x -> x[Office] |>
        x -> x[office_id(i)]
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{Office})::Office

Return the `Office` setting to which the individual `i` belongs, based on
their `office` ID.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{Office})
    return office(i, sim)
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{Department})::Department

Return the `Department` that contains the individual's `Office`.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{Department})
    return getsetting(i, sim, Office).contained |>
        id -> settings(sim, Department)[id]
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{Workplace})::Workplace

Return the `Workplace` that contains the individual's `Department`.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{Workplace})
    return getsetting(i, sim, Department).contained |>
        id -> settings(sim, Workplace)[id]
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{WorkplaceSite})::WorkplaceSite

Return the `WorkplaceSite` that contains the individual's `Workplace`.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{WorkplaceSite})
    return getsetting(i, sim, Workplace).contained |>
        id -> settings(sim, WorkplaceSite)[id]
end


"""
    schoolclass(i::Individual, sim::Simulation)::SchoolClass

Returns the `SchoolClass` instance referenced in an individual. 
"""
function schoolclass(i::Individual, sim::Simulation)::SchoolClass
    !is_student(i) ? throw(ArgumentError("Individual $(id(i)) is not assigned to a School Class")) :

    return sim |> settings |>
        x -> x[SchoolClass] |>
        x -> x[class_id(i)]
end

"""
    getsetting(i::Individual, sim::Simulation, ::Type{SchoolClass})::SchoolClass

Return the `SchoolClass` setting to which the individual `i` belongs, based on
their `schoolclass` ID.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{SchoolClass})
    return schoolclass(i, sim)
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{SchoolYear})::SchoolYear
"""
function getsetting(i::Individual, sim::Simulation, ::Type{SchoolYear})
    class = getsetting(i, sim, SchoolClass)
    year_id = class.contained
    return settings(sim, SchoolYear)[year_id]
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{School})::School

Return the `School` setting containing the individual's `SchoolYear`.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{School})
    year = getsetting(i, sim, SchoolYear)
    school_id = year.contained
    return settings(sim, School)[school_id]
end


"""
    getsetting(i::Individual, sim::Simulation, ::Type{SchoolComplex})::SchoolComplex

Return the `SchoolComplex` setting containing the individual's `School`.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{SchoolComplex})
    school = getsetting(i, sim, School)
    complex_id = school.contained
    return settings(sim, SchoolComplex)[complex_id]
end

"""
    municipality(i::Individual, sim::Simulation)::Municipality

Returns the `Municipality` instance referenced in an individual. 
"""
function municipality(i::Individual, sim::Simulation)::Municipality
    return sim |> settings |>
        x -> x[Municipality] |>
        x -> x[municipality_id(i)]
end

"""
    getsetting(i::Individual, sim::Simulation, ::Type{GlobalSetting})

Return the global setting.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{GlobalSetting})
    return settings(sim)[GlobalSetting][1]
end



### Registry GETTERS ###

"""
    get_infection_state(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8)::InfectionState

Cache-first lookup of the full `InfectionState` for `(ind, pathogen_id)`.
Searches `ind.infection_cache` first; falls back to the overflow linked list if not found.
Returns an empty sentinel `InfectionState` if no record exists for `pathogen_id`.
"""
@inline function get_infection_state(ind::Individual, infections::InfectionRegistry, pathogen_id::Int8)::InfectionState
    @inbounds for i in 1:INFECTIONS_CACHE_SIZE
        s = ind.infection_cache[i]
        s.active && s.pathogen_id == pathogen_id && return s
    end
    node = ind.infection_head
    while node != 0
        @inbounds s = infections.states[node]
        s.active && s.pathogen_id == pathogen_id && return s
        node = s.next
    end
    return InfectionState()
end

"""
    get_immunity_state(ind::Individual, reg::ImmunityRegistry, pathogen_id::Int8)::ImmunityState

Cache-first lookup of the full `ImmunityState` for `(ind, pathogen_id)`.
Searches `ind.immunity_cache` first; falls back to the overflow linked list if not found.
Returns an empty sentinel `ImmunityState` if no record exists for `pathogen_id`.
"""
@inline function get_immunity_state(ind::Individual, reg::ImmunityRegistry, pathogen_id::Int8)::ImmunityState
    @inbounds for i in 1:IMMUNITY_CACHE_SIZE
        s = ind.immunity_cache[i]
        _is_active_immunity(s) && s.pathogen_id == pathogen_id && return s
    end
    node = ind.immunity_head
    while node != 0
        @inbounds s = reg.states[node]
        _is_active_immunity(s) && s.pathogen_id == pathogen_id && return s
        node = s.next
    end
    return ImmunityState(pathogen_id)
end

### PATHOGEN ATTRIBUTES ###

"""
    infection_id(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)::Int32

Returns the `infection_id` of the individual's currently active infection
with `pathogen_id`, or `DEFAULT_INFECTION_ID` if no such infection exists.
"""
@inline infection_id(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)::Int32 =
    get_infection_state(individual, infections, pathogen_id).infection_id

"""
    infection_id(individual::Individual, sim::Simulation, pathogen_id::Int8)::Int32

Convenience wrapper that safely routes to the correct `InfectionRegistry` shard for the given individual.
"""
@inline infection_id(individual::Individual, sim::Simulation, pathogen_id::Int8)::Int32 =
    infection_id(individual, infection_registry(sim, individual), pathogen_id)


"""
    infectiousness(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)::Int8

Returns the individual's current infectiousness for the given pathogen
(`Int8`, 0–100). Returns `0` if the individual is not currently infected
with that pathogen, or is in the exposed-but-not-yet-infectious window,
or has recovered.
"""
@inline infectiousness(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8)::Int8 =
    get_infection_state(individual, infections, pathogen_id).infectiousness

"""
    infectiousness(individual::Individual, sim::Simulation, pathogen_id::Int8)::Int8

Convenience wrapper that safely routes to the correct `InfectionRegistry` shard for the given individual.
"""
@inline infectiousness(individual::Individual, sim::Simulation, pathogen_id::Int8)::Int8 =
    infectiousness(individual, infection_registry(sim, individual), pathogen_id)


"""
    immunity_level(individual::Individual, immunities::ImmunityRegistry, pathogen_id::Int8)::Int8

Returns the current cached immunity level (0-100) against `pathogen_id`,
or 0 if the individual has no immunity record for that pathogen.
"""
@inline immunity_level(individual::Individual, immunities::ImmunityRegistry, pathogen_id::Int8)::Int8 =
    get_immunity_state(individual, immunities, pathogen_id).immunity_level

"""
    immunity_level(individual::Individual, sim::Simulation, pathogen_id::Int8)::Int8

Convenience wrapper that safely routes to the correct `ImmunityRegistry` shard for the given individual.
"""
@inline immunity_level(individual::Individual, sim::Simulation, pathogen_id::Int8)::Int8 =
    immunity_level(individual, immunity_registry(sim, individual), pathogen_id)

"""
    earliest_infectiousness_onset(ind::Individual, infections::InfectionRegistry)::Int16

Returns the earliest `infectiousness_onset` tick across all of `ind`'s currently
active infections, or `Int16(-1)` if the individual has no active infections.
"""
function earliest_infectiousness_onset(ind::Individual, infections::InfectionRegistry)::Int16
    result = typemax(Int16)
    for state in each_infection(ind, infections)
        state.infectiousness_onset >= 0 && (result = min(result, state.infectiousness_onset))
    end
    return result == typemax(Int16) ? Int16(-1) : result
end

"""
    earliest_infectiousness_onset(ind::Individual, sim::Simulation)::Int16

Convenience wrapper that routes to the correct `InfectionRegistry` shard for the given individual.
"""
function earliest_infectiousness_onset(ind::Individual, sim::Simulation)::Int16
    return earliest_infectiousness_onset(ind, infection_registry(sim, ind))
end


### NATURAL DISEASE HISTORY ###


exposure(ind::Individual, infections::InfectionRegistry, pid::Int8) = get_infection_state(ind, infections, pid).exposure
infectiousness_onset(ind::Individual, infections::InfectionRegistry, pid::Int8) = get_infection_state(ind, infections, pid).infectiousness_onset
symptom_onset(ind::Individual, infections::InfectionRegistry, pid::Int8) = get_infection_state(ind, infections, pid).symptom_onset
severeness_onset(ind::Individual, infections::InfectionRegistry, pid::Int8) = get_infection_state(ind, infections, pid).severeness_onset
severeness_offset(ind::Individual, infections::InfectionRegistry, pid::Int8) = get_infection_state(ind, infections, pid).severeness_offset
critical_onset(ind::Individual, infections::InfectionRegistry, pid::Int8) = get_infection_state(ind, infections, pid).critical_onset
critical_offset(ind::Individual, infections::InfectionRegistry, pid::Int8) = get_infection_state(ind, infections, pid).critical_offset
recovery(ind::Individual, infections::InfectionRegistry, pid::Int8) = get_infection_state(ind, infections, pid).recovery


### DISEASE STATUS ###

"""
    is_infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isinfected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is infected with the given pathogen at tick `t`.
"""
function is_infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    return state.exposure >= 0 && state.exposure <= t < state.recovery
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
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    max_rec_dea = state.recovery
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
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    !(state.exposure >= 0 && state.exposure <= t < state.recovery) && return false
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
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    !(state.exposure >= 0 && state.exposure <= t < state.recovery) && return false
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
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    max_rec_dea = state.recovery
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
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    max_rec_dea = state.recovery
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
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    !(state.exposure >= 0 && state.exposure <= t < state.recovery) && return false
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
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    max_rec_dea = state.recovery
    !(state.exposure >= 0 && state.exposure <= t < max_rec_dea) && return false
    is_symp = 0 <= state.symptom_onset <= t < max_rec_dea
    !is_symp && return false
    return !(0 <= state.severeness_onset <= t < state.severeness_offset)
end
ismild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_mild(individual, infections, pathogen_id, t)
mild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_mild(individual, infections, pathogen_id, t)

"""
    is_critical(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    iscritical(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    critical(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is in a critical infection with the given pathogen at tick `t`.
"""
function is_critical(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    !(state.exposure >= 0 && state.exposure <= t < state.recovery) && return false
    return 0 <= state.critical_onset <= t < state.critical_offset
end
iscritical(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_critical(individual, infections, pathogen_id, t)
critical(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_critical(individual, infections, pathogen_id, t)

"""
    is_recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isrecovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is recovered from the given pathogen at tick `t`.
"""
function is_recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    return 0 <= state.recovery <= t
end
isrecovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_recovered(individual, infections, pathogen_id, t)
recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_recovered(individual, infections, pathogen_id, t)

"""
    is_detected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is currently infected with the given pathogen and has been detected at any point during this infection.
"""
function is_detected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    !(state.exposure >= 0 && state.exposure <= t < state.recovery) && return false
    return is_detected(individual, pathogen_id)
end
isdetected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_detected(individual, infections, pathogen_id, t)
detected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_detected(individual, infections, pathogen_id, t)


### TESTING STATUS ###

"""
    get_test_state(individual::Individual, reg::TestRegistry, pathogen_id::Int8)

Returns the `TestState` for `(individual, pathogen_id)` from the `TestRegistry`.
Returns an empty `TestState()` sentinel if no test has been recorded.
"""
@inline function get_test_state(individual::Individual, reg::TestRegistry, pathogen_id::Int8)
    return get(reg.states, _test_key(id(individual), pathogen_id), TestState())
end

"""
    last_test(individual::Individual, reg::TestRegistry, pathogen_id::Int8)

Returns the tick of the most recent test for this individual and pathogen.
Returns `DEFAULT_TICK` (-1) if never tested.
"""
last_test(individual::Individual, reg::TestRegistry, pathogen_id::Int8) = get_test_state(individual, reg, pathogen_id).last_test

"""
    last_test(individual::Individual, sim::Simulation, pathogen_id::Int8)

Convenience wrapper that safely routes to the correct `TestRegistry` shard for the given individual.
"""
last_test(individual::Individual, sim::Simulation, pathogen_id::Int8) = get_test_state(individual, test_registry(sim, individual), pathogen_id).last_test

"""
    last_test_result(individual::Individual, reg::TestRegistry, pathogen_id::Int8)

Returns whether the most recent test was positive for this individual and pathogen.
"""
last_test_result(individual::Individual, reg::TestRegistry, pathogen_id::Int8) = get_test_state(individual, reg, pathogen_id).last_test_result

"""
    last_test_result(individual::Individual, sim::Simulation, pathogen_id::Int8)

Convenience wrapper that safely routes to the correct `TestRegistry` shard for the given individual.
"""
last_test_result(individual::Individual, sim::Simulation, pathogen_id::Int8) = get_test_state(individual, test_registry(sim, individual), pathogen_id).last_test_result


"""
    was_reported(individual::Individual, reg::TestRegistry, pathogen_id::Int8)

Returns `true` if a positive reportable test was ever recorded for this individual
and pathogen.
"""
was_reported(individual::Individual, reg::TestRegistry, pathogen_id::Int8) = get_test_state(individual, reg, pathogen_id).was_reported

"""
    was_reported(individual::Individual, sim::Simulation, pathogen_id::Int8)

Convenience wrapper that safely routes to the correct `TestRegistry` shard for the given individual.
"""
was_reported(individual::Individual, sim::Simulation, pathogen_id::Int8) = get_test_state(individual, test_registry(sim, individual), pathogen_id).was_reported


"""
    record_test!(ind::Individual, tests::TestRegistry, pathogen_id::Int8, tick::Int16, test_result::Bool, reportable::Bool)

Records a test outcome into the `TestRegistry` for `(ind, pathogen_id)` and
updates `ind.detected_mask` if the test is a positive reportable result.
"""
@inline function record_test!(ind::Individual, tests::TestRegistry, pathogen_id::Int8, tick::Int16, test_result::Bool, reportable::Bool)
    detected = test_result && reportable
    set_test_state!(tests, id(ind), pathogen_id, tick, test_result, detected)
    detected && detected!(ind, pathogen_id, true)
    return nothing
end

"""
    record_test!(individual::Individual, sim::Simulation, pathogen_id::Int8, tick::Int16, test_result::Bool, reportable::Bool)

Convenience wrapper that routes to the correct `TestRegistry` shard.
"""
function record_test!(individual::Individual, sim::Simulation, pathogen_id::Int8, tick::Int16, test_result::Bool, reportable::Bool)
    record_test!(individual, test_registry(sim, individual), pathogen_id, tick, test_result, reportable)
end



### VACCINATION STATUS ###

"""
    vaccinate!(individual::Individual, registry::ImmunityRegistry, vaccine::Vaccine, tick::Int16)

Vaccinates an individual against a pathogen.
"""
function vaccinate!(individual::Individual, registry::ImmunityRegistry, vaccine::Vaccine, tick::Int16)
    log!(logger(vaccine), id(individual), target_pathogen_id(vaccine), tick)
    push_immunity!(registry, individual, target_pathogen_id(vaccine), IMMUNITY_SOURCE_VACCINE, tick, id(vaccine))
    individual.needs_immunity_update = true
end

"""
    vaccinate!(individual::Individual, sim::Simulation, vaccine::Vaccine, tick::Int16)

Convenience wrapper that routes to the correct `ImmunityRegistry` shard.
"""
function vaccinate!(individual::Individual, sim::Simulation, vaccine::Vaccine, tick::Int16)
    vaccinate!(individual, immunity_registry(sim, individual), vaccine, tick)
end

"""
    isvaccinated(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns wether the individual is vaccinated.
"""
function isvaccinated(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Bool
    state = get_immunity_state(individual, registry, pathogen_id)
    return state.vaccine_id != DEFAULT_VACCINE_ID
end

"""
    isvaccinated(individual::Individual, sim::Simulation, pathogen_id::Int8)

Convenience wrapper that routes to the correct `ImmunityRegistry` shard.
"""
isvaccinated(individual::Individual, sim::Simulation, pathogen_id::Int8) = isvaccinated(individual, immunity_registry(sim, individual), pathogen_id)

"""
    vaccine_id(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns the id of the vaccine the individual is vaccinated with.
"""
function vaccine_id(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Int8
    state = get_immunity_state(individual, registry, pathogen_id)
    return state.vaccine_id
end

"""
    vaccine_id(individual::Individual, sim::Simulation, pathogen_id::Int8)

Convenience wrapper that routes to the correct `ImmunityRegistry` shard.
"""
vaccine_id(individual::Individual, sim::Simulation, pathogen_id::Int8) = vaccine_id(individual, immunity_registry(sim, individual), pathogen_id)

"""
    vaccination_tick(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns the time of last vaccination.
"""
function vaccination_tick(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Int16
    state = get_immunity_state(individual, registry, pathogen_id)
    return state.vaccine_acquired_tick
end

"""
    vaccination_tick(individual::Individual, sim::Simulation, pathogen_id::Int8)

Convenience wrapper that routes to the correct `ImmunityRegistry` shard.
"""
vaccination_tick(individual::Individual, sim::Simulation, pathogen_id::Int8) = vaccination_tick(individual, immunity_registry(sim, individual), pathogen_id)

"""
    number_of_vaccinations(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)

Returns the number of vaccinations.
"""
function number_of_vaccinations(individual::Individual, registry::ImmunityRegistry, pathogen_id::Int8)::Int8
    state = get_immunity_state(individual, registry, pathogen_id)
    return state.dose_number
end

"""
    number_of_vaccinations(individual::Individual, sim::Simulation, pathogen_id::Int8)

Convenience wrapper that routes to the correct `ImmunityRegistry` shard.
"""
number_of_vaccinations(individual::Individual, sim::Simulation, pathogen_id::Int8) = number_of_vaccinations(individual, immunity_registry(sim, individual), pathogen_id)


"""
    set_progression!(ind::Individual, dp::DiseaseProgression, pathogen_id::Int8 = Int8(1))

Applies `dp` directly to `ind` by writing an active `InfectionState` into the individual's
infection cache, bypassing the normal simulation buffer and flush cycle.
The individual is immediately visible as infected for `pathogen_id` without needing a running
`Simulation` or a call to `step!`.

If `ind` is already actively infected with `pathogen_id`, this is a no-op (with a warning):
at most one active infection per pathogen is allowed.
"""
function set_progression!(ind::Individual, dp::DiseaseProgression, pathogen_id::Int8 = Int8(1))
    # at most one active infection per pathogen; skip a duplicate rather than corrupt the invariant
    if infected(ind, pathogen_id)
        @warn "set_progression!: individual $(id(ind)) is already infected with pathogen $pathogen_id; skipping to preserve the one-active-infection-per-pathogen invariant."
        return nothing
    end
    # without a persistent registry, an overflow would dangle, so require a free cache slot
    any(i -> !ind.infection_cache[i].active, 1:INFECTIONS_CACHE_SIZE) ||
        throw(ArgumentError("set_progression! cannot store more than $INFECTIONS_CACHE_SIZE concurrent infection(s) per individual without a Simulation context."))
    push_infection!(InfectionRegistry(), ind, pathogen_id, DEFAULT_INFECTION_ID, dp)
    infected!(ind, true)
    infected!(ind, pathogen_id, true)
    return nothing
end

"""
    set_progression!(ind::Individual, pathogen_id::Int8 = Int8(1))

Seeds an active `InfectionState` with all fields set to `DEFAULT_TICK` (i.e. -1).
Useful when you need an active infection slot for a specific pathogen without
constraining any timeline values.
"""
function set_progression!(ind::Individual, pathogen_id::Int8 = Int8(1))
    # at most one active infection per pathogen; skip a duplicate rather than corrupt the invariant
    if infected(ind, pathogen_id)
        @warn "set_progression!: individual $(id(ind)) is already infected with pathogen $pathogen_id; skipping to preserve the one-active-infection-per-pathogen invariant."
        return nothing
    end
    blank = InfectionState(
        DEFAULT_INFECTION_ID, Int32(0),
        DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK,
        DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK,
        Int8(0), pathogen_id, true
    )
    ind.infection_cache = Base.setindex(ind.infection_cache, blank, 1)
    infected!(ind, true)
    infected!(ind, pathogen_id, true)
    return nothing
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
    _step_immunity!(ind, registry, pathogens, loc, tick, rng)

Recomputes the immunity level for the single record at slot `loc` (a `_CacheSlot` or
`_OverflowNode`) and writes it back only when it changed. Shared by both branches of
`update_immunity!` so the recompute logic lives once; the storage details are handled by
`_slot_state` / `_set_slot!` dispatch. Returns whether the record is stable.
"""
@inline function _step_immunity!(ind::Individual, registry::ImmunityRegistry, pathogens::P, loc, tick::Int16, rng::Xoshiro) where {P<:Tuple}
    state = _slot_state(ind, registry, loc)
    pat = get_pathogen(pathogens, state.pathogen_id)
    new_level, stable = _immunity_level_and_stable(pat, state, ind, tick, rng)
    new_level != state.immunity_level && _set_slot!(ind, registry, loc, _setstate(state, Val(:immunity_level), new_level))
    return stable
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
        _is_active_immunity(individual.immunity_cache[i]) || continue
        _all_stable &= _step_immunity!(individual, registry, pathogens, _CacheSlot(Int32(i)), tick, rng)
    end

    # Overflow slots
    if individual.immunity_head != 0
        node = individual.immunity_head
        while node != 0
            @inbounds next_node = registry.states[node].next
            _all_stable &= _step_immunity!(individual, registry, pathogens, _OverflowNode(node), tick, rng)
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
    _process_death!(individual::Individual, pathogen_id::Int8, infections::InfectionRegistry, removal_buf::Vector{_SlotRemoval})

Handles the health flags and memory-management when an individual dies.
"""
@inline function _process_death!(individual::Individual, pathogen_id::Int8, infections::InfectionRegistry, removal_buf::Vector{_SlotRemoval})
    individual.disease_flags = DiseaseFlags(FLAG_DEAD)

    individual.killing_pathogen_id = pathogen_id
    individual.active_pathogens_mask = 0
    individual.detected_mask = 0

    # stage all active cache memory for removal
    @inbounds for c in 1:INFECTIONS_CACHE_SIZE
        if individual.infection_cache[c].active
            _stage_slot_removal!(removal_buf, individual, _CacheSlot(Int32(c)))
            # Clear it AFTER pushing to the buffer
            individual.infection_cache = Base.setindex(individual.infection_cache, InfectionState(), c)
        end
    end

    # stage all active overflow memory for removal
    if individual.infection_head != 0
        node_idx = individual.infection_head
        while node_idx != 0
            _stage_slot_removal!(removal_buf, individual, _OverflowNode(node_idx))
            node_idx = infections.states[node_idx].next
        end
    end

    return nothing
end

"""
    _disease_flags(s::InfectionState, tick::Int16, end_tick::Int16)::DiseaseFlags

Single source of truth for the per-tick disease-state predicates of one active infection.
"""
@inline function _disease_flags(s::InfectionState, tick::Int16, end_tick::Int16)
    bits = UInt8(0)
    s.exposure <= tick < end_tick && (bits |= FLAG_INFECTED)
    s.infectiousness_onset <= tick < end_tick && (bits |= FLAG_INFECTIOUS)
    Int16(0) <= s.symptom_onset <= tick < end_tick && (bits |= FLAG_SYMPTOMATIC)
    Int16(0) <= s.severeness_onset <= tick < s.severeness_offset && (bits |= FLAG_SEVERE)
    Int16(0) <= s.critical_onset <= tick < s.critical_offset && (bits |= FLAG_CRITICAL)
    return DiseaseFlags(bits)
end

"""
    _step_infection!(ind, infections, pathogens, removal_buf, loc, tick, rng)

Processes the single infection at slot `loc` (a `_CacheSlot` or `_OverflowNode`) for `tick`:
handles recovery and the per-tick infectiousness recompute, reading/writing/clearing
the slot through `_slot_state` / `_set_slot!` / `_clear_slot!` dispatch. Shared by both
branches of `progress_disease!`. Returns the record's `DiseaseFlags` contribution.
"""
@inline function _step_infection!(ind::Individual, infections::InfectionRegistry, pathogens::P, removal_buf, loc, tick::Int16, rng::Xoshiro) where {P<:Tuple}
    state = _slot_state(ind, infections, loc)

    # check recovery
    if Int16(0) < state.recovery <= tick
        infected!(ind, state.pathogen_id, false)
        detected!(ind, state.pathogen_id, false)
        _clear_slot!(ind, infections, loc)
        _stage_slot_removal!(removal_buf, ind, loc)
        return DiseaseFlags()
    end

    # update infectiousness while active
    end_tick = state.recovery
    if state.exposure <= tick < end_tick
        level = _infectiousness_level(get_pathogen(pathogens, state.pathogen_id), state, ind, tick, rng)
        if level != state.infectiousness
            state = _setstate(state, Val(:infectiousness), level)
            _set_slot!(ind, infections, loc, state)
        end
    end

    return _disease_flags(state, tick, end_tick)
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
function progress_disease!(
    individual::Individual, 
    infections::InfectionRegistry, 
    pathogens::P, 
    removal_buf::Vector{_SlotRemoval},
    tick::Int16, 
    rng::Xoshiro
) where {P<:Tuple}

    dead(individual) && return nothing

    # host death is driven by the precomputed host timeline, not per-infection
    if Int16(0) <= individual.death <= tick
        _process_death!(individual, individual.killing_pathogen_id, infections, removal_buf)
        return nothing
    end

    # OR-accumulated disease flags across all active infections
    acc = DiseaseFlags()

    # process cache slots
    @inbounds for i in 1:INFECTIONS_CACHE_SIZE
        individual.infection_cache[i].active || continue
        acc |= _step_infection!(individual, infections, pathogens, removal_buf, _CacheSlot(Int32(i)), tick, rng)
    end

    # process overflow nodes
    if individual.infection_head != 0
        node = individual.infection_head
        while node != 0
            next_node = (@inbounds infections.states[node].next)   # capture before any mutation
            acc |= _step_infection!(individual, infections, pathogens, removal_buf, _OverflowNode(node), tick, rng)
            node = next_node
        end
    end

    # commit accumulated disease flags in one store (host care states are derived on the fly;
    # the dead bit is 0 here since a dead individual would have returned above)
    individual.disease_flags = acc

    return nothing
end



### RESET DISEASE PROGRESSION ###
"""
    reset!(individual::Individual, infections::InfectionRegistry)

Resets all non-static values like the disease progression timing.
The individual will get back into a infections where it was never infected, vaccinated, tested, etc.
"""
function reset!(individual::Individual, infections::InfectionRegistry, immunities::ImmunityRegistry)
    individual.disease_flags = DiseaseFlags()

    # reset host health timeline
    individual.hospital_admission = DEFAULT_TICK
    individual.hospital_discharge = DEFAULT_TICK
    individual.icu_admission = DEFAULT_TICK
    individual.icu_discharge = DEFAULT_TICK
    individual.ventilation_admission = DEFAULT_TICK
    individual.ventilation_discharge = DEFAULT_TICK
    individual.death = DEFAULT_TICK

    # Clean overflow before clearing flags
    individual.infection_head != 0 && remove_infections!(infections, individual)
    individual.immunity_head != 0 && remove_immunities!(immunities, individual)

    individual.infection_cache = ntuple(_ -> InfectionState(), INFECTIONS_CACHE_SIZE)
    individual.number_of_infections = 0
    individual.active_pathogens_mask = 0
    individual.detected_mask = 0
    individual.killing_pathogen_id = DEFAULT_PATHOGEN_ID

    individual.immunity_cache = ntuple(_ -> ImmunityState(), IMMUNITY_CACHE_SIZE)
    individual.needs_immunity_update = false

    individual.quarantine_status = QUARANTINE_STATE_NO_QUARANTINE
    individual.quarantine_tick = DEFAULT_TICK
    individual.quarantine_release_tick = DEFAULT_TICK
end
