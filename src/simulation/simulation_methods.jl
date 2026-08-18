#=
THIS FILE HANDLES THE FUNCTIONALITY TO RUN THE SIMULATION
Basic functionality is included in simulation/simulation.jl. This file
is mostly comprised of the step! and run! function as well as functionality
that is dependent on other structs, so it has to be loaded later.
=#
### EXPORTS
export step!, run!
export is_disease_active

###
### RUN SIMULATION
###

"""
    process_events!(simulation::Simulation)

Executes the `process_measure` function for all measures in the 
simulation's `EventQueue` for the current tick.
"""
function process_events!(simulation::Simulation)
    process_due!(event_queue(simulation), simulation, tick(simulation))
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
- `base_size::Int = 100_000` *(optional)*: Reference population size for incidence calculation
- `duration::Int16 = Int16(7)` *(optional)*: Reference duration (in ticks) for the incidence calculation

# Returns

- `Float64`: Incidence
"""
function incidence(simulation::Simulation, pathogen::Pathogen, base_size::Int = 100_000, duration::Int16 = Int16(7))
    logger = infectionlogger(simulation)
    current_tick = tick(simulation)
    start_tick = current_tick - duration
    
    target_pathogen_id = pathogen.id
    infection_count = 0
    
    # Iterate through each thread's log buffers
    for tid in 1:Threads.maxthreadid()
        ticks_tid = logger.tick[tid]
        pids_tid = logger.pathogen_id[tid]
        
        for i in length(ticks_tid):-1:1
            t = ticks_tid[i]     
            t < start_tick && break 
            
            if t <= current_tick && pids_tid[i] == target_pathogen_id
                infection_count += 1
            end
        end
    end
    
    pop_size = Base.size(population(simulation))
    
    return (infection_count / (pop_size / base_size))
end

"""
    incidence(simulation::Simulation, pathogen_id::Int8, base_size::Int = 100_000, duration::Int16 = Int16(7))

Convenience wrapper to calculate incidence using a pathogen ID.
"""
function incidence(simulation::Simulation, pathogen_id::Int8, base_size::Int = 100_000, duration::Int16 = Int16(7))
    return incidence(simulation, get_pathogen(simulation, pathogen_id), base_size, duration)
end

"""
    incidence(simulation::Simulation, pathogen_name::String, base_size::Int = 100_000, duration::Int16 = Int16(7))

Convenience wrapper to calculate incidence using a pathogen name.
"""
function incidence(simulation::Simulation, pathogen_name::String, base_size::Int = 100_000, duration::Int16 = Int16(7))
    return incidence(simulation, get_pathogen(simulation, pathogen_name), base_size, duration)
end




# RECURRING SEEDING

"""
    seed_scheduled!(simulation::Simulation)

Executes the imports staged for the current tick in `simulation.seeding_schedule` (a
`Dict` keyed by tick). Called at the top of `step!`, before transmission, so imported
cases can spread the same tick. `O(1)` when nothing is due today.
"""
function seed_scheduled!(simulation::Simulation)
    specs = get(simulation.seeding_schedule, tick(simulation), nothing)
    isnothing(specs) && return nothing
    r = rng(simulation)
    for spec in specs
        _seed_infection!(simulation, spec, r)
    end
    flush_pending_infections!(simulation)
    return nothing
end

# An import can only land on a host that is alive, not in hospital, and not already carrying the
# pathogen. Seeding runs before the individual loop, so a host due to die at `t` still looks alive.
@inline _can_be_seeded(individual::Individual, pathogen_id::Int8, t::Int16) =
    !dead(individual) && !(Int16(0) <= individual.death <= t) &&
    !hospitalized(individual) && !infected(individual, pathogen_id)

"""
    _seed_infection!(simulation, spec::InfectionSeed, rng)

Samples and infects the individuals described by `spec` at the current tick, drawing from
the whole population (`spec.ags === nothing`) or from the region otherwise.
"""
function _seed_infection!(simulation::Simulation, spec::InfectionSeed, rng::Xoshiro)
    spec.count <= 0 && return nothing
    pthgn = get_pathogen(simulation, spec.pathogen)
    pid = id(pthgn)
    t = tick(simulation)

    pool = isnothing(spec.ags) ? individuals(simulation) : individuals_in_ags(simulation, AGS(spec.ags))

    # reservoir sampling: one pass over the pool, holding a uniform sample of `spec.count` of the eligible hosts seen so far
    picked = sizehint!(Individual[], spec.count)
    seen = 0
    for i in pool
        _can_be_seeded(i, pid, t) || continue
        seen += 1
        if seen <= spec.count
            push!(picked, i)
        else
            # the seen-th host takes a random slot with probability count/seen
            j = gems_rand(rng, 1:seen)
            j <= spec.count && (picked[j] = i)
        end
    end

    for i in picked
        infect!(i, t, pthgn, sim = simulation, rng = rng)
        activate_memberships!(i, simulation)
    end
    return nothing
end


# RUN STEP

"""
    step!(simulation::Simulation)

Increments the simulation status by one tick and executes all events that shall be handled during this tick.
"""
function step!(simulation::Simulation)
    dormant = is_dormant(simulation)

    # realize scheduled care before anything reads hospitalization state. Unconditional, so a
    # mis-judged dormant tick cannot strand a host mid-episode; dormancy makes it a no-op anyway
    drain_health_schedule!(simulation)

    # seed scheduled imports before transmission so a fresh import can spread this tick
    seed_scheduled!(simulation)

    # update disease state
    if !dormant
        Threads.@threads :static for i in simulation |> population |> individuals
            update_individual!(i, tick(simulation), simulation)
        end
        flush_ended_infections!(simulation)
    end

    # after the individual loop, so trigger conditions see this tick's disease flags
    fire_hospitalization_triggers!(simulation)
    # merge per-thread staged trigger events into the queue before processing
    flush_staging!(event_queue(simulation))

    # infect individuals in settings
    if !dormant
        foreach_setting_vector(settingscontainer(simulation)) do stngs
            Threads.@threads :static for stng in stngs
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
        if should_fire(tt, simulation)
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
    eq = event_queue(simulation)
    if !isempty(eq) && peektick(eq) <= current_t
        return false
    end

    # wake up if a trigger fires today
    for tt in simulation.tick_triggers
        if should_fire(tt, simulation)
            return false
        end
    end

    # wake up if a scheduled import seeds today
    if haskey(simulation.seeding_schedule, current_t)
        return false
    end
    
    # wake up if a care transition or a death is due today. Deliberately not an "anything outstanding"
    # test, which would hold the simulation awake up to the last scheduled event
    if any(s -> due_now(s, current_t), simulation.health_schedules)
        return false
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
    is_disease_active(simulation::Simulation)

Returns `true` if there is currently active disease transmission (i.e. any
individuals exposed or infectious), `false` otherwise. Intended for use as a
tick-trigger `condition`, so that interventions stop re-firing once the
disease has died out, allowing `is_dormant` to fast-forward the simulation
again.
"""
function is_disease_active(simulation::Simulation)::Bool
    sl = statelogger(simulation)
    isempty(sl.exposed) && return true
    return sl.exposed[end] > 0 || sl.infectious[end] > 0
end



"""
    flush_pending_infections!(sim::Simulation)
 
Drains every `_PendingInfection` staged in `sim.infection_buffers` into `sim.infection_registry`.
Empties each buffer when done.
"""
function flush_pending_infections!(sim::Simulation)
    pop = population(sim)
    num_shards = Threads.maxthreadid()
 
    Threads.@threads :static for shard_id in 1:num_shards
        infections = sim.infection_registries[shard_id]

        # drain all buffers destined for this shard
        @inbounds for producer_id in 1:num_shards
            buf = sim.infection_buffers[producer_id, shard_id]
            for p in buf
                ind = get_individual_by_id(pop, p.host_id)
                state = push_infection!(infections, ind, p.pathogen_id, p.infection_id, p.dp, p.progression_id)
                # contribute the new infection's care demand
                compute_health!(ind, infections, health_progression(sim), state, tick(sim),
                    sim.rngs[shard_id], sim.health_schedules[shard_id])
            end
            empty!(buf)
        end
    end
    return nothing
end



"""
    flush_ended_infections!(sim)
 
Drains `removal_buffers` after the threaded update phase: grants the natural immunity each
ended infection leaves behind, clears `slot_to_row` entries for infections that ended during
this tick, and returns their indices to the free list so they can be reused.
"""
function flush_ended_infections!(sim::Simulation)
    pop = population(sim)
    num_shards = Threads.maxthreadid()

    Threads.@threads :static for shard_id in 1:num_shards
        reg = sim.infection_registries[shard_id]
        immunities = sim.immunity_registries[shard_id]

        @inbounds for producer_id in 1:num_shards
            buf = sim.removal_buffers[producer_id, shard_id]
            for r in buf
                r.pathogen_id == DEFAULT_PATHOGEN_ID && continue
                ind = get_individual_by_id(pop, r.host_id)
                push_immunity!(immunities, ind, r.pathogen_id, IMMUNITY_SOURCE_NATURAL, r.recovery, DEFAULT_VACCINE_ID)
                ind.needs_immunity_update = true
                # refresh now: this runs before the spread phase, so the level must be current
                update_immunity!(ind, immunities, sim.pathogens, tick(sim), sim.rngs[shard_id])
            end
            # overflow unlinks before cache-slot promotions, so a just-ended overflow head
            # is unlinked before any promotion can pull it into cache
            for r in buf
                r.is_overflow || continue
                remove_infection!(reg, get_individual_by_id(pop, r.host_id), r)
            end
            for r in buf
                r.is_overflow && continue
                remove_infection!(reg, get_individual_by_id(pop, r.host_id), r)
            end
            empty!(buf)
        end
    end
    return nothing
end






"""
    _apply_transition!(indiv::Individual, hl::HealthLogger, tr::CareTransition, tick::Int16)

Applies one transition to the host's demand counter, logging only if it crossed zero — a second
overlapping contribution neither re-admits nor discharges.

Returns `true` if an admission edge fired, for the trigger phase.
"""
@inline function _apply_transition!(indiv::Individual, hl::HealthLogger, tr::CareTransition, tick::Int16)
    if tr.is_admission
        _adjust_demand!(indiv, tr.level, Int16(1)) == 1 || return false
        log!(hl, id(indiv), _care_event(tr.level, true), tick)
        return true
    end
    _adjust_demand!(indiv, tr.level, Int16(-1)) == 0 &&
        log!(hl, id(indiv), _care_event(tr.level, false), tick)
    return false
end

"""
    drain_health_schedule!(sim::Simulation)

Realizes every care transition due at or before the current tick.

Admissions first, then discharges, each in ladder order (reversed for discharges). That split is what
lets one stay end exactly where another begins without logging a spurious discharge and re-admission,
while still logging both events of a zero-length stay.

Sweeps `<= tick`, so a bucket missed for any reason drains late rather than never, and logs at the
bucket's own tick to keep occupancy aligned.

Hosts due to die at or before this tick are skipped; `_close_care_at_death!` closes their open levels.
"""
function drain_health_schedule!(sim::Simulation)
    t = tick(sim)
    hl = healthlogger(sim)
    pop = population(sim)

    Threads.@threads :static for shard_id in 1:Threads.maxthreadid()
        sched = sim.health_schedules[shard_id]
        empty!(sched.admitted)
        while sched.head <= Int(t)
            bucket_tick = Int16(sched.head)
            sched.head += 1
            bucket = get(sched.buckets, bucket_tick, nothing)
            bucket === nothing && continue

            for level in instances(CareLevel), tr in bucket
                (tr.is_admission && tr.level === level) || continue
                indiv = get_individual_by_id(pop, tr.host_id)
                (Int16(0) <= indiv.death <= t) && continue
                _apply_transition!(indiv, hl, tr, bucket_tick) &&
                    level === CARE_HOSPITAL && push!(sched.admitted, tr.host_id)
            end
            for level in reverse(instances(CareLevel)), tr in bucket
                (!tr.is_admission && tr.level === level) || continue
                indiv = get_individual_by_id(pop, tr.host_id)
                (Int16(0) <= indiv.death <= t) && continue
                _apply_transition!(indiv, hl, tr, bucket_tick)
            end

            delete!(sched.buckets, bucket_tick)
        end
    end
    return nothing
end

"""
    fire_hospitalization_triggers!(sim::Simulation)

Fires the hospitalization triggers for every host admitted by this tick's drain.

Separate from the drain, and after the individual loop, so a trigger's `condition` and `delay` see
this tick's disease flags as well as the finished care counters.
"""
function fire_hospitalization_triggers!(sim::Simulation)
    triggers = hospitalization_triggers(sim)
    isempty(triggers) && return nothing
    pop = population(sim)
    for sched in sim.health_schedules, host_id in sched.admitted
        indiv = get_individual_by_id(pop, host_id)
        for ht in triggers
            trigger(ht, indiv, sim, staged = true)
        end
    end
    return nothing
end

"""
    _close_care_at_death!(indiv::Individual, hl::HealthLogger, tick::Int16)

Closes every open care level when a host dies, logging one discharge per level in reverse ladder
order. Counters are zeroed rather than decremented, so a stale queued discharge cannot drive one
negative.
"""
@inline function _close_care_at_death!(indiv::Individual, hl::HealthLogger, tick::Int16)
    for level in reverse(instances(CareLevel))
        _demand(indiv, level) > 0 || continue
        _set_demand!(indiv, level, Int16(0))
        log!(hl, id(indiv), _care_event(level, false), tick)
    end
    return nothing
end

"""
    update_individual!(indiv::Individual, tick::Int16, sim::Simulation)

Update the individual disease progression, handle its recovery and log its possible death.
If the individual is not infected, this function will just return.
"""
function update_individual!(indiv::Individual, tick::Int16, sim::Simulation)
    was_dead = dead(indiv)
    was_symptomatic = symptomatic(indiv)

    # update immunity levels
    if indiv.needs_immunity_update
        update_immunity!(indiv, immunity_registry(sim, id(indiv)), sim.pathogens, tick, rng(sim))
    end

    # progress disease while infected, or while a scheduled death is still pending: a death can fall
    # after every infection has cleared, and the drain does not realize deaths
    if infected(indiv) || (Int16(0) <= indiv.death && !was_dead)
        shard_id = _owner_shard(id(indiv))

        progress_disease!(indiv, infection_registry(sim, id(indiv)), sim.pathogens, sim.removal_buffers[Threads.threadid(), shard_id], tick, rng(sim))

        if !was_dead && dead(indiv)
            log!(deathlogger(sim), id(indiv), indiv.killing_pathogen_id, tick)
            _close_care_at_death!(indiv, healthlogger(sim), tick)
        end
    end

    if !was_symptomatic && symptomatic(indiv)
        for st in sim |> symptom_triggers
            trigger(st, indiv, sim, staged = true)
        end
    end
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
    _printinfo("Running Simulation $(label(simulation))")

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
