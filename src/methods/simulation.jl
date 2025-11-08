#=
THIS FILE HANDLES THE FUNCTIONALITY TO RUN THE SIMULATION
Basic functionality is included in structs/simulation.jl. This file
is mostly comprised of the step! and run! function as well as functionality
that is dependent on other structs, so it has to be loaded later.
=#
### EXPORTS
export step!, run!
export fire_custom_loggers!

###
### RUN SIMULATION
###

"""
    process_events!(simulation::Simulation)

Executes the `process_measure` function for all measures in the 
simulation's `EventQueue` for the current tick.
"""
function process_events!(simulation::Simulation)

    while !isempty(simulation |> event_queue) &&
        first(simulation |> event_queue)[2] <= simulation |> tick

        simulation |> event_queue |> dequeue! |>
            x -> process_event(x, simulation)
    end
end

"""
    log_quarantines(simulation::Simulation)

Log all current quarantines stratified by occupation (workers, students, all)
to the simulation's `QuarantineLogger`.
"""
function log_quarantines(simulation::Simulation)

    # Julia 1.12-safe threaded counting with atomic integers
    tot = Threads.Atomic{Int}(0)
    st  = Threads.Atomic{Int}(0)
    wo  = Threads.Atomic{Int}(0)

    Threads.@threads for i in simulation |> individuals
        if isquarantined(i)
            Threads.atomic_add!(tot, 1)
            Threads.atomic_add!(st,  is_student(i) ? 1 : 0)
            Threads.atomic_add!(wo,  is_working(i) ? 1 : 0)
        end
    end

    log!(
        simulation |> quarantinelogger,
        simulation |> tick,
        tot[], st[], wo[]
    )
end

"""
    fire_custom_loggers!(sim::Simulation)

Executes all custom functions that are stored in the `CustomLogger`
on the `Simulation` object and stores them in the internal dataframe.
"""
function fire_custom_loggers!(sim::Simulation)
    cl = customlogger(sim)
    # run each registered function on the sim object and push the results to the internal dataframe
    # only log something "tick" is not the only "custom" function
    hasfuncs(cl) ? push!(cl.data, [cl.funcs[Symbol(col)](sim) for col in names(cl.data)]) : nothing
end


### Incidence access functions
"""
    incidence(simulation::Simulation, pathogen::Pathogen, base_size::Int = 100_000, duration::Int16 = Int16(7))

Returns the incidence at a particular pathogen and a point in time (current simulation tick).
The `duration` defines a time-span for which the incidence is measured (default: 7 ticks).
The `base_size` provides the population size reference (default: 100_000 individuals)

# Parameters

- `simulation::Simulation`: Simulation object
- `pathogen::Pathogen`: Pathogen for which the incidence shall be calculated
- `base_size::Int = 100_000` *(optional)*: Reference popuation size for incidence calculation
- `duration::Int16 = Int16(7)` *(optional)*: Reference duration (in ticks) for the incidence calculation

# Returns

- `Float64`: Incidence

"""
function incidence(simulation::Simulation, pathogen::Pathogen, base_size::Int = 100_000, duration::Int16 = Int16(7))
    
    return(
        # count number of infection events from (now - duration) until (now) and divide it by (population_size / base_size)
        (simulation |> infectionlogger |> ticks |>
            x -> count(y -> tick(simulation) - duration <= y <= tick(simulation), x))
            /
        ((simulation |> population |> Base.size) / base_size)
    )
end


"""
    incidence(simulation::Simulation, base_size::Int = 100_000, duration::Int16 = Int16(7))

Returns the incidence at a particular point in time (current simulation tick).
NOTE: This will only work for the single-pathogen version. 
The `duration` defines a time-span for which the incidence is measured (default: 7 ticks).
The `base_size` provides the population size reference (default: 100_000 individuals)

# Parameters

- `simulation::Simulation`: Simulation object
- `base_size::Int = 100_000` *(optional)*: Reference popuation size for incidence calculation
- `duration::Int16 = Int16(7)` *(optional)*: Reference duration (in ticks) for the incidence calculation

# Returns

- `Float64`: Incidence
"""
function incidence(simulation::Simulation, base_size::Int = 100_000, duration::Int16 = Int16(7))
    return(incidence(simulation, simulation |> pathogen, base_size, duration))
end




# RUN STEP
"""
    step!(simulation::Simulation)

Increments the simulation status by one tick and executes all events that shall be handled during this tick.
"""
function step!(simulation::Simulation)
    # create newborns
    process_births!(simulation)

    # update individuals
    Threads.@threads :static for i in simulation |> population |> individuals
        update_individual!(i, tick(simulation), simulation)
    end

    # infect individuals in settings
    for type in settingtypes(settingscontainer(simulation))
        Threads.@threads :static for stng in settings(simulation, type)
            if stng.isactive
                spread_infection!(stng, simulation, pathogen(simulation))
            end
        end
    end

    # trigger tick triggers
    for tt in simulation |> tick_triggers
        if should_fire(tt, tick(simulation))
            trigger(tt, simulation)
        end
    end

    process_events!(simulation)
    log_quarantines(simulation)
    
    # fire custom loggers
    fire_custom_loggers!(simulation)

    # fire custom step modification funtion
    simulation.stepmod(simulation)

    increment!(simulation)
end

# MAIN LOOP
"""
    run!(simulation::Simulation; with_progressbar::Bool = true)

Takes and initializes Simulation object and calls the stepping function (step!) until the stop criterion is met.

# Returns

- `Simulation`: Simulation object
"""
function run!(simulation::Simulation; with_progressbar::Bool = true)
    
    printinfo("Running Simulation $(label(simulation))")

    # Use a progressbar for the most common stop criterion
    if with_progressbar && isa(stop_criterion(simulation), TimesUp)

        # Progressbar for the simulation if time limit is set
        for i in ProgressBar((simulation |> tick) : (simulation |> stop_criterion |> limit) - 1, unit= " $(simulation |> tickunit)s")
            step!(simulation)
        end
    else
        # while the simulation's stop criterion is not met, perform next step
        while !evaluate(simulation, stop_criterion(simulation))

            # Print current tick
            @info "\r  \u2514 Currently simulating $(simulation |> tickunit): $(tick(simulation) + 1)"
            step!(simulation)
        end
        println()
    end

    return(simulation)
end


"""
    process_births!(sim::Simulation)

Adds new individuals (births) to the population based on a BirthModel.
"""
function process_births!(sim::Simulation)
    num_births = get_births_for_tick(sim.birth_model, sim)

    if num_births == 0 return end

    pop = population(sim)
    
    # get the highest existing individual ID to ensure new IDs are unique
    max_id = maximum(i -> id(i), individuals(pop))

    for i in 1:num_births
        # select mother
        mother = select_random_mother(sim)

        target_household = households(sim)[household_id(mother)]
        target_municipality = municipalities(sim)[municipality_id(mother)]

        # create newborn
        new_id = max_id + i
        newborn = Individual(
            id = new_id,
            sex = rand(1:2),
            birthday = sim.startdate + Day(tick(sim)),
            mother_id = mother
        )

        setting_id!(newborn, Household, id(target_household))
        setting_id!(newborn, Municipality, id(target_municipality))

        add!(pop, newborn)
        add!(target_household, newborn)
        add!(target_municipality, newborn)
    end
end