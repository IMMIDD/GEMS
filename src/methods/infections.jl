#=
THIS FILE HANDLES INFECTIONS ON DIFFERENT LEVELS
This means, that the functionality to directly infect someone and spread a disease
is contained here.
=#
export infect!, spread_infection!, try_to_infect!, update_individual!, sample_contacts, get_containers!

export settings



"""
    settings(individual::Individual, sim::Simulation)

Return a dictionary with the assigned setting types as keys and the assigned IDs as values.
"""
function settings(individual::Individual, sim::Simulation)::Dict{DataType, Int32}
    d::Dict{DataType, Int32} = Dict()
    if household_id(individual)>=0
        d[Household] = household_id(individual)
        get_containers!(settings(sim, Household)[d[Household]], d, sim)
    end
    if office_id(individual)>=0
        d[Office] = office_id(individual)
        get_containers!(settings(sim, Office)[d[Office]], d, sim)
    end
    if class_id(individual)>=0
        d[SchoolClass] = class_id(individual)
        get_containers!(settings(sim, SchoolClass)[d[SchoolClass]], d, sim)
    end
    if municipality_id(individual)>=0
        d[Municipality] = municipality_id(individual)
        get_containers!(settings(sim, Municipality)[d[Municipality]], d, sim)
    end

    # delete later
    if GlobalSetting in keys(sim.settings.settings)
        d[GlobalSetting] = GLOBAL_SETTING_ID
    end

    return d
end

"""
    claim_active_slot!(individual::Individual, pathogen_id::Int8)

Immediately writes `pathogen_id` into the first free slot of `individual.active_pathogens`
so that concurrent infectors in the same setting cannot infect the same individual twice
within a single tick.
"""
@inline function claim_active_slot!(individual::Individual, pathogen_id::Int8)
    @inbounds for s in 1:MAX_CONCURRENT_INFECTIONS
        if individual.active_pathogens[s] == Int8(0)
            individual.active_pathogens = Base.setindex(individual.active_pathogens, pathogen_id, s)
            return nothing
        end
    end
end


"""
    infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen,
        sim::Union{Simulation, Nothing},
        rng::Xoshiro,
        infecter_id::Int32,
        setting_id::Int32 ,
        lon::Float32,
        lat::Float32,
        setting_type::Char,
        ags::Int32,
        source_infection_id::Int32)

Infect `infectee` with the specified `pathogen` and calculate time to infectiousness
and time to recovery. Optional arguments `infecter_id`. `setting_id`, and `setting_type`
can be passed for logging. It's not required to calulate the infection. The infection
can only be logged, if `Simulation` object is passed (as this object holds the logger).

# Parameters

- `infectee::Individual`: Individual to infect
- `tick::Int16`: Infection tick
- `pathogen::Pathogen`: Pathogen to infect the individual with
- `sim::Union{Simulation, Nothing}` = Simulation object (used to get logger)
- `rng::Xoshiro`: RNG to use for stochastic parts
- `infecter_id::Int32`: Infecting individual
- `setting_id::Int32`: ID of setting this infection happens in
- `lon::Float32`: Longitude of the infection infection location (setting) 
- `lat::Float32`: Latitude of the infection infection location (setting)
- `setting_type::Char`: Setting type as char (e.g. "h" for `Household`)
- `ags::Int32`*: Amtlicher Gemeindeschlüssel (community identification number) of the region this infection happened in as Integer value
- `source_infection_id::Int32`: Current infection ID of the infecting individual

# Returns

- `Int32`: New infection ID

"""
function infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen,
        sim::Union{Simulation, Nothing},
        rng::Xoshiro,
        infecter_id::Int32,
        setting_id::Int32,
        lon::Float32,
        lat::Float32,
        setting_type::Char,
        ags::Int32 ,
        source_infection_id::Int32)


    # calculate disease progression
    paf = progression_assignment(pathogen)
    pc = assign(infectee, paf, rng)

    prog = progressions(pathogen)[pc]
    dp = calculate_progression(infectee, tick, prog, rng)::DiseaseProgression

    # log infection
    new_infection_id = log!(
        infectionlogger(sim),
        infecter_id,
        id(infectee),
        id(pathogen),
        nameof(pc),
        tick,
        infectiousness_onset(dp),
        symptom_onset(dp),
        severeness_onset(dp),
        hospital_admission(dp),
        hospital_discharge(dp),
        icu_admission(dp),
        icu_discharge(dp),
        ventilation_admission(dp),
        ventilation_discharge(dp),
        severeness_offset(dp),
        recovery(dp),
        death(dp),
        setting_id,
        setting_type,
        lat,
        lon,
        ags,
        source_infection_id
    )

    # stage for serial flush after the threaded phase
    push!(infection_buffers(sim)[Threads.threadid()], PendingInfection(id(infectee), id(pathogen), new_infection_id, dp))

    # increase lifetime number of infections
    inc_number_of_infections!(infectee)

    # block same-tick re-infection by the same pathogen
    claim_active_slot!(infectee, id(pathogen))
    
    # set infected flag
    infected!(infectee, true)
    
    return new_infection_id
end

"""
    infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen;
        sim::Union{Simulation, Nothing} = nothing,
        rng::Xoshiro = default_gems_rng(),
        infecter_id::Int32 = Int32(-1),
        setting_id::Int32 = Int32(-1),
        lon::Float32 = NaN32,
        lat::Float32 = NaN32,
        setting_type::Char = '?',
        ags::Int32 = Int32(-1),
        source_infection_id::Int32 = DEFAULT_INFECTION_ID)

Infect `infectee` with the pathogen of the simulation at the current tick of the simulation. Wrapper for optional keyword arguments

# Parameters

- `infectee::Individual`: Individual to infect
- `tick::Int16`: Infection tick
- `pathogen::Pathogen`: Pathogen to infect the individual with
- `sim::Union{Simulation, Nothing} = nothing` *(optional)* = Simulation object (used to get logger)
- `rng::Xoshiro = default_gems_rng()` *(optional)*: RNG to use for stochastic parts
- `infecter_id::Int32 = Int32(-1)` *(optional)*: Infecting individual
- `setting_id::Int32 = Int32(-1)` *(optional)*: ID of setting this infection happens in
- `lon::Float32 = NaN32` *(optional)*: Longitude of the infection infection location (setting) 
- `lat::Float32 = NaN32` *(optional)*: Latitude of the infection infection location (setting)
- `setting_type::Char = '?'` *(optional)*: Setting type as char (e.g. "h" for `Household`)
- `ags::Int32 = Int32(-1)` *(optional)*: Amtlicher Gemeindeschlüssel (community identification number) of the region this infection happened in as Integer value
- `source_infection_id::Int32 = DEFAULT_INFECTION_ID` *(optional)*: Current infection ID of the infecting individual

# Returns

- `Int32`: New infection ID

"""

function infect!(infectee::Individual,
        tick::Int16,
        pathogen::Pathogen;
        # optional keyword arguments (mainly needed for logging)
        sim::Union{Simulation, Nothing} = nothing,
        rng::Xoshiro = default_gems_rng(),
        infecter_id::Int32 = Int32(-1),
        setting_id::Int32 = Int32(-1),
        lon::Float32 = NaN32,
        lat::Float32 = NaN32,
        setting_type::Char = '?',
        ags::Int32 = Int32(-1),
        source_infection_id::Int32 = DEFAULT_INFECTION_ID)

        infect!(infectee, tick, pathogen, sim, rng, infecter_id, setting_id, lon, lat, setting_type, ags, source_infection_id)
end
"""
    infect!(infectee::Individual, sim::Simulation)

Infect `infectee` with the pathogen of the simulation at the current tick of the simulation.
Mainly a convenience wrapper around `infect!` with less parameters.
Used for example in test cases.
"""
infect!(infectee::Individual, sim::Simulation) = infect!(infectee, tick(sim), only(values(pathogens(sim))); sim = sim, rng = rng(sim))

"""
    try_to_infect!(infctr::Individual, infctd::Individual, sim::Simulation, pathogen::Pathogen, setting::Setting,
        source_infection_id::Int32)

Tries to infect the `infctd` with the given `pathogen` transmitted by `infctr `at time `tick(sim)` with `sim` 
being the simulation. Success depends on whether the agent is alive, not already infected
an whether an infection event was sampled using the provided distribution or probability.
Returns `true` if infection was successful.

# Parameters

- `infctr::Individual`: Infecting individual
- `infctd::Individual`: Individual to infect
- `sim::Simulation`: Simulation object
- `pathogen::Pathogen`: Pathogen to infect the individual with
- `setting::Setting`: Setting this infection happens in
- `source_infection_id::Int32`: Current infection ID of the infecting individual

# Returns

- `Bool`: True if infection was successful, false otherwise

"""
function try_to_infect!(infctr::Individual,
        infctd::Individual,
        sim::Simulation,
        pathogen::Pathogen,
        setting::Setting,
        source_infection_id::Int32)::Bool

    # if one of both is dead
    if dead(infctr) || dead(infctd)
        return false
    end

    # if one of both is hospitalized
    if hospitalized(infctr) || hospitalized(infctd)
        return false
    end
    
    # if infectee is already infected with the current pathogen
    if any(==(id(pathogen)), infctd.active_pathogens)
        return false
    end

    # if infectee already has MAX_CONCURRENT_INFECTIONS active pathogens
    if !any(==(Int8(0)), infctd.active_pathogens)
        return false
    end


    # calculate infection probability
    infection_probability = transmission_probability(
        pathogen |> transmission_function, 
        pathogen |> id,
        infctr, infctd, 
        setting, sim |> tick, rng(sim)
    )

    # try to infect
    if gems_rand(sim) < infection_probability
        hh = settings(sim, Household)[household_id(infctd)]::Household
        infect!(infctd, 
            tick(sim), 
            pathogen,
            sim,
            rng(sim),
            id(infctr),
            id(setting),
            lon(hh), 
            lat(hh),
            settingchar(setting),
            ags(setting) |> id,
            source_infection_id)
        return true
    end

    return false

end

"""
    try_to_infect!(infctr::Individual, infctd::Individual, sim::Simulation, pathogen::Pathogen, setting::Setting;
        source_infection_id::Int32 = DEFAULT_INFECTION_ID)

Tries to infect the `infctd` with the given `pathogen` transmitted by `infctr `at time `tick(sim)` with `sim` 
being the simulation. Success depends on whether the agent is alive, not already infected
an whether an infection event was sampled using the provided distribution or probability.
Returns `true` if infection was successful. Wrapper for optional keyword arguments.

# Parameters

- `infctr::Individual`: Infecting individual
- `infctd::Individual`: Individual to infect
- `sim::Simulation`: Simulation object
- `pathogen::Pathogen`: Pathogen to infect the individual with
- `setting::Setting`: Setting this infection happens in
- `source_infection_id::Int32 = DEFAULT_INFECTION_ID` *(optional)*: Current infection ID of the infecting individual

# Returns

- `Bool`: True if infection was successful, false otherwise

"""

function try_to_infect!(infctr::Individual,
        infctd::Individual,
        sim::Simulation,
        pathogen::Pathogen,
        setting::Setting;
        source_infection_id::Int32 = DEFAULT_INFECTION_ID)::Bool

        try_to_infect!(infctr, infctd, sim, pathogen, setting, source_infection_id)
end


"""
    update_individual!(indiv::Individual, tick::Int16, sim::Simulation)

Update the individual disease progression, handle its recovery and log its possible death.
If the individual is not infected, this function will just return.
"""
function update_individual!(indiv::Individual, tick::Int16, sim::Simulation)
    was_dead = dead(indiv)
    was_symptomatic = symptomatic(indiv)
    was_hospitalized = is_hospitalized(indiv)

    # update immunity levels
    if indiv.needs_immunity_update
        update_immunity!(indiv, immunity_registry(sim), pathogens(sim), tick, rng(sim))
    end

    # progress disease for currently infected individuals
    if infected(indiv)
        progress_disease!(indiv, sim.infection_registry, pathogens(sim), tick, rng(sim))

        if !was_dead && dead(indiv)
            log!(deathlogger(sim), id(indiv), indiv.killing_pathogen_id, tick)
        end
    end


    if !was_symptomatic && symptomatic(indiv)
        for st in sim |> symptom_triggers
            trigger(st, indiv, sim)
        end
    end
    if !was_hospitalized && is_hospitalized(indiv)
        for ht in sim |> hospitalization_triggers
            trigger(ht, indiv, sim)
        end
    end
end

"""
    can_infect(ind::Individual, setting::Setting)::Bool

Determines whether the individual can infect others in the given setting.
Checks for infectiousness, setting openness, and quarantine status.

# Parameters
- `ind::Individual`: Individual to check
- `setting::Setting`: Setting to check

# Returns
- `Bool`: True if the individual can infect others in the setting, false otherwise
"""
function can_infect(ind::Individual, setting::Setting)::Bool
    # if individual is not infectious
    if !infectious(ind)
        return false
    end

    # if individual is hospitalized
    if is_hospitalized(ind)
        return false
    end

    # if setting is closed
    if !is_open(setting)
        return false
    end

    # severe symptoms prevent infecting others outside the household
    if is_severe(ind) && (typeof(setting) != Household)
        return false
    end

    # if individual is quarantined
    if isquarantined(ind)
        # if individual is in household quarantine and setting is not Household
        if quarantine_status(ind) == QUARANTINE_STATE_HOUSEHOLD_QUARANTINE && (typeof(setting) != Household)
            return false
        end
    end

    return true
end

"""
    can_be_contacted(ind::Individual, setting::Setting)::Bool

Determines whether the individual can be contacted (and thus infected) in the given setting.
Checks for death and quarantine status.

# Parameters
- `ind::Individual`: Individual to check
- `setting::Setting`: Setting to check

# Returns
- `Bool`: True if the individual can be contacted in the setting, false otherwise
"""
function can_be_contacted(ind::Individual, setting::Setting)::Bool
    # if individual is dead
    if dead(ind)
        return false
    end

    # if individual is hospitalized
    if is_hospitalized(ind)
        return false
    end

    # if individual is quarantined
    if isquarantined(ind)
        # if individual is in household quarantine and setting is not Household
        if quarantine_status(ind) == QUARANTINE_STATE_HOUSEHOLD_QUARANTINE && (typeof(setting) != Household)
            return false
        end
    end

    return true
end


"""
    spread_infection!(setting::Setting, sim::Simulation)

Spreads the infection of `pathogen` inside the provided setting. This will simulate the
infection dynamics at the time `tick(sim)` inside `setting` within the context of the
simulation `sim`. This will also update all settings, the individual is part of, if the
infection is successful.

# Parameters

- `setting::Setting`: Setting in which the pathogen shall be spreaded
- `sim::Simulation`: Simulation object

"""
function spread_infection!(setting::Setting, sim::Simulation)
    tid = Threads.threadid()
    p_buffer = sim.present_buffers[tid]
    c_buffer = sim.contact_buffers[tid]

    empty!(p_buffer)
    present_individuals!(p_buffer, setting, sim)

    csm = setting.contact_sampling_method

    num_infected = process_infections!(p_buffer, c_buffer, csm, setting, sim)

    if num_infected == 0
        for ind in individuals(setting, sim)
            if infected(ind)
                num_infected += 1
            end
        end
        if num_infected == 0
            deactivate!(setting)
        end
    end
end


function process_infections!(p_buffer, c_buffer, csm, setting, sim)
    num_infected = 0
    current_tick = tick(sim)
    current_rng = rng(sim)

    for ind_index in 1:length(p_buffer)
        ind = p_buffer[ind_index]
        if infected(ind)
            num_infected += 1
            if can_infect(ind, setting)
                sample_contacts!(c_buffer, csm, setting, ind_index, p_buffer, current_tick, true, current_rng)

                pids = ind.active_pathogens
                inflev = ind.infectiousness
                infids = ind.infection_ids
                pathogen_iter = gems_rand(current_rng, Bool) ? (MAX_CONCURRENT_INFECTIONS:-1:1) : (1:MAX_CONCURRENT_INFECTIONS)

                for i in pathogen_iter
                    pid = pids[i]
                    pid == 0 && continue
                    level = inflev[i]
                    level == 0 && continue 

                    pat = get_pathogen(sim, pid)
                    src_inf_id = infids[i]

                    for c in c_buffer
                        if can_be_contacted(c, setting)
                            if try_to_infect!(ind, c, sim, pat, setting, src_inf_id)
                                for (type, sid) in settings_tuple(c)
                                    if sid != DEFAULT_SETTING_ID
                                        current_setting = settings(sim, type)[sid]
                                        activate!(current_setting, sim)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return num_infected
end