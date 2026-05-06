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
    
    Threads.@threads :static for chunk in collect(Iterators.partition(inds, chunk_size))
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
    
    Threads.@threads :static for chunk in collect(Iterators.partition(s_classes, chunk_size_sc))
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
    
    Threads.@threads :static for chunk in collect(Iterators.partition(offs, chunk_size_off))
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
    copy_last_log_state(simulation::Simulation)

Fills the loggers for the current dormant tick by copying the last known state.
"""
function copy_last_log_state(simulation::Simulation)
    sl = statelogger(simulation)
    ql = quarantinelogger(simulation)
    
    # Get last known state
    last_exposed = isempty(sl.exposed) ? 0 : sl.exposed[end]
    last_infectious = isempty(sl.infectious) ? 0 : sl.infectious[end]
    last_dead = isempty(sl.dead) ? 0 : sl.dead[end]
    last_detected = isempty(sl.detected) ? 0 : sl.detected[end]
    
    last_quar = isempty(sl.quarantined) ? 0 : sl.quarantined[end]
    last_quar_st = isempty(sl.quarantined_students) ? 0 : sl.quarantined_students[end]
    last_isol_st = isempty(sl.isolated_students) ? 0 : sl.isolated_students[end]
    last_unab_st = isempty(sl.unable_to_attend_students) ? 0 : sl.unable_to_attend_students[end]
    
    last_quar_wo = isempty(sl.quarantined_workers) ? 0 : sl.quarantined_workers[end]
    last_isol_wo = isempty(sl.isolated_workers) ? 0 : sl.isolated_workers[end]
    last_unab_wo = isempty(sl.unable_to_attend_workers) ? 0 : sl.unable_to_attend_workers[end]
    
    current_tick = tick(simulation)
    
    # Log the copied state for the current tick
    log!(ql, current_tick, last_quar, last_quar_st, last_quar_wo)
    log!(sl; tick=current_tick, exposed=last_exposed, infectious=last_infectious, dead=last_dead, 
         detected=last_detected, quarantined=last_quar, quarantined_students=last_quar_st, 
         isolated_students=last_isol_st, unable_to_attend_students=last_unab_st, 
         quarantined_workers=last_quar_wo, isolated_workers=last_isol_wo, 
         unable_to_attend_workers=last_unab_wo)             
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
    dormant = is_dormant(simulation)

    # update disease state
    if !dormant
        Threads.@threads :static for i in simulation |> population |> individuals
            update_individual!(i, tick(simulation), simulation)
        end
        flush_ended_infections!(simulation)
    end

    # infect individuals in settings
    if !dormant
        for type in settingtypes_sorted(settingscontainer(simulation))
            Threads.@threads :static for stng in settings(simulation, type)
                if isactive(stng)
                    spread_infection!(stng, simulation)
                end
            end
        end

        # push pending infections to InfectionRegistry
        flush_pending_infections!(simulation)
    end

    # trigger tick triggers
    for tt in simulation |> tick_triggers
        if should_fire(tt, tick(simulation))
            trigger(tt, simulation)
        end
    end

    process_events!(simulation)

    # update quarantine state
    if !dormant
        Threads.@threads :static for i in simulation |> population |> individuals
            quarantined!(i, is_quarantined(i, tick(simulation)))
        end
    end

    if !dormant
        log_stepinfo(simulation)
    else
        copy_last_log_state(simulation)
    end

    # fire custom loggers
    fire_custom_loggers!(simulation)

    # fire custom step modification funtion
    simulation.stepmod(simulation)

    increment!(simulation)
end

"""
    is_dormant(simulation::Simulation)

Checks if the simulation can be safely fast-forwarded. 
Returns `false` if there is active disease, active quarantines, or any events/triggers scheduled for today.
"""
function is_dormant(simulation::Simulation)
    current_t = tick(simulation)

    # wake up if an event is scheduled for today (or was missed)
    if !isempty(simulation.event_queue) && first(simulation.event_queue)[2] <= current_t
        return false 
    end

    # wake up if a trigger fires today
    for tt in simulation.tick_triggers
        if should_fire(tt, current_t)
            return false 
        end
    end

    # wake up if disease or quarantines are active
    sl = statelogger(simulation)
    
    if isempty(sl.exposed)
        return false
    end
    
    cur_exp = sl.exposed[end]
    cur_inf = sl.infectious[end]
    cur_quar = sl.quarantined[end]
    
    return cur_exp == 0 && cur_inf == 0 && cur_quar == 0
end

"""
    push_immunity_to_individual!(ind::Individual, registry::ImmunityRegistry, host_id::Int32, pathogen_id::Int8, source::Int8, acquired_tick::Int16, vaccine_id::Int8)
 
Cache-first immunity write. Used by flush_pending_infections! and vaccinate!.
"""
function push_immunity_to_individual!(
    ind::Individual,
    registry::ImmunityRegistry,
    host_id::Int32,
    pathogen_id::Int8,
    source::Int8,
    acquired_tick::Int16,
    vaccine_id::Int8
)
    # Update existing cache entry for this pathogen
    @inbounds for i in 1:IMMUNITY_CACHE_SIZE
        s = ind.immunity_cache[i]
        _is_active_immunity(s) && s.pathogen_id == pathogen_id || continue
        ind.immunity_cache = Base.setindex(ind.immunity_cache,
            if source == IMMUNITY_SOURCE_NATURAL
                ImmunityState(Int32(0), acquired_tick, s.vaccine_acquired_tick, s.immunity_level, pathogen_id, s.vaccine_id, s.dose_number)
            else
                ImmunityState(Int32(0), s.natural_acquired_tick, acquired_tick, s.immunity_level, pathogen_id, vaccine_id, s.dose_number + Int8(1))
            end, i)
        return nothing
    end
 
    # Free cache slot
    @inbounds for i in 1:IMMUNITY_CACHE_SIZE
        s = ind.immunity_cache[i]
        _is_active_immunity(s) && continue
        ind.immunity_cache = Base.setindex(ind.immunity_cache,
            if source == IMMUNITY_SOURCE_NATURAL
                ImmunityState(Int32(0), acquired_tick, DEFAULT_TICK, Int8(0), pathogen_id, DEFAULT_VACCINE_ID, Int8(0))
            else
                ImmunityState(Int32(0), DEFAULT_TICK, acquired_tick, Int8(0), pathogen_id, vaccine_id, Int8(1))
            end, i)
        return nothing
    end
 
    # Cache full: write to overflow registry
    push_immunity!(registry, host_id, pathogen_id, source, acquired_tick, vaccine_id)
    ind.immunity_overflow = true
    return nothing
end


"""
    flush_pending_infections!(sim::Simulation)
 
Drains every `PendingInfection` staged in `sim.infection_buffers` into `sim.infection_registry`. 
Empties each buffer when done.
"""
function flush_pending_infections!(sim::Simulation)
    infections = infection_registry(sim)
    immunities = immunity_registry(sim)
    pop = population(sim)
 
    @inbounds for buf in sim.infection_buffers
        for p in buf
            ind = get_individual_by_id(pop, p.host_id)
            full_state = _state_from_pending(p.pathogen_id, p.infection_id, p.dp)
 
            placed = false
            @inbounds for i in 1:INFECTIONS_CACHE_SIZE
                if ind.claimed_pathogens[i] == p.pathogen_id && !ind.infection_cache[i].active
                    ind.infection_cache = Base.setindex(ind.infection_cache, full_state, i)
                    placed = true
                    ind.claimed_pathogens = Base.setindex(ind.claimed_pathogens, Int8(0), i)
                    break
                end
            end
 
            if !placed
                # claim_active_slot! set infection_overflow; write to registry now
                _push_overflow!(infections, p.host_id, full_state)
            end
 
            if p.dp.recovery >= 0
                push_immunity_to_individual!(ind, immunities, p.host_id, p.pathogen_id, IMMUNITY_SOURCE_NATURAL, p.dp.recovery, DEFAULT_VACCINE_ID)
                ind.needs_immunity_update = true
            end
        end
        empty!(buf)
    end
    return nothing
end

"""
    _promote_overflow_to_cache!(ind::Individual, reg::InfectionRegistry, cache_slot::Int32)
 
Moves the first overflow node into a freed cache slot.
"""
@inline function _promote_overflow_to_cache!(ind::Individual, reg::InfectionRegistry, cache_slot::Int32)
    head_idx = reg.head[ind.id]
    head_idx == 0 && (ind.infection_overflow = false; return nothing)
 
    @inbounds promoted = reg.states[head_idx]
    # Promote: clear the next chain pointer for the cache state
    ind.infection_cache = Base.setindex(ind.infection_cache, _setstate(promoted, Val(:next), Int32(0)), Int(cache_slot))
 
    reg.head[ind.id] = promoted.next
    push!(reg.free_slots, head_idx)
 
    reg.head[ind.id] == 0 && (ind.infection_overflow = false)
    return nothing
end



"""
    flush_ended_infections!(sim)
 
Drains `removal_buffers` after the threaded update phase: clears `slot_to_row`
entries for infections that ended during this tick and returns their indices to
the free list so they can be reused.
"""
function flush_ended_infections!(sim::Simulation)
    reg = infection_registry(sim)
    pop = population(sim)
 
    @inbounds for buf in sim.removal_buffers
        for (host_id, val) in buf
            ind = get_individual_by_id(pop, host_id)
            if val < 0
                # Freed cache slot
                if ind.infection_overflow
                    _promote_overflow_to_cache!(ind, reg, Int32(-val))
                end
            else
                # Ended overflow node 
                _remove_overflow_node!(reg, host_id, Int32(val))
                if reg.head[host_id] == 0
                    ind.infection_overflow = false
                end
            end
        end
        empty!(buf)
    end
    return nothing
end






# MAIN LOOP
"""
    run!(simulation::Simulation; with_progressbar::Bool = true)

Takes and initializes Simulation object and calls the stepping 
function (step!) until the stop criterion is met.

# Returns

- `Simulation`: Simulation object
"""
function run!(simulation::Simulation; with_progressbar::Bool = true)
    printinfo("Running Simulation $(label(simulation))")

    sc = stop_criterion(simulation)
    
    # check if a limit exists
    has_time_limit = applicable(limit, sc) && !isnothing(limit(sc))

    # define iterator
    if with_progressbar && has_time_limit
        iter = ProgressBar(tick(simulation) : limit(sc) - 1, unit=" $(tickunit(simulation))s")
    else
        iter = Iterators.countfrom(1)
    end

    for _ in iter
        if evaluate(simulation, sc)
            break
        end

        # The unified step! handles both active and dormant states
        step!(simulation)

        if !has_time_limit 
            @info "\r  \u2514 Currently simulating $(tickunit(simulation)): $(tick(simulation))"
        end
    end

    println()
    return simulation
end
