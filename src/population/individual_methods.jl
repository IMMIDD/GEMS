###
### INDIVIDUAL METHODS
### Methods on Individual that depend on Simulation or on any other type defined after
### individuals.jl (cannot live there due to include order), and the disease-progression engine.
###

# EXPORTS
# setting membership and lookup
export household, office, schoolclass, getsetting, settings_tuple
export membership_setting_types
# registry-based getters
export get_infection_state, get_immunity_state
export infection_id
export infectiousness
export immunity_level
# disease progression timeline
export exposure, infectiousness_onset, symptom_onset, severeness_onset, severeness_offset
export recovery
# testing
export get_test_state
export last_test
export last_test_result
export was_reported
export record_test!
# quarantine
export quarantine_release_tick!
# vaccination
export vaccinate!
export vaccination_tick, vaccine_id, isvaccinated, number_of_vaccinations
# disease progression engine
export progress_disease!



### INDIVIDUAL-SETTING MEMBERSHIP & SETTING LOOKUP ###

"""
    membership_setting_types(::Type{Individual})

The `IndividualSetting` types an `Individual` may hold a plan entry for. `GlobalSetting` is
excluded; it holds everyone, and `setting_id` answers for it from the constant.
"""
membership_setting_types(::Type{Individual}) = (Household, Office, SchoolClass, Municipality)

"""
    setting_id(individual::Individual, ::Type{T}, plans::ActivityPlanStore) where {T<:Setting}

Returns the id of the individual's primary setting of type `T` (the first entry of that type),
or `DEFAULT_SETTING_ID`.
"""
@inline function setting_id(individual::Individual, ::Type{T}, plans::ActivityPlanStore)::Int32 where {T<:Setting}
    slot = plan_slot(plans, individual, T)
    slot == 0 && return DEFAULT_SETTING_ID
    return @inbounds setting_id(plans.entries[slot])
end

# there is only one GlobalSetting and everyone is in it, so it needs no entry
@inline setting_id(individual::Individual, ::Type{GlobalSetting}, plans::ActivityPlanStore)::Int32 = GLOBAL_SETTING_ID

"""
    setting_id(individual::Individual, ::Type{T}, sim::Simulation) where {T<:Setting}

Convenience for callers holding a `Simulation` rather than the store.
"""
@inline setting_id(individual::Individual, ::Type{T}, sim::Simulation) where {T<:Setting} =
    setting_id(individual, T, activity_plans(sim))

# The id of the individual's primary setting of type index `tidx`, or `DEFAULT_SETTING_ID`.
@inline function _setting_id(individual::Individual, tidx::UInt8, plans::ActivityPlanStore)::Int32
    start, len = _plan_type_run(plans, individual, tidx)
    return len == 0 ? DEFAULT_SETTING_ID : @inbounds setting_id(plans.entries[Int(individual.plan_offset) + start])
end

"""
    setting_ids(individual::Individual, ::Type{T}, plans::ActivityPlanStore) where {T<:Setting}

Returns the ids of every setting of type `T` the individual belongs to, primary first.
"""
function setting_ids(individual::Individual, ::Type{T}, plans::ActivityPlanStore)::Vector{Int32} where {T<:Setting}
    return Int32[@inbounds(setting_id(plans.entries[s])) for s in plan_slots(plans, individual, T)]
end

# there is only one GlobalSetting and everyone is in it, so it needs no entry
setting_ids(individual::Individual, ::Type{GlobalSetting}, plans::ActivityPlanStore)::Vector{Int32} = [GLOBAL_SETTING_ID]

"""
    setting_ids(individual::Individual, ::Type{T}, sim::Simulation) where {T<:Setting}

Convenience for callers holding a `Simulation` rather than the store.
"""
setting_ids(individual::Individual, ::Type{T}, sim::Simulation) where {T<:Setting} =
    setting_ids(individual, T, activity_plans(sim))

"""
    setting_ids(individual::Individual, ::Type{T}, sim::Simulation) where {T<:ContainerSetting}

Returns the ids of every container of type `T` above the individual's settings, primary first and each once
"""
function setting_ids(individual::Individual, ::Type{T}, sim::Simulation)::Vector{Int32} where {T<:ContainerSetting}
    L = _leaf_type(T)
    plans = activity_plans(sim)
    leaves = settings(sim, L)
    ids = Int32[]
    for slot in plan_slots(plans, individual, L)
        cid = _ancestor_id(leaves[@inbounds(setting_id(plans.entries[slot]))], T, sim)
        cid == DEFAULT_SETTING_ID || cid in ids || push!(ids, cid)
    end
    return ids
end

"""
    member_index(individual::Individual, ::Type{T}, plans::ActivityPlanStore) where {T<:Setting}

Returns the individual's position in the member frame of their primary setting of type `T`.
"""
@inline function member_index(individual::Individual, ::Type{T}, plans::ActivityPlanStore)::Int32 where {T<:Setting}
    _check_indexed(plans)
    slot = plan_slot(plans, individual, T)
    slot == 0 && return DEFAULT_MEMBER_INDEX
    return @inbounds member_index(plans.entries[slot])
end

"""
    settings_tuple(individual::Individual, plans::ActivityPlanStore)

Returns all of the individual's memberships as `(type, id)` pairs, in plan order.
"""
function settings_tuple(individual::Individual, plans::ActivityPlanStore)
    return [(setting_type_from_index(setting_type_of(e)), setting_id(e))
            for e in plan_entries(plans, individual)]
end

"""
    settings_tuple(individual::Individual, sim::Simulation)

Convenience for callers holding a `Simulation` rather than the store.
"""
settings_tuple(individual::Individual, sim::Simulation) = settings_tuple(individual, activity_plans(sim))

### SETTING ACCESSORS ###
# These resolve through the plan store, taken directly or via a `Simulation`.

"""
    household_id(individual::Individual, plans::ActivityPlanStore)

Returns the id of an individual's primary household.
"""
@inline household_id(individual::Individual, plans::ActivityPlanStore)::Int32 = setting_id(individual, Household, plans)

"""
    household_id(individual::Individual, sim::Simulation)

Convenience for callers holding a `Simulation` rather than the store.
"""
@inline household_id(individual::Individual, sim::Simulation)::Int32 = household_id(individual, activity_plans(sim))

"""
    office_id(individual::Individual, plans::ActivityPlanStore)

Returns the id of an individual's primary office.
"""
@inline office_id(individual::Individual, plans::ActivityPlanStore)::Int32 = setting_id(individual, Office, plans)

"""
    office_id(individual::Individual, sim::Simulation)

Convenience for callers holding a `Simulation` rather than the store.
"""
@inline office_id(individual::Individual, sim::Simulation)::Int32 = office_id(individual, activity_plans(sim))

"""
    class_id(individual::Individual, plans::ActivityPlanStore)

Returns the id of an individual's primary school class.
"""
@inline class_id(individual::Individual, plans::ActivityPlanStore)::Int32 = setting_id(individual, SchoolClass, plans)

"""
    class_id(individual::Individual, sim::Simulation)

Convenience for callers holding a `Simulation` rather than the store.
"""
@inline class_id(individual::Individual, sim::Simulation)::Int32 = class_id(individual, activity_plans(sim))

"""
    municipality_id(individual::Individual, plans::ActivityPlanStore)

Returns the id of an individual's primary municipality.
"""
@inline municipality_id(individual::Individual, plans::ActivityPlanStore)::Int32 = setting_id(individual, Municipality, plans)

"""
    municipality_id(individual::Individual, sim::Simulation)

Convenience for callers holding a `Simulation` rather than the store.
"""
@inline municipality_id(individual::Individual, sim::Simulation)::Int32 = municipality_id(individual, activity_plans(sim))

"""
    is_working(individual::Individual, plans::ActivityPlanStore)

Returns `true` if individual is assigned to an instance of type `Office`.
"""
is_working(individual::Individual, plans::ActivityPlanStore) = plan_slot(plans, individual, Office) != 0

"""
    is_working(individual::Individual, sim::Simulation)

Convenience for callers holding a `Simulation` rather than the store.
"""
is_working(individual::Individual, sim::Simulation) = is_working(individual, activity_plans(sim))

"""
    is_student(individual::Individual, plans::ActivityPlanStore)

Returns `true` if individual is assigned to an instance of type `SchoolClass`.
"""
is_student(individual::Individual, plans::ActivityPlanStore) = plan_slot(plans, individual, SchoolClass) != 0

"""
    is_student(individual::Individual, sim::Simulation)

Convenience for callers holding a `Simulation` rather than the store.
"""
is_student(individual::Individual, sim::Simulation) = is_student(individual, activity_plans(sim))

"""
    has_municipality(individual::Individual, plans::ActivityPlanStore)

Returns `true` if individual is assigned to an instance of type `Municipality`.
"""
has_municipality(individual::Individual, plans::ActivityPlanStore) = plan_slot(plans, individual, Municipality) != 0

"""
    has_municipality(individual::Individual, sim::Simulation)

Convenience for callers holding a `Simulation` rather than the store.
"""
has_municipality(individual::Individual, sim::Simulation) = has_municipality(individual, activity_plans(sim))


### setting extraction from individuals
"""
    household(i::Individual, sim::Simulation)::Household

Returns the `Household` instance referenced in an individual. 
"""
function household(i::Individual, sim::Simulation)::Household
    return settings(sim, Household)[household_id(i, sim)]
end

"""
    office(i::Individual, sim::Simulation)::Office

Returns the `Office` instance referenced in an individual. 
"""
function office(i::Individual, sim::Simulation)::Office
    oid = office_id(i, sim)
    oid == DEFAULT_SETTING_ID && throw(ArgumentError("Individual $(id(i)) is not assigned to an Office"))
    return settings(sim, Office)[oid]
end


"""
    schoolclass(i::Individual, sim::Simulation)::SchoolClass

Returns the `SchoolClass` instance referenced in an individual. 
"""
function schoolclass(i::Individual, sim::Simulation)::SchoolClass
    cid = class_id(i, sim)
    cid == DEFAULT_SETTING_ID && throw(ArgumentError("Individual $(id(i)) is not assigned to a School Class"))
    return settings(sim, SchoolClass)[cid]
end

"""
    municipality(i::Individual, sim::Simulation)::Municipality

Returns the `Municipality` instance referenced in an individual. 
"""
function municipality(i::Individual, sim::Simulation)::Municipality
    return settings(sim, Municipality)[municipality_id(i, sim)]
end

# The individual's primary setting of type `T`, or `nothing` if they hold none. A container holds no
# plan entries, so `setting_ids` finds it through the leaves below it.
function _primary_setting(i::Individual, sim::Simulation, ::Type{T}) where {T<:Setting}
    ids = setting_ids(i, T, sim)
    return isempty(ids) ? nothing : settings(sim, T)[ids[1]]
end

"""
    getsetting(i::Individual, sim::Simulation, ::Type{T}) where {T<:Setting}

Returns the individual's primary setting of type `T`, a container through the settings below it;
throws if they hold none.
"""
function getsetting(i::Individual, sim::Simulation, ::Type{T}) where {T<:Setting}
    s = _primary_setting(i, sim, T)
    isnothing(s) && throw(ArgumentError("Individual $(id(i)) is not assigned to a $(setting_type_name(T))"))
    return s
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

"""
    get_infection_state(ind::Individual, sim::Simulation, pathogen_id::Int8)::InfectionState

Convenience wrapper that routes to the correct `InfectionRegistry` shard for the given individual.
"""
@inline get_infection_state(ind::Individual, sim::Simulation, pathogen_id::Int8)::InfectionState =
    get_infection_state(ind, infection_registry(sim, ind), pathogen_id)

"""
    get_immunity_state(ind::Individual, sim::Simulation, pathogen_id::Int8)::ImmunityState

Convenience wrapper that routes to the correct `ImmunityRegistry` shard for the given individual.
"""
@inline get_immunity_state(ind::Individual, sim::Simulation, pathogen_id::Int8)::ImmunityState =
    get_immunity_state(ind, immunity_registry(sim, ind), pathogen_id)

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
    immunity_level(individual::Individual, immunities::ImmunityRegistry, pathogen_id::Int8)

Removed, throws: levels are computed on read and need the simulation.
"""
immunity_level(::Individual, ::ImmunityRegistry, ::Int8) =
    throw(ArgumentError("immunity_level(individual, immunities, pathogen_id) was removed; use immunity_level(individual, sim, pathogen_id[, tick])."))

"""
    immunity_level(individual::Individual, ::Nothing, pathogen_id::Int8, tick::Int16 = Int16(0))::Int8

Returns 0: without a simulation there is no immunity.
"""
immunity_level(::Individual, ::Nothing, ::Int8, ::Int16 = Int16(0))::Int8 = Int8(0)

"""
    immunity_level(individual::Individual, sim::Simulation, pathogen_id::Int8, tick::Int16 = tick(sim))::Int8

Returns the immunity level (0-100) against `pathogen_id` at `tick`, or 0 without a record.
"""
@inline immunity_level(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16 = tick(sim))::Int8 =
    immunity_level(get_immunity_state(individual, sim, pathogen_id), individual, sim, t)

"""
    immunity_level(state::ImmunityState, individual::Individual, sim::Simulation, tick::Int16 = tick(sim))::Int8

Returns the level (0-100) of one immunity record at `tick`, e.g. from `each_immunity`.
"""
function immunity_level(state::ImmunityState, individual::Individual, sim::Simulation, t::Int16 = tick(sim))::Int8
    _immunity_recorded(state) || return Int8(0)
    return _with_pathogen(p -> _immunity_level(p, state, individual, sim, t), sim.pathogens, state.pathogen_id)
end

# whether `state` holds natural or vaccine immunity
@inline _immunity_recorded(state::ImmunityState) = natural_immunity_recorded(state) || vaccine_immunity_recorded(state)

# level of a recorded `state` from the already looked-up `pathogen`
@inline function _immunity_level(pathogen, state::ImmunityState, individual::Individual, sim::Simulation, t::Int16)::Int8
    rng = _keyed_immunity_rng(sim.seed, id(individual), state.pathogen_id)
    return calculate_immunity(immunity_profile(pathogen), state, individual, t, rng)
end

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

exposure(ind::Individual, sim::Simulation, pid::Int8) = exposure(ind, infection_registry(sim, ind), pid)
infectiousness_onset(ind::Individual, sim::Simulation, pid::Int8) = infectiousness_onset(ind, infection_registry(sim, ind), pid)
symptom_onset(ind::Individual, sim::Simulation, pid::Int8) = symptom_onset(ind, infection_registry(sim, ind), pid)
severeness_onset(ind::Individual, sim::Simulation, pid::Int8) = severeness_onset(ind, infection_registry(sim, ind), pid)
severeness_offset(ind::Individual, sim::Simulation, pid::Int8) = severeness_offset(ind, infection_registry(sim, ind), pid)
critical_onset(ind::Individual, sim::Simulation, pid::Int8) = critical_onset(ind, infection_registry(sim, ind), pid)
critical_offset(ind::Individual, sim::Simulation, pid::Int8) = critical_offset(ind, infection_registry(sim, ind), pid)
recovery(ind::Individual, sim::Simulation, pid::Int8) = recovery(ind, infection_registry(sim, ind), pid)


### DISEASE STATUS ###

"""
    is_infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isinfected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_infected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    isinfected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    infected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is infected with the given pathogen at tick `t`.
"""
function is_infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    return state.exposure >= 0 && state.exposure <= t < state.recovery
end
isinfected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_infected(individual, infections, pathogen_id, t)
infected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_infected(individual, infections, pathogen_id, t)
is_infected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_infected(individual, infection_registry(sim, individual), pathogen_id, t)
isinfected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_infected(individual, sim, pathogen_id, t)
infected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_infected(individual, sim, pathogen_id, t)

"""
    is_infectious(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isinfectious(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    infectious(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_infectious(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    isinfectious(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    infectious(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

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
is_infectious(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_infectious(individual, infection_registry(sim, individual), pathogen_id, t)
isinfectious(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_infectious(individual, sim, pathogen_id, t)
infectious(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_infectious(individual, sim, pathogen_id, t)

"""
    is_exposed(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isexposed(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    exposed(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_exposed(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    isexposed(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    exposed(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

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
is_exposed(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_exposed(individual, infection_registry(sim, individual), pathogen_id, t)
isexposed(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_exposed(individual, sim, pathogen_id, t)
exposed(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_exposed(individual, sim, pathogen_id, t)

"""
    is_presymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    ispresymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    presymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_presymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    ispresymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    presymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

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
is_presymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_presymptomatic(individual, infection_registry(sim, individual), pathogen_id, t)
ispresymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_presymptomatic(individual, sim, pathogen_id, t)
presymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_presymptomatic(individual, sim, pathogen_id, t)

"""
    is_symptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    issymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    symptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_symptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    issymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    symptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

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
is_symptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_symptomatic(individual, infection_registry(sim, individual), pathogen_id, t)
issymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_symptomatic(individual, sim, pathogen_id, t)
symptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_symptomatic(individual, sim, pathogen_id, t)

"""
    is_asymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isasymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    asymptomatic(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_asymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    isasymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    asymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

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
is_asymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_asymptomatic(individual, infection_registry(sim, individual), pathogen_id, t)
isasymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_asymptomatic(individual, sim, pathogen_id, t)
asymptomatic(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_asymptomatic(individual, sim, pathogen_id, t)

"""
    is_severe(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    issevere(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    severe(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_severe(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    issevere(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    severe(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

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
is_severe(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_severe(individual, infection_registry(sim, individual), pathogen_id, t)
issevere(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_severe(individual, sim, pathogen_id, t)
severe(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_severe(individual, sim, pathogen_id, t)

"""
    is_mild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    ismild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    mild(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_mild(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    ismild(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    mild(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

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
is_mild(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_mild(individual, infection_registry(sim, individual), pathogen_id, t)
ismild(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_mild(individual, sim, pathogen_id, t)
mild(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_mild(individual, sim, pathogen_id, t)

"""
    is_critical(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    iscritical(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    critical(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_critical(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    iscritical(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    critical(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

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
is_critical(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_critical(individual, infection_registry(sim, individual), pathogen_id, t)
iscritical(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_critical(individual, sim, pathogen_id, t)
critical(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_critical(individual, sim, pathogen_id, t)

"""
    is_recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isrecovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_recovered(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    isrecovered(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    recovered(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

Returns `true` if the individual is recovered from the given pathogen at tick `t`.
"""
function is_recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    state = get_infection_state(individual, infections, pathogen_id)
    !state.active && return false
    return 0 <= state.recovery <= t
end
isrecovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_recovered(individual, infections, pathogen_id, t)
recovered(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16) = is_recovered(individual, infections, pathogen_id, t)
is_recovered(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_recovered(individual, infection_registry(sim, individual), pathogen_id, t)
isrecovered(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_recovered(individual, sim, pathogen_id, t)
recovered(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_recovered(individual, sim, pathogen_id, t)

"""
    is_detected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    isdetected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    detected(individual::Individual, infections::InfectionRegistry, pathogen_id::Int8, t::Int16)
    is_detected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    isdetected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)
    detected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16)

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
is_detected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_detected(individual, infection_registry(sim, individual), pathogen_id, t)
isdetected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_detected(individual, sim, pathogen_id, t)
detected(individual::Individual, sim::Simulation, pathogen_id::Int8, t::Int16) = is_detected(individual, sim, pathogen_id, t)


### CARE DEMAND ###

"""
    _get_demand(individual::Individual, level::CareLevel)

The host's current demand count for one care level.
"""
@inline function _get_demand(individual::Individual, level::CareLevel)
    level === CARE_HOSPITAL && return individual.hospital_demands
    level === CARE_ICU && return individual.icu_demands
    level === CARE_VENTILATION && return individual.ventilation_demands
    throw(ArgumentError("no demand field on Individual for care level $level"))
end

"""
    _set_demand!(individual::Individual, level::CareLevel, n::Int16)

Writes one care level's demand count and returns it.
"""
@inline function _set_demand!(individual::Individual, level::CareLevel, n::Int16)
    level === CARE_HOSPITAL && return (individual.hospital_demands = n)
    level === CARE_ICU && return (individual.icu_demands = n)
    level === CARE_VENTILATION && return (individual.ventilation_demands = n)
    throw(ArgumentError("no demand field on Individual for care level $level"))
end

"""
    _adjust_demand!(individual::Individual, level::CareLevel, delta::Int16)

Adds `delta` to one care level's demand count and returns the new value, from which the caller
detects the 0-1 and 1-0 edges.

Throws on a negative result, which also catches overflow since `Int16` wraps.
"""
@inline function _adjust_demand!(individual::Individual, level::CareLevel, delta::Int16)
    n = _get_demand(individual, level) + delta
    n < 0 && throw(ArgumentError("care demand for $level went negative on host $(individual.id): a discharge with no matching admission. Only simulation-level reset! is safe."))
    return _set_demand!(individual, level, n)
end


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
updates `ind.detected_mask` if the test is a positive reportable result. During a simulation use
`record_test!(ind, sim, ...)`, or the state log counts the detection a tick late.
"""
@inline function record_test!(ind::Individual, tests::TestRegistry, pathogen_id::Int8, tick::Int16, test_result::Bool, reportable::Bool)
    detected = test_result && reportable
    set_test_state!(tests, id(ind), pathogen_id, tick, test_result, detected)
    detected && detected!(ind, pathogen_id, true)
    return nothing
end

"""
    record_test!(individual::Individual, sim::Simulation, pathogen_id::Int8, tick::Int16, test_result::Bool, reportable::Bool)

Records a test outcome in the correct `TestRegistry` shard, and counts a first detection for the state log.
"""
function record_test!(individual::Individual, sim::Simulation, pathogen_id::Int8, tick::Int16, test_result::Bool, reportable::Bool)
    was_detected = is_detected(individual)
    record_test!(individual, test_registry(sim, individual), pathogen_id, tick, test_result, reportable)
    if !was_detected && is_detected(individual)
        # tests come after the disease update's count; it counts them from the next tick on
        sim.state_log_counts[Threads.threadid()].detected += 1
        _mark_active!(sim, individual)
    end
    return nothing
end



### QUARANTINE STATUS ###

"""
    quarantine_release_tick!(individual::Individual, sim::Simulation, tick::Int16)

Sets an individual's quarantine release tick and flags the individual for the quarantine update.
"""
function quarantine_release_tick!(individual::Individual, sim::Simulation, tick::Int16)
    _quarantine_release_tick!(individual, tick)
    _mark_quarantined!(sim, individual)
end



### VACCINATION STATUS ###

"""
    vaccinate!(individual::Individual, registry::ImmunityRegistry, vaccine::Vaccine, tick::Int16)

Vaccinates an individual against a pathogen. Deprecated: use `vaccinate!(individual, sim, vaccine, tick)`,
which picks the individual's registry shard.
"""
function vaccinate!(individual::Individual, registry::ImmunityRegistry, vaccine::Vaccine, tick::Int16)
    @warn "vaccinate!(individual, registry, vaccine, tick) is deprecated; use vaccinate!(individual, sim, vaccine, tick), which picks the individual's registry shard." maxlog=1
    _vaccinate!(individual, registry, vaccine, tick)
end

# records the vaccination in `registry`
function _vaccinate!(individual::Individual, registry::ImmunityRegistry, vaccine::Vaccine, tick::Int16)
    log!(logger(vaccine), id(individual), target_pathogen_id(vaccine), tick)
    push_immunity!(registry, individual, target_pathogen_id(vaccine), IMMUNITY_SOURCE_VACCINE, tick, id(vaccine))
end

"""
    vaccinate!(individual::Individual, sim::Simulation, vaccine::Vaccine, tick::Int16)

Vaccinates an individual against the vaccine's target pathogen at `tick`.
"""
function vaccinate!(individual::Individual, sim::Simulation, vaccine::Vaccine, tick::Int16)
    _vaccinate!(individual, immunity_registry(sim, individual), vaccine, tick)
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



### UPDATE DISEASE PROGRESSION IN AGENTS ###

"""
    _infectiousness_level(pathogen, state, individual, tick, seed)

Function barrier that extracts the `InfectiousnessProfile` from `pathogen` and calls `calculate_infectiousness`
with the infection's keyed rng, left unkeyed for a profile that never draws.
"""
function _infectiousness_level(pathogen, state::InfectionState, individual::Individual, tick::Int16, seed::Int64)::Int8
    profile = infectiousness_profile(pathogen)
    rng = _draws_from_rng(profile) ? _keyed_infection_rng(seed, id(individual), state) : _profile_rng().rng
    return calculate_infectiousness(profile, state, individual, tick, rng)
end

"""
    _process_death!(individual::Individual, pathogen_id::Int8, infections::InfectionRegistry, removal_buf::Vector{_EndedInfection})

Handles the health flags and memory-management when an individual dies.
"""
@inline function _process_death!(individual::Individual, pathogen_id::Int8, infections::InfectionRegistry, removal_buf::Vector{_EndedInfection})
    individual.disease_flags = DiseaseFlags(FLAG_DEAD)

    individual.killing_pathogen_id = pathogen_id
    individual.active_pathogens_mask = 0
    individual.detected_mask = 0

    # stage all active cache memory for removal
    @inbounds for c in 1:INFECTIONS_CACHE_SIZE
        if individual.infection_cache[c].active
            _stage_ended_infection!(removal_buf, individual, _CacheSlot(Int32(c)))
            # Clear it AFTER pushing to the buffer
            individual.infection_cache = Base.setindex(individual.infection_cache, InfectionState(), c)
        end
    end

    # stage all active overflow memory for removal
    if individual.infection_head != 0
        node_idx = individual.infection_head
        while node_idx != 0
            _stage_ended_infection!(removal_buf, individual, _OverflowNode(node_idx))
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
    _next_update(ind::Individual, infections::InfectionRegistry, pathogens::P, tick::Int16) where {P<:Tuple}

The first tick after `tick` at which `progress_disease!` can change anything for `ind`, or `typemax(Int16)`.
"""
@inline function _next_update(ind::Individual, infections::InfectionRegistry, pathogens::P, tick::Int16) where {P<:Tuple}
    dead(ind) && return typemax(Int16)
    next = next_tick_after(tick, ind.death)
    @inbounds for i in 1:INFECTIONS_CACHE_SIZE
        s = ind.infection_cache[i]
        s.active && (next = min(next, _next_change(s, pathogens, tick)))
    end
    node = ind.infection_head
    while node != 0
        s = @inbounds infections.states[node]
        next = min(next, _next_change(s, pathogens, tick))
        node = s.next
    end
    return next
end

# the first tick after `tick` at which infection `s` changes its host's flags or its infectiousness
@inline function _next_change(s::InfectionState, pathogens::P, tick::Int16) where {P<:Tuple}
    flags = next_tick_after(tick, s.exposure, s.infectiousness_onset, s.symptom_onset,
        s.severeness_onset, s.severeness_offset, s.critical_onset, s.critical_offset, s.recovery)
    level = _with_pathogen(p -> next_infectiousness_change(infectiousness_profile(p), s, tick), pathogens, s.pathogen_id)
    return min(flags, level)
end

"""
    _step_infection!(ind, infections, pathogens, removal_buf, loc, tick, seed)

Processes the single infection at slot `loc` (a `_CacheSlot` or `_OverflowNode`) for `tick`:
handles recovery and the per-tick infectiousness recompute, reading/writing/clearing
the slot through `_slot_state` / `_set_slot!` / `_clear_slot!` dispatch. Shared by both
branches of `progress_disease!`. Returns the record's `DiseaseFlags` contribution.
"""
@inline function _step_infection!(ind::Individual, infections::InfectionRegistry, pathogens::P, removal_buf, loc, tick::Int16, seed::Int64) where {P<:Tuple}
    state = _slot_state(ind, infections, loc)

    # check recovery
    if Int16(0) < state.recovery <= tick
        infected!(ind, state.pathogen_id, false)
        detected!(ind, state.pathogen_id, false)
        _clear_slot!(ind, infections, loc)
        _stage_ended_infection!(removal_buf, ind, loc, state.pathogen_id, state.recovery)
        return DiseaseFlags()
    end

    # update infectiousness while active
    end_tick = state.recovery
    if state.exposure <= tick < end_tick
        level = _infectiousness_level(get_pathogen(pathogens, state.pathogen_id), state, ind, tick, seed)
        if level != state.infectiousness
            state = _setstate(state, Val(:infectiousness), level)
            _set_slot!(ind, infections, loc, state)
        end
    end

    return _disease_flags(state, tick, end_tick)
end

"""
    progress_disease!(individual::Individual, infections::InfectionRegistry, pathogens::P, removal_buf::Vector{_EndedInfection}, tick::Int16, seed::Int64) where {P<:Tuple}

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
    removal_buf::Vector{_EndedInfection},
    tick::Int16,
    seed::Int64
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
        acc |= _step_infection!(individual, infections, pathogens, removal_buf, _CacheSlot(Int32(i)), tick, seed)
    end

    # process overflow nodes
    if individual.infection_head != 0
        node = individual.infection_head
        while node != 0
            next_node = (@inbounds infections.states[node].next)   # capture before any mutation
            acc |= _step_infection!(individual, infections, pathogens, removal_buf, _OverflowNode(node), tick, seed)
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
The individual is returned to a state as if it had never been infected, vaccinated, tested, etc.

Only safe as part of simulation-level `reset!`, which also clears the `HealthSchedule`s. Called alone,
the host's queued transitions remain and the next to drain throws on a cleared counter.
"""
function reset!(individual::Individual, infections::InfectionRegistry, immunities::ImmunityRegistry)
    individual.disease_flags = DiseaseFlags()

    # reset host care state
    individual.hospital_demands = 0
    individual.icu_demands = 0
    individual.ventilation_demands = 0
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

    individual.quarantine_status = QUARANTINE_STATE_NO_QUARANTINE
    individual.quarantine_tick = DEFAULT_TICK
    individual.quarantine_release_tick = DEFAULT_TICK
end
