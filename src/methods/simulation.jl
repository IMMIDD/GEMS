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
    tot_quar_cnt = zeros(Int, Threads.maxthreadid())
    st_quar_cnt = zeros(Int, Threads.maxthreadid())
    st_isol_cnt = zeros(Int, Threads.maxthreadid())
    st_unab_cnt = zeros(Int, Threads.maxthreadid())
    wo_quar_cnt = zeros(Int, Threads.maxthreadid())
    wo_isol_cnt = zeros(Int, Threads.maxthreadid())
    wo_unab_cnt = zeros(Int, Threads.maxthreadid())
    exp_cnt = zeros(Int, Threads.maxthreadid())
    inf_cnt = zeros(Int, Threads.maxthreadid())
    dead_cnt = zeros(Int, Threads.maxthreadid())
    det_cnt = zeros(Int, Threads.maxthreadid())

    inds = simulation |> individuals
    chunk_size = max(1, length(inds) ÷ Threads.nthreads())
    
    Threads.@threads for chunk in collect(Iterators.partition(inds, chunk_size))
        tid = Threads.threadid()
        
        loc_tot_quar = 0; loc_st_quar = 0; loc_st_isol = 0; 
        loc_wo_quar = 0; loc_wo_isol = 0; loc_exp = 0; 
        loc_inf = 0; loc_dead = 0; loc_det = 0

        for i in chunk
            if isquarantined(i)
                loc_tot_quar += 1
                if is_student(i)
                    loc_st_quar += 1
                    if is_infected(i)
                        loc_st_isol += 1
                    end
                end
                if is_working(i)
                    loc_wo_quar += 1
                    if is_infected(i)
                        loc_wo_isol += 1
                    end
                end
            end

            loc_exp += is_exposed(i) ? 1 : 0
            loc_inf += is_infectious(i) ? 1 : 0
            loc_dead += is_dead(i) ? 1 : 0
            loc_det += is_detected(i) ? 1 : 0
        end

        @inbounds begin
            tot_quar_cnt[tid] += loc_tot_quar
            st_quar_cnt[tid] += loc_st_quar
            st_isol_cnt[tid] += loc_st_isol
            wo_quar_cnt[tid] += loc_wo_quar
            wo_isol_cnt[tid] += loc_wo_isol
            exp_cnt[tid] += loc_exp
            inf_cnt[tid] += loc_inf
            dead_cnt[tid] += loc_dead
            det_cnt[tid] += loc_det
        end
    end

    s_classes = schoolclasses(simulation)
    chunk_size_sc = max(1, length(s_classes) ÷ Threads.nthreads())
    
    Threads.@threads for chunk in collect(Iterators.partition(s_classes, chunk_size_sc))
        tid = Threads.threadid()
        loc_st_unab = 0
        
        for s in chunk
            if !is_open(s)
                loc_st_unab += size(s)
            else
                for i in individuals(s)
                    if is_severe(i) || is_hospitalized(i) || isquarantined(i)
                        loc_st_unab += 1
                    end
                end
            end
        end
        @inbounds st_unab_cnt[tid] += loc_st_unab
    end

    offs = offices(simulation)
    chunk_size_off = max(1, length(offs) ÷ Threads.nthreads())
    
    Threads.@threads for chunk in collect(Iterators.partition(offs, chunk_size_off))
        tid = Threads.threadid()
        loc_wo_unab = 0
        
        for o in chunk
            if !is_open(o)
                loc_wo_unab += size(o)
            else
                for i in individuals(o)
                    if is_severe(i) || is_hospitalized(i) || isquarantined(i)
                        loc_wo_unab += 1
                    end
                end
            end
        end
        @inbounds wo_unab_cnt[tid] += loc_wo_unab
    end

    log!(
        simulation |> quarantinelogger,
        simulation |> tick,
        sum(tot_quar_cnt),
        sum(st_quar_cnt),
        sum(wo_quar_cnt)
    )

    log!(simulation |> statelogger;
        tick = simulation |> tick,
        exposed = sum(exp_cnt),
        infectious = sum(inf_cnt),
        dead = sum(dead_cnt),
        detected = sum(det_cnt),
        quarantined = sum(tot_quar_cnt),
        quarantined_students = sum(st_quar_cnt),
        isolated_students = sum(st_isol_cnt),
        unable_to_attend_students = sum(st_unab_cnt),
        quarantined_workers = sum(wo_quar_cnt),
        isolated_workers = sum(wo_isol_cnt),
        unable_to_attend_workers = sum(wo_unab_cnt)
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
    tid = Threads.threadid()
    
    # fetch the last logged values from the logger
    last_exposed = isempty(sl.exposed[tid]) ? 0 : sl.exposed[tid][end]
    last_infectious = isempty(sl.infectious[tid]) ? 0 : sl.infectious[tid][end]
    last_dead = isempty(sl.dead[tid]) ? 0 : sl.dead[tid][end]
    last_detected = isempty(sl.detected[tid]) ? 0 : sl.detected[tid][end]
    last_quar = isempty(sl.quarantined[tid]) ? 0 : sl.quarantined[tid][end]
    last_quar_st = isempty(sl.quarantined_students[tid]) ? 0 : sl.quarantined_students[tid][end]
    last_isol_st = isempty(sl.isolated_students[tid]) ? 0 : sl.isolated_students[tid][end]
    last_unab_st = isempty(sl.unable_to_attend_students[tid]) ? 0 : sl.unable_to_attend_students[tid][end]
    last_quar_wo = isempty(sl.quarantined_workers[tid]) ? 0 : sl.quarantined_workers[tid][end]
    last_isol_wo = isempty(sl.isolated_workers[tid]) ? 0 : sl.isolated_workers[tid][end]
    last_unab_wo = isempty(sl.unable_to_attend_workers[tid]) ? 0 : sl.unable_to_attend_workers[tid][end]
    
    #@info "Steady state reached at tick $(tick(simulation)). Fast-forwarding remaining $remaining_ticks ticks..."
    
    for t in 1:remaining_ticks
        current_tick = tick(simulation)
        
        log!(ql, current_tick, last_quar, last_quar_st, last_quar_wo)
        log!(sl; tick=current_tick, exposed=last_exposed, infectious=last_infectious, dead=last_dead, detected=last_detected, quarantined=last_quar, quarantined_students=last_quar_st, isolated_students=last_isol_st, unable_to_attend_students=last_unab_st, quarantined_workers=last_quar_wo, isolated_workers=last_isol_wo, unable_to_attend_workers=last_unab_wo)
        
        fire_custom_loggers!(simulation)
        increment!(simulation)
    end
end

"""
    check_and_fast_forward!(simulation::Simulation)

Checks if the pandemic has reached a steady state (zero active cases and quarantines).
If so, and there are no future interventions, it executes the fast-forward and returns `true`.
Otherwise, it returns `false`.
"""
function check_and_fast_forward!(simulation::Simulation)
    sl = statelogger(simulation)
    tid = Threads.threadid()
    
    # Check the most recently pushed values
    cur_exp = isempty(sl.exposed[tid]) ? 0 : sl.exposed[tid][end]
    cur_inf = isempty(sl.infectious[tid]) ? 0 : sl.infectious[tid][end]
    cur_quar = isempty(sl.quarantined[tid]) ? 0 : sl.quarantined[tid][end]
    
    if cur_exp == 0 && cur_inf == 0 && cur_quar == 0
        if !has_future_interventions(simulation)
            fast_forward!(simulation)
            return true
        end
    end
    
    return false
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
            
            fast_forwarded = check_and_fast_forward!(simulation)
        end
    else
        # while the simulation's stop criterion is not met, perform next step
        while !evaluate(simulation, stop_criterion(simulation))

            # Print current tick
            @info "\r  \u2514 Currently simulating $(simulation |> tickunit): $(tick(simulation) + 1)"
            step!(simulation)
            
            if isa(stop_criterion(simulation), TimesUp)
                check_and_fast_forward!(simulation)
            end
        end
        println()
    end

    return(simulation)
end
