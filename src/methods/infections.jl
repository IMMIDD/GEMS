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
    infect!(infectee::Individual, tick::Int16, pathogen::Pathogen;
        sim::Union{Simulation, Nothing} = nothing,
        rng::AbstractRNG = Random.default_rng(),
        infecter_id::Int32 = Int32(-1), setting_id::Int32 = Int32(-1), lon::Float32 = NaN32,
        lat::Float32 = NaN32, setting_type::Char = '?', ags::Int32 = Int32(-1),
        source_infection_id::Int32 = DEFAULT_INFECTION_ID)

Infect `infectee` with the specified `pathogen` and calculate time to infectiousness
and time to recovery. Optional arguments `infecter_id`. `setting_id`, and `setting_type`
can be passed for logging. It's not required to calulate the infection. The infection
can only be logged, if `Simulation` object is passed (as this object holds the logger).

# Parameters

- `infectee::Individual`: Individual to infect
- `tick::Int16`: Infection tick
- `pathogen::Pathogen`: Pathogen to infect the individual with
- `sim::Simulation`: Simulation object (used to get logger and current tick)
- `sim::Union{Simulation, Nothing} = nothing` *(optional)* = Simulation object (used to get logger)
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
        rng::AbstractRNG = Random.default_rng(),
        infecter_id::Int32 = Int32(-1),
        setting_id::Int32 = Int32(-1),
        lon::Float32 = NaN32,
        lat::Float32 = NaN32,
        setting_type::Char = '?',
        ags::Int32 = Int32(-1),
        source_infection_id::Int32 = DEFAULT_INFECTION_ID)

    infectee.pathogen_id = id(pathogen)
    presymptomatic!(infectee) # sets the individual to be presymptomatic
    infectee.infectiousness = 0
    infectee.number_of_infections += 1
    infectee.exposed_tick = tick

    # calculate disease progression
    disease_progression!(infectee, pathogen, tick, rng=rng)

    if isnothing(sim)
        return -1
    end

    # log infection
    new_infection_id = log!(
        infectionlogger(sim),
        infecter_id,
        id(infectee),
        tick,
        infectee.infectious_tick,
        infectee.onset_of_symptoms,
        infectee.onset_of_severeness,
        infectee.hospitalized_tick,
        infectee.icu_tick,
        infectee.ventilation_tick,
        infectee.removed_tick,
        infectee.death_tick,
        infectee.symptom_category,
        setting_id,
        setting_type,
        lat,
        lon,
        ags,
        source_infection_id
    )

    # set the infectees current infection_id to the value that was returned by the logger
    infectee.infection_id = new_infection_id
    return new_infection_id
end

"""
    try_to_infect!(infctr::Individual, infctd::Individual, sim::Simulation, pathogen::Pathogen, setting::Setting;
        source_infection_id::Int32 = DEFAULT_INFECTION_ID)

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

    # Basic infection function. No vaccination or stratification
    if !infected(infctd) && !dead(infctd)
        infection_probability = transmission_probability(pathogen |> transmission_function, infctr, infctd, setting, sim |> tick, rng=sim.rng)

        if rand(sim.rng) < infection_probability
            infect!(infctd, tick(sim), pathogen,
                sim = sim,
                rng = sim.rng,
                infecter_id = id(infctr),
                setting_id = id(setting),
                lat = geolocation(settings(sim, Household)[household_id(infctd)], sim)[2],
                lon = geolocation(settings(sim, Household)[household_id(infctd)], sim)[1],
                setting_type = settingchar(setting),
                ags = ags(setting, sim) |> id,
                source_infection_id = source_infection_id)
            return true
        end
    end
    return false
end


"""
    update_individual!(indiv::Individual, tick::Int16, sim::Simulation)

Update the individual disease progression, handle its recovery and log its possible death.
If the individual is not infected, this function will just return.

# Parameters

- `indiv::Individual`: Individual to update
- `tick::Int16`: Current tick
- `sim::Simulation`: Simulation object
"""
function update_individual!(indiv::Individual, tick::Int16, sim::Simulation)

    # if the agent should be removed
    if infected(indiv) # make sure agents are really infected. If not, update the list

        progress_disease!(indiv, tick)

        # update from anywhere to death
        if death_tick(indiv)!=-1 && death_tick(indiv) <= tick && !dead(indiv)
            recover!(indiv)
            kill!(indiv)
            log!(deathlogger(sim), id(indiv), tick)
        end
    end

    # handle quarantining
    if isquarantined(indiv)
        if quarantine_release_tick(indiv) < tick
            end_quarantine!(indiv)
        end
    end

    # handle symptom triggers
    if symptomatic(indiv) && onset_of_symptoms(indiv) == tick
        for st in sim |> symptom_triggers
            trigger(st, indiv, sim)
        end
    end

    # handle hospitalization triggers
    if hospitalized(indiv) && hospitalized_tick(indiv) == tick
        for ht in sim |> hospitalization_triggers
            trigger(ht, indiv, sim)
        end
    end
end


"""
    spread_infection!(setting::Setting, sim::Simulation, pathogen::Pathogen)

Spreads the infection of `pathogen` inside the provided setting. This will simulate the
infection dynamics at the time `tick(sim)` inside `setting` within the context of the
simulation `sim`. This will also update all settings, the individual is part of, if the
infection is successful.

# Parameters

- `setting::Setting`: Setting in which the pathogen shall be spreaded
- `sim::Simulation`: Simulation object
- `pathogen::Pathogen`: Pathogen to spread

"""
function spread_infection!(setting::Setting, sim::Simulation, pathogen::Pathogen)
    num_infected = 0
    # Obtain individuals present in the current setting
    present_inds = present_individuals(setting, sim)
    # Check if the setting is open
    open = is_open(setting)
    for ind in present_inds
        if infected(ind)
            num_infected+=1
            # if infectious and setting is open try to infect others
            if infectious(ind) && open && (!isquarantined(ind) || ((quarantine_status(ind) == QUARANTINE_STATE_HOUSEHOLD_QUARANTINE) && (typeof(setting)==Household)))
                # sample contacts based on setting specific "ContactSamplingMethod"
                contacts = sample_contacts(setting.contact_sampling_method, setting, ind, present_inds, tick(sim), rng=sim.rng)
                for c in contacts
                    # try to infect
                    if !isquarantined(c) || ((quarantine_status(c) == QUARANTINE_STATE_HOUSEHOLD_QUARANTINE) && (typeof(setting)==Household))
                        if try_to_infect!(ind, c, sim, pathogen, setting, source_infection_id = infection_id(ind))
                            # activate all settings the individual is part of
                            for (type, id) in settings(c, sim)
                                activate!(settings(sim, type)[id])
                            end
                        end
                    end
                end
            end
        end
    end

    if num_infected == 0
        for ind in individuals(setting, sim)
            if infected(ind)
                num_infected+=1
            end
        end
        if num_infected == 0
            deactivate!(setting)
        end
    end
end