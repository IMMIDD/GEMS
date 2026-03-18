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
    sl = statelogger(simulation)
    
    # Zero out buffers to prevent array allocation
    fill!(sl.tot_quar_cnt_buf, 0)
    fill!(sl.st_quar_cnt_buf, 0)
    fill!(sl.st_isol_cnt_buf, 0)
    fill!(sl.st_unab_cnt_buf, 0)
    fill!(sl.wo_quar_cnt_buf, 0)
    fill!(sl.wo_isol_cnt_buf, 0)
    fill!(sl.wo_unab_cnt_buf, 0)
    fill!(sl.exp_cnt_buf, 0)
    fill!(sl.inf_cnt_buf, 0)
    fill!(sl.dead_cnt_buf, 0)
    fill!(sl.det_cnt_buf, 0)
    
    # Fast cache lookups for closed settings
    closed_schools = Set{Int32}()
    for s in schoolclasses(simulation)
        if !is_open(s)
            push!(closed_schools, id(s))
        end
    end
    
    closed_offices = Set{Int32}()
    for o in offices(simulation)
        if !is_open(o)
            push!(closed_offices, id(o))
        end
    end
    
    
    Threads.@threads for i in simulation |> individuals
        tid = Threads.threadid()
        
        quar = isquarantined(i)
        inf = is_infected(i)
        
        # log quarantined individuals
        if quar
            sl.tot_quar_cnt_buf[tid] += 1
            if is_student(i)
                sl.st_quar_cnt_buf[tid] += 1
                if inf
                    sl.st_isol_cnt_buf[tid] += 1
                end
            end
            if is_working(i)
                sl.wo_quar_cnt_buf[tid] += 1
                if inf
                    sl.wo_isol_cnt_buf[tid] += 1
                end
            end
        end
        
        # log infected individuals
        sl.exp_cnt_buf[tid] += is_exposed(i) ? 1 : 0
        sl.inf_cnt_buf[tid] += is_infectious(i) ? 1 : 0
        sl.dead_cnt_buf[tid] += is_dead(i) ? 1 : 0
        sl.det_cnt_buf[tid] += is_detected(i) ? 1 : 0
        
        # calculate unable to attend by checking closed sets & health state directly 
        if is_student(i)
            if class_id(i) in closed_schools || is_severe(i) || is_hospitalized(i) || quar
                sl.st_unab_cnt_buf[tid] += 1
            end
        end
        
        if is_working(i)
            if office_id(i) in closed_offices || is_severe(i) || is_hospitalized(i) || quar
                sl.wo_unab_cnt_buf[tid] += 1
            end
        end
    end

    # log quarantine data
    log!(
        simulation |> quarantinelogger, 
        simulation |> tick, 
        sum(sl.tot_quar_cnt_buf), 
        sum(sl.st_quar_cnt_buf), 
        sum(sl.wo_quar_cnt_buf)
    )

    # log infection data
    log!(sl;
        tick = simulation |> tick,
        exposed = sum(sl.exp_cnt_buf),
        infectious = sum(sl.inf_cnt_buf),
        dead = sum(sl.dead_cnt_buf),
        detected = sum(sl.det_cnt_buf),
        quarantined = sum(sl.tot_quar_cnt_buf),
        quarantined_students = sum(sl.st_quar_cnt_buf),
        isolated_students = sum(sl.st_isol_cnt_buf),
        unable_to_attend_students = sum(sl.st_unab_cnt_buf),
        quarantined_workers = sum(sl.wo_quar_cnt_buf),
        isolated_workers = sum(sl.wo_isol_cnt_buf),
        unable_to_attend_workers = sum(sl.wo_unab_cnt_buf)
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
    # update disease state
    Threads.@threads :static for i in simulation |> population |> individuals
        update_individual!(i, tick(simulation), simulation)
    end

    # infect individuals in settings
    for type in settingtypes_sorted(settingscontainer(simulation))
        Threads.@threads :static for stng in settings(simulation, type)
            if isactive(stng)
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

    # update quarantine state
    Threads.@threads :static for i in simulation |> population |> individuals
        quarantined!(i, is_quarantined(i, tick(simulation)))
    end

    log_stepinfo(simulation)
    
    # fire custom loggers
    fire_custom_loggers!(simulation)

    # fire custom step modification funtion
    simulation.stepmod(simulation)

    increment!(simulation)
end

"""
    has_future_interventions(sim::Simulation)

Determines if there are delayed or scheduled interventions still active in the simulation.
"""
function has_future_interventions(sim::Simulation)
    !isempty(sim.event_queue) && return true
    
    for t in sim.tick_triggers
        if interval(t) > 0 || switch_tick(t) > tick(sim)
            return true
        end
    end
    
    return false
end

"""
    fast_forward!(simulation::Simulation)

Instantly completes the simulation if the pandemic is over by duplicating
the logger state to match the end date limit, thereby saving computation time.
"""
function fast_forward!(simulation::Simulation)
    sc = stop_criterion(simulation)
    if !isa(sc, TimesUp)
        return
    end
    
    remaining_ticks = limit(sc) - tick(simulation)
    if remaining_ticks <= 0
        return
    end
    
    sl = statelogger(simulation)
    ql = quarantinelogger(simulation)
    
    last_exposed = sum(sl.exp_cnt_buf)
    last_infectious = sum(sl.inf_cnt_buf)
    last_dead = sum(sl.dead_cnt_buf)
    last_detected = sum(sl.det_cnt_buf)
    last_quar = sum(sl.tot_quar_cnt_buf)
    last_quar_st = sum(sl.st_quar_cnt_buf)
    last_isol_st = sum(sl.st_isol_cnt_buf)
    last_unab_st = sum(sl.st_unab_cnt_buf)
    last_quar_wo = sum(sl.wo_quar_cnt_buf)
    last_isol_wo = sum(sl.wo_isol_cnt_buf)
    last_unab_wo = sum(sl.wo_unab_cnt_buf)
    
    #@info "Steady state reached at tick $(tick(simulation)). Fast-forwarding remaining $remaining_ticks ticks..."
    
    for t in 1:remaining_ticks
        current_tick = tick(simulation)
        
        log!(ql, current_tick, last_quar, last_quar_st, last_quar_wo)
        log!(sl; tick=current_tick, exposed=last_exposed, infectious=last_infectious, dead=last_dead, detected=last_detected, quarantined=last_quar, quarantined_students=last_quar_st, isolated_students=last_isol_st, unable_to_attend_students=last_unab_st, quarantined_workers=last_quar_wo, isolated_workers=last_isol_wo, unable_to_attend_workers=last_unab_wo)
        
        fire_custom_loggers!(simulation)
        increment!(simulation)
    end
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

        fast_forwarded = false

        # Progressbar for the simulation if time limit is set
        for i in ProgressBar((simulation |> tick) : (simulation |> stop_criterion |> limit) - 1, unit= " $(simulation |> tickunit)s")

            if fast_forwarded
                continue
            end

            step!(simulation)
            
            sl = statelogger(simulation)
            if sum(sl.exp_cnt_buf) == 0 && sum(sl.inf_cnt_buf) == 0 && sum(sl.tot_quar_cnt_buf) == 0
                if !has_future_interventions(simulation)
                    fast_forward!(simulation)
                    fast_forwarded = true
                end
            end
        end
    else
        # while the simulation's stop criterion is not met, perform next step
        while !evaluate(simulation, stop_criterion(simulation))

            # Print current tick
            @info "\r  \u2514 Currently simulating $(simulation |> tickunit): $(tick(simulation) + 1)"
            step!(simulation)
            
            if isa(stop_criterion(simulation), TimesUp)
                sl = statelogger(simulation)
                if sum(sl.exp_cnt_buf) == 0 && sum(sl.inf_cnt_buf) == 0 && sum(sl.tot_quar_cnt_buf) == 0
                    if !has_future_interventions(simulation)
                        fast_forward!(simulation)
                        break
                    end
                end
            end
        end
        println()
    end

    return(simulation)
end
