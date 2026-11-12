###
### SHARED TEST FIXTURES
###


import GEMS: INFECTIONS_CACHE_SIZE, DEFAULT_INFECTION_ID, DEFAULT_TICK, push_infection!, infected!

"""
    set_progression!(ind::Individual, dp::DiseaseProgression, pathogen_id::Int8 = Int8(1))

Applies `dp` directly to `ind` by writing an active `InfectionState` into the individual's
infection cache, bypassing the normal simulation buffer and flush cycle.
The individual is immediately visible as infected for `pathogen_id` without needing a running
`Simulation` or a call to `step!`.

If `ind` is already actively infected with `pathogen_id`, this is a no-op (with a warning):
at most one active infection per pathogen is allowed.
"""
function set_progression!(ind::Individual, dp::DiseaseProgression, pathogen_id::Int8 = Int8(1))
    # at most one active infection per pathogen; skip a duplicate rather than corrupt the invariant
    if infected(ind, pathogen_id)
        @warn "set_progression!: individual $(id(ind)) is already infected with pathogen $pathogen_id; skipping to preserve the one-active-infection-per-pathogen invariant."
        return nothing
    end
    _free_cache_slot(ind) # without a persistent registry, an overflow would dangle
    push_infection!(InfectionRegistry(), ind, pathogen_id, DEFAULT_INFECTION_ID, dp)
    infected!(ind, true)
    infected!(ind, pathogen_id, true)
    return nothing
end

"""
    set_progression!(ind::Individual, pathogen_id::Int8 = Int8(1))

Seeds an active `InfectionState` with all fields set to `DEFAULT_TICK` (i.e. -1).
Useful when you need an active infection slot for a specific pathogen without
constraining any timeline values.
"""
function set_progression!(ind::Individual, pathogen_id::Int8 = Int8(1))
    # at most one active infection per pathogen; skip a duplicate rather than corrupt the invariant
    if infected(ind, pathogen_id)
        @warn "set_progression!: individual $(id(ind)) is already infected with pathogen $pathogen_id; skipping to preserve the one-active-infection-per-pathogen invariant."
        return nothing
    end
    blank = InfectionState(
        DEFAULT_INFECTION_ID, Int32(0),
        DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK,
        DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK, DEFAULT_TICK,
        Int8(0), pathogen_id, Int8(0), true
    )
    # a free slot, not slot 1: a fixed slot overwrites an existing infection while
    # active_pathogens_mask still claims it, leaving a flag no recovery can clear
    ind.infection_cache = Base.setindex(ind.infection_cache, blank, _free_cache_slot(ind))
    infected!(ind, true)
    infected!(ind, pathogen_id, true)
    return nothing
end

# index of the first free infection cache slot; throws if the cache is full
function _free_cache_slot(ind::Individual)
    i = findfirst(i -> !ind.infection_cache[i].active, 1:INFECTIONS_CACHE_SIZE)
    isnothing(i) && throw(ArgumentError("set_progression! cannot store more than $INFECTIONS_CACHE_SIZE concurrent infection(s) per individual without a Simulation context."))
    return i
end

"""
    fake_membership!(pop::Population, ind::Individual, ::Type{T}, sid::Integer) where {T<:Setting}

Gives `ind` a plan entry for setting `sid` of type `T` without making it a member of that
setting, for tests that only need the id to resolve. `assign_settings!` refuses this once the
plans are indexed, because a simulation must not hold such an entry.
"""
function fake_membership!(pop::Population, ind::Individual, ::Type{T}, sid::Integer) where {T<:Setting}
    GEMS.plan_add!(GEMS.activity_plans(pop), ind, GEMS.PlanEntry(T, Int32(sid), GEMS.DEFAULT_MEMBER_INDEX))
    return nothing
end

# makes the slots of a phase run serially in a random order, to check that the order does not matter
const SHUFFLED_SLOTS = Ref(false)

# adds a method for `Simulation` next to the one in `src`, and passes on to that one unless the phases are shuffled
function GEMS._foreach_slot(f, sim::Simulation; owner_phase::Bool = false)
    SHUFFLED_SLOTS[] || return invoke(GEMS._foreach_slot, Tuple{Any, Any}, f, sim; owner_phase)
    for slot in GEMS.gems_shuffle!(GEMS.Xoshiro(Int(tick(sim))), collect(1:Threads.maxthreadid()))
        GEMS._with_slot(() -> f(slot), sim, slot; owner_phase)
    end
    return nothing
end

"""
    with_shuffled_slots(f)

Calls `f()` with the slots of every phase running serially in a random order.
"""
function with_shuffled_slots(f)
    SHUFFLED_SLOTS[] = true
    try
        return f()
    finally
        SHUFFLED_SLOTS[] = false
    end
end

struct QueuedEvents
    queues::Vector{GEMS.EventQueue}
end

"""
    queued_events(sim::Simulation)

Returns a view of all event queues of `sim`, for tests that inspect what a measure queued. Events come out queue by queue.
"""
queued_events(sim::Simulation) = QueuedEvents(GEMS.EventQueue[
    GEMS.event_queue(sim),
    GEMS._setting_queue(sim),
    (GEMS._owner_queue(sim, s) for s in 1:Threads.maxthreadid())...
])

Base.isempty(q::QueuedEvents) = all(isempty, q.queues)
Base.empty!(q::QueuedEvents) = (foreach(empty!, q.queues); q)
GEMS.dequeue!(q::QueuedEvents) = GEMS.dequeue!(q.queues[findfirst(!isempty, q.queues)])
