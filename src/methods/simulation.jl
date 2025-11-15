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
    log_stepinfo(simulation::Simulation)

Log all current quarantines stratified by occupation (workers, students, all)
to the simulation's `QuarantineLogger`.

"""
function log_stepinfo(simulation::Simulation)
    
    # Julia 1.12-safe threaded counting with atomic integers
    
    # quarantine data
    # set up one vector with one entry for each thread
    tot_cnt = Threads.Atomic{Int}(0)
    st_cnt  = Threads.Atomic{Int}(0)
    wo_cnt  = Threads.Atomic{Int}(0)

    # infection data
    exp_cnt = Threads.Atomic{Int}(0)
    inf_cnt = Threads.Atomic{Int}(0)
    dead_cnt = Threads.Atomic{Int}(0)
    det_cnt = Threads.Atomic{Int}(0)

    Threads.@threads for i in simulation |> individuals
        # log quarantined individuals
        if isquarantined(i)
            Threads.atomic_add!(tot_cnt, 1)
            Threads.atomic_add!(st_cnt, is_student(i) ? 1 : 0)
            Threads.atomic_add!(wo_cnt, is_working(i) ? 1 : 0)
        end

        # log infected individuals
        Threads.atomic_add!(exp_cnt, is_exposed(i) ? 1 : 0)
        Threads.atomic_add!(inf_cnt, is_infectious(i) ? 1 : 0)
        Threads.atomic_add!(dead_cnt, is_dead(i) ? 1 : 0)
        Threads.atomic_add!(det_cnt, is_detected(i) ? 1 : 0)
    end

    # log quarantine data
    log!(
        simulation |> quarantinelogger,
        simulation |> tick,
        tot_cnt[],
        st_cnt[],
        wo_cnt[]
    )

    # log infection data
    log!(
        simulation |> statelogger,
        simulation |> tick,
        exp_cnt[],
        inf_cnt[],
        dead_cnt[],
        det_cnt[]
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
    log_stepinfo(simulation)
    
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
