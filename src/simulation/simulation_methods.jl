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
    st_unab_cnt = zeros(Int, Threads.maxthreadid())
    wo_unab_cnt = zeros(Int, Threads.maxthreadid())
    hb_cnt = zeros(Int, Threads.maxthreadid())

    plans = activity_plans(simulation)
    s_classes = schoolclasses(simulation)
    offs = offices(simulation)
    # true if no class (office) is closed
    classes_open = _all_open(settingscontainer(simulation), SchoolClass)
    offices_open = _all_open(settingscontainer(simulation), Office)

    # the homebound and hospitalized the disease update found, unless `update_quarantines!` counted them as quarantined
    log_counts = simulation.state_log_counts
    Threads.@threads :static for counts in log_counts
        tid = Threads.threadid()
        loc_st_unab = 0; loc_wo_unab = 0; loc_hb = 0
        for i in counts.in_care
            # at home, so not counted again under hospital occupancy
            loc_hb += is_homebound(i) && !is_hospitalized(i) ? 1 : 0
            isquarantined(i) && continue
            loc_st_unab += _open_memberships(plans, i, s_classes, classes_open)
            loc_wo_unab += _open_memberships(plans, i, offs, offices_open)
        end
        @inbounds st_unab_cnt[tid] += loc_st_unab
        @inbounds wo_unab_cnt[tid] += loc_wo_unab
        @inbounds hb_cnt[tid] += loc_hb
    end

    if !classes_open
        for s in s_classes
            is_open(s) || (st_unab_cnt[1] += size(s))
        end
    end
    if !offices_open
        for o in offs
            is_open(o) || (wo_unab_cnt[1] += size(o))
        end
    end

    quarantined = sum(t -> t.quarantined, log_counts)
    quarantined_students = sum(t -> t.quarantined_students, log_counts)
    quarantined_workers = sum(t -> t.quarantined_workers, log_counts)

    log!(
        simulation |> quarantinelogger,
        simulation |> tick,
        quarantined,
        quarantined_students,
        quarantined_workers
    )

    log!(simulation |> statelogger;
        tick = simulation |> tick,
        exposed = sum(t -> t.exposed, log_counts),
        infectious = sum(length, simulation.infectious_individuals),
        dead = length(deathlogger(simulation)),
        detected = sum(t -> t.detected, log_counts),
        quarantined = quarantined,
        quarantined_students = quarantined_students,
        isolated_students = sum(t -> t.isolated_students, log_counts),
        unable_to_attend_students = sum(st_unab_cnt) + sum(t -> t.missed_classes, log_counts),
        quarantined_workers = quarantined_workers,
        isolated_workers = sum(t -> t.isolated_workers, log_counts),
        unable_to_attend_workers = sum(wo_unab_cnt) + sum(t -> t.missed_offices, log_counts),
        homebound = sum(hb_cnt)
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
    last_homebound = isempty(sl.homebound) ? 0 : sl.homebound[end]

    current_tick = tick(simulation)
    
    # Log the copied state for the current tick
    log!(ql, current_tick, last_quar, last_quar_st, last_quar_wo)
    log!(sl; tick=current_tick, exposed=last_exposed, infectious=last_infectious, dead=last_dead, 
         detected=last_detected, quarantined=last_quar, quarantined_students=last_quar_st, 
         isolated_students=last_isol_st, unable_to_attend_students=last_unab_st, 
         quarantined_workers=last_quar_wo, isolated_workers=last_isol_wo, 
         unable_to_attend_workers=last_unab_wo, homebound=last_homebound)             
end

"""
    _open_memberships(plans::ActivityPlanStore, indiv::Individual, stngs::Vector{T}) where {T<:Setting}

Counts the settings of type `T` in `indiv`'s activity plan that are open.
"""
@inline function _open_memberships(plans::ActivityPlanStore, indiv::Individual, stngs::Vector{T}) where {T<:Setting}
    n = 0
    for slot in plan_slots(plans, indiv, T)
        @inbounds is_open(stngs[setting_id(plans.entries[slot])]) && (n += 1)
    end
    return n
end

"""
    _open_memberships(plans::ActivityPlanStore, indiv::Individual, stngs::Vector{T}, all_open::Bool) where {T<:Setting}

Counts the open settings of type `T` in `indiv`'s activity plan. Pass `all_open = true` when none of them
is closed; the settings are then not looked up.
"""
@inline _open_memberships(plans::ActivityPlanStore, indiv::Individual, stngs::Vector{T}, all_open::Bool) where {T<:Setting} =
    all_open ? length(plan_slots(plans, indiv, T)) : _open_memberships(plans, indiv, stngs)

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

# An import lands only on a host that is alive, not in hospital, homebound or isolating, and without the pathogen.
# Seeding runs before this tick's flags are updated, so death and quarantine are read from their ticks.
@inline _can_be_seeded(individual::Individual, pathogen_id::Int8, t::Int16) =
    !dead(individual) && !(Int16(0) <= individual.death <= t) &&
    !hospitalized(individual) && !is_homebound(individual) && !is_quarantined(individual, t) &&
    !infected(individual, pathogen_id)

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

    # realize scheduled care
    drain_health_schedule!(simulation)

    # seed scheduled imports
    seed_scheduled!(simulation)

    # update disease state and apply deaths
    update_population!(simulation, dormant)

    # fire hospitalization_triggers
    fire_hospitalization_triggers!(simulation)
    # merge per-thread staged trigger events into the queue before processing
    flush_staging!(event_queue(simulation))

    # infect individuals in settings
    if !dormant
        spread_infections!(simulation)

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
        update_quarantines!(simulation)
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
    
    # wake up if a care transition or a death is due today; later ones don't keep the simulation awake
    if any(s -> due_now(s, current_t), simulation.health_schedules)
        return false
    end

    # wake up if infections were staged outside the spreading phase
    if any(!isempty, simulation.infection_buffers)
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
 
Commits every `_PendingInfection` staged in `sim.infection_buffers`, keeping one winner per
`(host, pathogen)` and dropping the rest. Empties each buffer when done.

Two passes: the first records the smallest `_deduplication_key` per
`(host, pathogen)`, the second commits the attempt carrying it.

Each shard reserves its block of infection ids up front, so ids are reproducible. Losers leave
gaps in a block.
"""
function flush_pending_infections!(sim::Simulation)
    logger = infectionlogger(sim)
    plans = activity_plans(sim)
    num_shards = Threads.maxthreadid()

    # serial: reserve one id block per shard, sized by what that shard is about to see
    id_bases = Vector{Int32}(undef, num_shards)
    @inbounds for shard_id in 1:num_shards
        arrivals = 0
        for producer_id in 1:num_shards
            arrivals += length(sim.infection_buffers[producer_id, shard_id])
        end
        id_bases[shard_id] = reserve_infection_ids!(logger, arrivals)
    end

    Threads.@threads :static for shard_id in 1:num_shards
        infections = sim.infection_registries[shard_id]
        best = sim.deduplication_winners[shard_id]
        next_id = id_bases[shard_id]

        # pass 1: pick canonical winner of each contest, over the whole column
        empty!(best)
        @inbounds for producer_id in 1:num_shards
            for p in sim.infection_buffers[producer_id, shard_id]
                k = _deduplication_key(p)
                hp = (p.host_id, p.pathogen_id)
                cur = get(best, hp, nothing)
                (cur === nothing || k < cur) && (best[hp] = k)
            end
        end

        # pass 2: commit the winners. The mask guard skips the losers' host and settles exact ties.
        counts = sim.state_log_counts[Threads.threadid()]
        @inbounds for producer_id in 1:num_shards
            buf = sim.infection_buffers[producer_id, shard_id]
            for j in eachindex(buf)
                # hosts and their plan entries, read for the log's household, are cache misses unless fetched ahead
                _prefetch_listed_ahead(i -> buf[i].host, length(buf), j, plans)
                # and the hosts' `id_map` entries, read by `_mark_active!`
                _prefetch_id_map_ahead(i -> buf[i].host_id, length(buf), j, population(sim))
                p = buf[j]
                _deduplication_key(p) == best[(p.host_id, p.pathogen_id)] || continue
                ind = p.host
                infected(ind, p.pathogen_id) && continue
                # a first infection makes the host exposed, which the state log counts
                infected(ind) || (counts.exposed += 1)
                _commit_infection!(sim, ind, p, next_id, infections, logger, shard_id)
                next_id += Int32(1)
            end
            empty!(buf)
        end
    end
    return nothing
end

"""
    _commit_infection!(sim, ind, p::_PendingInfection, infection_id, infections, logger, shard_id)

Realizes one deduplicated infection: logs it under `infection_id`, stores the state, contributes
its care demand and sets the host's flags.
"""
function _commit_infection!(sim::Simulation, ind::Individual, p::_PendingInfection,
        infection_id::Int32, infections::InfectionRegistry, logger::InfectionLogger, shard_id::Int)
    log!(
        logger,
        infection_id,
        p.infecter_id,
        p.host_id,
        p.pathogen_id,
        p.progression_id,
        p.tick,
        infectiousness_onset(p.dp),
        symptom_onset(p.dp),
        severeness_onset(p.dp),
        critical_onset(p.dp),
        critical_offset(p.dp),
        severeness_offset(p.dp),
        recovery(p.dp),
        p.setting_id,
        p.setting_type,
        # an infection in a setting is located at the host's household; a seed has no location
        p.setting_id == DEFAULT_SETTING_ID ? DEFAULT_SETTING_ID : household_id(ind, activity_plans(sim)),
        p.source_infection_id
    )
    state = push_infection!(infections, ind, p.pathogen_id, infection_id, p.dp, p.progression_id)
    compute_health!(ind, infections, health_progression(sim), sim.health_profiles, state, tick(sim),
        sim.rngs[shard_id], sim.health_schedules[shard_id])
    _mark_infected!(ind, p.pathogen_id)
    _mark_active!(sim, ind)
    return nothing
end



"""
    flush_ended_infections!(sim)
 
Drains `removal_buffers` after the threaded update phase: grants the natural immunity each
ended infection leaves behind, clears `slot_to_row` entries for infections that ended during
this tick, and returns their indices to the free list so they can be reused.
"""
function flush_ended_infections!(sim::Simulation)
    num_shards = Threads.maxthreadid()

    Threads.@threads :static for shard_id in 1:num_shards
        reg = sim.infection_registries[shard_id]
        immunities = sim.immunity_registries[shard_id]

        @inbounds for producer_id in 1:num_shards
            buf = sim.removal_buffers[producer_id, shard_id]
            for r in buf
                r.pathogen_id == DEFAULT_PATHOGEN_ID && continue
                ind = r.host
                push_immunity!(immunities, ind, r.pathogen_id, IMMUNITY_SOURCE_NATURAL, r.recovery, DEFAULT_VACCINE_ID)
            end
            # overflow unlinks before cache-slot promotions, so a just-ended overflow head
            # is unlinked before any promotion can pull it into cache
            for r in buf
                r.is_overflow || continue
                remove_infection!(reg, r.host, r)
            end
            for r in buf
                r.is_overflow && continue
                remove_infection!(reg, r.host, r)
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
        _adjust_care_demand!(indiv, tr.level, Int16(1)) == 1 || return false
        log!(hl, id(indiv), _care_event(tr.level, true), tick)
        return true
    end
    _adjust_care_demand!(indiv, tr.level, Int16(-1)) == 0 &&
        log!(hl, id(indiv), _care_event(tr.level, false), tick)
    return false
end

"""
    drain_health_schedule!(sim::Simulation)

Realizes every care transition and homebound start or end due at or before the current tick.

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

            # homebound windows are not logged and never zero-length, so start/end order is irrelevant
            homebound = get(sched.homebound_buckets, bucket_tick, nothing)
            if homebound !== nothing
                for tr in homebound
                    indiv = get_individual_by_id(pop, tr.host_id)
                    (Int16(0) <= indiv.death <= t) && continue
                    n = _adjust_homebound_demand!(indiv, tr.is_start ? Int16(1) : Int16(-1))
                    tr.is_start && n == 1 && _mark_active!(sim, indiv)
                end
                delete!(sched.homebound_buckets, bucket_tick)
            end

            bucket = get(sched.care_buckets, bucket_tick, nothing)
            bucket === nothing && continue

            for level in instances(CareLevel), tr in bucket
                (tr.is_admission && tr.level === level) || continue
                indiv = get_individual_by_id(pop, tr.host_id)
                (Int16(0) <= indiv.death <= t) && continue
                _apply_transition!(indiv, hl, tr, bucket_tick) || continue
                # an admission can come after the infection ended
                _mark_active!(sim, indiv)
                level === CARE_HOSPITAL && push!(sched.admitted, tr.host_id)
            end
            for level in reverse(instances(CareLevel)), tr in bucket
                (!tr.is_admission && tr.level === level) || continue
                indiv = get_individual_by_id(pop, tr.host_id)
                (Int16(0) <= indiv.death <= t) && continue
                _apply_transition!(indiv, hl, tr, bucket_tick)
                # the update finds whether the host is still in care
                _mark_active!(sim, indiv)
            end

            delete!(sched.care_buckets, bucket_tick)
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
order, and ends any homebound window unlogged. Counters are zeroed rather than decremented, so a
stale queued discharge cannot drive one negative.
"""
@inline function _close_care_at_death!(indiv::Individual, hl::HealthLogger, tick::Int16)
    for level in reverse(instances(CareLevel))
        _get_care_demand(indiv, level) > 0 || continue
        _set_care_demand!(indiv, level, Int16(0))
        log!(hl, id(indiv), _care_event(level, false), tick)
    end
    indiv.homebound_demands = 0
    return nothing
end

"""
    _mark_active!(sim::Simulation, indiv::Individual)

Flags `indiv` for the disease-update loop and state log, due at the next update. No-op if it is not part of the population.
"""
@inline function _mark_active!(sim::Simulation, indiv::Individual)
    k = _individual_index(population(sim), id(indiv))
    if k > 0
        @inbounds sim.active_individuals[k] = true
        @inbounds sim.update_states[k] = _UpdateState()
    end
    return nothing
end

"""
    _mark_quarantined!(sim::Simulation, indiv::Individual)

Flags `indiv` for the quarantine update and state log. No-op if it is not part of the population.
"""
@inline function _mark_quarantined!(sim::Simulation, indiv::Individual)
    k = _individual_index(population(sim), id(indiv))
    k > 0 && (@inbounds sim.quarantined_individuals[k] = true)
    return nothing
end

"""
    _stays_active(indiv::Individual)

Whether `indiv` must keep its active flag after this tick's disease update.
"""
@inline _stays_active(indiv::Individual) = infected(indiv) ||
    (Int16(0) <= indiv.death && !dead(indiv)) || hospitalized(indiv) || detected(indiv) || is_homebound(indiv)

"""
    update_individual!(indiv::Individual, tick::Int16, sim::Simulation)

Update the individual disease progression, handle its recovery and log its possible death.
Returns the `_UpdateState` the update found, with the tick of its next one.
"""
function update_individual!(indiv::Individual, tick::Int16, sim::Simulation)
    was_dead = dead(indiv)
    was_symptomatic = symptomatic(indiv)

    # progress disease while infected, or while a scheduled death is still pending: a death can fall
    # after every infection has cleared, and the drain does not realize deaths
    if infected(indiv) || (Int16(0) <= indiv.death && !was_dead)
        shard_id = _owner_shard(id(indiv))

        progress_disease!(indiv, sim.infection_registries[shard_id], sim.pathogens, sim.removal_buffers[Threads.threadid(), shard_id], tick, sim.seed)

        if !was_dead && dead(indiv)
            log!(deathlogger(sim), id(indiv), indiv.killing_pathogen_id, tick)
            _close_care_at_death!(indiv, healthlogger(sim), tick)
            # leaves its settings in `apply_deaths!`, after this threaded loop
            push!(sim.newly_dead[Threads.threadid()], indiv)
        end
    end

    if !was_symptomatic && symptomatic(indiv)
        for st in sim |> symptom_triggers
            trigger(st, indiv, sim, staged = true)
        end
    end
    return _UpdateState(_next_update(indiv, infection_registry(sim, id(indiv)), sim.pathogens, tick), indiv)
end

# Prefetching for the loops over individuals: each one is a cache miss unless fetched ahead.

# How many list positions ahead `_prefetch_listed_ahead` fetches individuals and their plan entries
const LISTED_PREFETCH_DISTANCE = 8
const LISTED_PLAN_PREFETCH_DISTANCE = 4
# How many list positions ahead `_prefetch_id_map_ahead` fetches `id_map` entries
const ID_MAP_PREFETCH_DISTANCE = 16

# While a loop works on item `k` of `n`, prefetches the `Individual` `LISTED_PREFETCH_DISTANCE` ahead and
# the plan entries of the one `LISTED_PLAN_PREFETCH_DISTANCE` ahead, whose `Individual` an earlier call fetched.
@inline function _prefetch_listed_ahead(individual_at::F, n::Int, k::Int, plans::ActivityPlanStore) where {F}
    k + LISTED_PREFETCH_DISTANCE <= n && _prefetch(pointer_from_objref(individual_at(k + LISTED_PREFETCH_DISTANCE)), sizeof(Individual))
    if k + LISTED_PLAN_PREFETCH_DISTANCE <= n
        next = individual_at(k + LISTED_PLAN_PREFETCH_DISTANCE)
        len = plan_length(next)
        len > 0 && _prefetch(pointer(plans.entries, Int(next.plan_offset)), len * sizeof(PlanEntry))
    end
    return nothing
end

# While a loop works on item `k` of `n`, prefetches the `id_map` entry of the id `ID_MAP_PREFETCH_DISTANCE` ahead.
@inline function _prefetch_id_map_ahead(id_at::F, n::Int, k::Int, population::Population) where {F}
    if k + ID_MAP_PREFETCH_DISTANCE <= n
        idx = id_at(k + ID_MAP_PREFETCH_DISTANCE) - population.minid + 1
        1 <= idx <= length(population.id_map) && _prefetch(pointer(population.id_map, Int(idx)), sizeof(Int32))
    end
    return nothing
end

# How many indices ahead `_prefetch_flagged_ahead` fetches
const FLAGGED_PREFETCH_DISTANCE = 256

# Starts loading `inds[k + FLAGGED_PREFETCH_DISTANCE]` if `flagged` at that index. A loop over a
# sparse set of individuals in index order leaves gaps too large for the CPU to stream them itself.
@inline function _prefetch_flagged_ahead(flagged::F, inds::Vector{Individual}, k::Int) where {F}
    j = k + FLAGGED_PREFETCH_DISTANCE
    j <= length(inds) && flagged(j) && _prefetch(pointer_from_objref(@inbounds inds[j]), sizeof(Individual))
    return nothing
end

"""
    update_individuals!(sim::Simulation)

Updates every active individual that has an update due and collects the infectious ones per thread for the transmission phase.
"""
function update_individuals!(sim::Simulation)
    t = tick(sim)
    inds = individuals(population(sim))
    active = sim.active_individuals
    states = sim.update_states
    foreach(empty!, sim.infectious_individuals)
    foreach(_reset!, sim.state_log_counts)
    due(j) = @inbounds(active[j] && states[j].next_update <= t)
    Threads.@threads :static for k in eachindex(inds)
        _prefetch_flagged_ahead(due, inds, k)
        @inbounds active[k] || continue
        # only the pointer; an individual with nothing due is not read
        i = @inbounds inds[k]
        if due(k)
            @inbounds states[k] = update_individual!(i, t, sim)
            @inbounds active[k] = _stays_active(i)
        end
        s = @inbounds states[k]
        # the transmission phase goes through exactly these
        s.infectious && push!(sim.infectious_individuals[Threads.threadid()], i)
        _count_for_state_log!(sim.state_log_counts[Threads.threadid()], i, s)
    end
    return nothing
end

"""
    mark_deceased!(individual::Individual, sim::Simulation)

Marks a dead individual deceased in each of their settings.
"""
function mark_deceased!(individual::Individual, sim::Simulation)
    for e in plan_entries(activity_plans(sim), individual)
        _with_entry_setting(s -> mark_deceased!(s, individual, sim), settingscontainer(sim), e)
    end
    return nothing
end

# Marks this tick's dead deceased; `spread_infections!` repacks the pools. A mark swaps two members, so
# each setting, and all settings of a pooled type, are marked by a single thread.
function apply_deaths!(sim::Simulation)
    any(!isempty, sim.newly_dead) || return nothing
    cntnr = settingscontainer(sim)
    # (type, part, parts): a flat type split by setting id, a pooled type whole
    parts = Tuple{DataType, Int, Int}[]
    for T in settingtypes(cntnr)
        (T <: IndividualSetting && hasfield(T, :deceased)) || continue
        n = hasfield(T, :pool) ? 1 : Threads.nthreads()
        append!(parts, ((T, p, n) for p in 0:(n - 1)))
    end
    Threads.@threads :dynamic for (T, part, n) in parts
        _apply_deaths!(sim, settings(cntnr, T), part, n)
    end
    foreach(empty!, sim.newly_dead)
    return nothing
end

# Marks this tick's dead deceased in the settings of one type with `setting_id % n == part`, in the
# order the disease update found them, which is population order whichever thread found a death.
function _apply_deaths!(sim::Simulation, stngs::Vector{T}, part::Int, n::Int) where {T<:IndividualSetting}
    plans = activity_plans(sim)
    for buf in sim.newly_dead, ind in buf, slot in plan_slots(plans, ind, T)
        sid = setting_id(@inbounds plans.entries[slot])
        sid % n == part && mark_deceased!(stngs[sid], ind, sim)
    end
    return nothing
end

"""
    update_population!(sim::Simulation, dormant::Bool)

Advances every active individual and applies what changes the population. Does nothing on a dormant tick.
"""
function update_population!(sim::Simulation, dormant::Bool)
    if !dormant
        update_individuals!(sim)
        flush_ended_infections!(sim)
        apply_deaths!(sim)
    end
    return nothing
end

"""
    update_quarantines!(sim::Simulation)

Sets the quarantine status of every individual with a quarantine that has not ended yet, and counts the
quarantined individuals for the state log.
"""
function update_quarantines!(sim::Simulation)
    t = tick(sim)
    inds = individuals(population(sim))
    plans = activity_plans(sim)
    quarantined = sim.quarantined_individuals
    s_classes = schoolclasses(sim)
    offs = offices(sim)
    # true if no class (office) is closed
    classes_open = _all_open(settingscontainer(sim), SchoolClass)
    offices_open = _all_open(settingscontainer(sim), Office)
    Threads.@threads :static for k in eachindex(inds)
        @inbounds quarantined[k] || continue
        i = @inbounds inds[k]
        quarantined!(i, is_quarantined(i, t))
        @inbounds quarantined[k] = t < quarantine_release_tick(i)
        isquarantined(i) && _count_quarantined!(sim.state_log_counts[Threads.threadid()], i, plans,
            s_classes, offs, classes_open, offices_open)
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

    # the buffers are sized by the busiest tick
    _release_tick_buffers!(simulation)

    println()
    return simulation
end
