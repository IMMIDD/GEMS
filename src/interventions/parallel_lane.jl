###
### PARALLEL LANE
###

# A slot is what a phase runs per: a shard in the owner phase, otherwise a chunk of events or objects.
# Each slot has its own random stream and log column. The producer is the slot making a request; a person's owner is the shard that holds their state.
# `process_events!` (simulation_methods.jl) runs the rounds: the serial lane, a setting phase, an owner phase, then the serial requests.

# setting events with their tick and target queue
const _StagedSettingEvents = Vector{Tuple{SMeasureEvent, Int16, EventQueue}}

# A request to trigger `strategy` for `individual`.
struct _IStrategyRequest
    individual::Individual
    strategy::IStrategy
end

# A request to trigger `strategy` for `setting`.
struct _SStrategyRequest
    setting::Setting
    strategy::SStrategy
end

# What a thread is working as during event processing.
mutable struct _EventContext
    # the shard whose owner phase this thread runs, otherwise 0
    owner::Int
    # the slot this thread works for, 0 in serial code
    slot::Int
    # whether this thread added to an owner request matrix
    has_owner_requests::Bool
end

_EventContext() = _EventContext(0, 0, false)

# Queues, random streams and request buffers of the events that run in the parallel lane.
mutable struct _ParallelLane <: AbstractParallelLane
    # individual events by owning shard
    owner_queues::Vector{EventQueue}
    # setting events
    setting_queue::EventQueue
    # random stream per slot
    slot_rngs::Vector{Xoshiro}
    # per thread
    contexts::Vector{_EventContext}
    # requests for the owner phase, by producer and owning shard
    owner_requests::Matrix{Vector{_IStrategyRequest}}
    # requests from the owner phase for the next round, by producer and owning shard
    next_owner_requests::Matrix{Vector{_IStrategyRequest}}
    # requests for serial code, by producer
    serial_individual_requests::Vector{Vector{_IStrategyRequest}}
    serial_setting_requests::Vector{Vector{_SStrategyRequest}}
    # setting events from a threaded tick trigger, by slot
    staged_setting_events::Vector{_StagedSettingEvents}
end

"""
    _slot_rngs(seed::Int64)

Returns one `Xoshiro` per slot, derived from `seed` and the slot, each created on the thread that runs that slot.
"""
function _slot_rngs(seed::Int64)
    v = Vector{Xoshiro}(undef, Threads.maxthreadid())
    Threads.@threads :static for s in eachindex(v)
        v[s] = _rekey!(Xoshiro(0), _mix(UInt64(4), seed, s))
    end
    return v
end

_ParallelLane(seed::Int64) = _ParallelLane(
    _shard_local_vector(EventQueue),
    EventQueue(),
    _slot_rngs(seed),
    _thread_local_vector(_EventContext),
    _shard_local_matrix(Vector{_IStrategyRequest}),
    _shard_local_matrix(Vector{_IStrategyRequest}),
    _shard_local_vector(Vector{_IStrategyRequest}),
    _shard_local_vector(Vector{_SStrategyRequest}),
    _shard_local_vector(_StagedSettingEvents)
)

###
### ACCESSORS
###

"""
    _parallel_lane(sim::Simulation)

Returns the state of the parallel lane.
"""
_parallel_lane(sim::Simulation) = sim.parallel_lane::_ParallelLane

"""
    _setting_queue(sim::Simulation)

Returns the queue of the setting events that run in the parallel lane.
"""
_setting_queue(sim::Simulation) = _parallel_lane(sim).setting_queue

"""
    _owner_queue(sim::Simulation, shard::Integer)

Returns the queue of the individual events that run in the parallel lane on `shard`.
"""
_owner_queue(sim::Simulation, shard::Integer) = _parallel_lane(sim).owner_queues[shard]

"""
    _event_context(sim::Simulation)

Returns what this thread is working as during event processing.
"""
_event_context(sim::Simulation) = _parallel_lane(sim).contexts[Threads.threadid()]

###
### THREAD CONTEXT
###

"""
    _in_slot(context::_EventContext)

Returns whether this thread is working for a slot of the parallel lane.
"""
_in_slot(context::_EventContext) = context.slot != 0

"""
    _in_owner_phase(context::_EventContext)

Returns whether this thread is working for a shard in the owner phase.
"""
_in_owner_phase(context::_EventContext) = context.owner != 0

"""
    _log_slot(sim::Simulation)

Returns the logger column an event on this thread writes to: its slot in a phase of the parallel lane, otherwise the thread's own.
"""
function _log_slot(sim::Simulation)
    context = _event_context(sim)
    return _in_slot(context) ? context.slot : Threads.threadid()
end

###
### RUNNING SLOTS
###

"""
    _with_slot(f, sim, slot::Int; owner_phase::Bool = false)

Calls `f()` on this thread as `slot`, with that slot's random stream. In the owner phase the slot owns its shard, so `f` may evaluate that shard's people.
"""
function _with_slot(f, sim, slot::Int; owner_phase::Bool = false)
    tid = Threads.threadid()
    context = _event_context(sim)
    thread_rng = sim.rngs[tid]
    sim.rngs[tid] = _parallel_lane(sim).slot_rngs[slot]
    context.slot = slot
    context.owner = owner_phase ? slot : 0
    f()
    context.slot = 0
    context.owner = 0
    sim.rngs[tid] = thread_rng
    return nothing
end

"""
    _foreach_slot(f, sim; owner_phase::Bool = false)

Calls `f(slot)` as every slot, on all threads. In the owner phase each slot owns its shard. `sim` stays untyped: the tests add a method on `Simulation` that shuffles the slots.
"""
function _foreach_slot(f, sim; owner_phase::Bool = false)
    try
        Threads.@threads :static for slot in 1:Threads.maxthreadid()
            _with_slot(() -> f(slot), sim, slot; owner_phase)
        end
    catch e
        throw(_thread_exception(e))
    end
    return nothing
end

"""
    _foreach_chunk(f, sim, n::Int)

Splits `1:n` into one contiguous chunk per slot and calls `f(range)` as that slot.
"""
function _foreach_chunk(f, sim, n::Int)
    per_chunk = cld(n, Threads.maxthreadid())
    _foreach_slot(sim) do chunk
        f(((chunk - 1) * per_chunk + 1):min(chunk * per_chunk, n))
    end
    return nothing
end

###
### REQUESTS
###

"""
    _request_from_owner!(str::IStrategy, i::Individual, sim::Simulation, context::_EventContext, shard::Integer)

Hands the trigger of `str` for `i` to its owner `shard`: for the next round if this is the owner phase, otherwise for the next owner phase.
"""
function _request_from_owner!(str::IStrategy, i::Individual, sim::Simulation, context::_EventContext, shard::Integer)
    parallel_lane = _parallel_lane(sim)
    requests = _in_owner_phase(context) ? parallel_lane.next_owner_requests : parallel_lane.owner_requests
    push!(requests[context.slot, shard], _IStrategyRequest(i, str))
    context.has_owner_requests = true
    return nothing
end

###
### ROUNDS
###

"""
    _events_due(sim, t)

Returns whether any event queue of `sim` holds an event due at a tick `<= t`.
"""
function _events_due(sim, t)
    _has_due(event_queue(sim), t) && return true
    _has_due(_setting_queue(sim), t) && return true
    return _owner_events_due(sim, t)
end

"""
    _owner_events_due(sim, t)

Returns whether any owner queue of `sim` holds an event due at a tick `<= t`.
"""
_owner_events_due(sim, t) = any(shard -> _has_due(_owner_queue(sim, shard), t), 1:Threads.maxthreadid())

"""
    _owner_requests_pending(sim)

Returns whether the owner phase of the next round has requests to process.
"""
_owner_requests_pending(sim) = any(c -> c.has_owner_requests, _parallel_lane(sim).contexts)

"""
    _run_setting_phase!(sim, t)

Processes the due setting events of the parallel lane, split into one chunk per slot by position.
"""
function _run_setting_phase!(sim, t)
    _foreach_due_setting_bucket(_setting_queue(sim), t) do bucket
        _foreach_chunk(sim, length(bucket)) do range
            for k in range
                process_event(@inbounds(bucket[k]), sim)
            end
        end
    end
    return nothing
end

"""
    _run_owner_phase!(sim, t)

Lets every shard process its due events and the requests for it. Requests made during this phase wait for the next round.
"""
function _run_owner_phase!(sim, t)
    if !_owner_events_due(sim, t) && !_owner_requests_pending(sim)
        return nothing
    end
    parallel_lane = _parallel_lane(sim)
    # the requests made so far are the ones this phase processes
    foreach(c -> c.has_owner_requests = false, parallel_lane.contexts)
    _foreach_slot(sim, owner_phase = true) do shard
        _process_owner_shard!(sim, shard, t)
    end
    processed = parallel_lane.owner_requests
    parallel_lane.owner_requests = parallel_lane.next_owner_requests
    parallel_lane.next_owner_requests = processed
    return nothing
end

# Processes the due events of `shard`, then its requests, so that a second request for the same person sees the effect of the first.
function _process_owner_shard!(sim::S, shard::Int, t) where {S}
    queue = _owner_queue(sim, shard)
    process_due!(queue, sim, t)
    requests = _parallel_lane(sim).owner_requests
    for producer in axes(requests, 1)
        column = @inbounds requests[producer, shard]
        for k in eachindex(column)
            # people are scattered in memory, so fetch the next ones early
            _prefetch_listed_ahead(j -> (column[j]).individual, length(column), k, activity_plans(sim))
            r =  column[k]
            trigger_strategy(r.strategy::IStrategy{S}, r.individual, sim)
            _drain_individual_events!(queue, t, sim)
        end
        empty!(column)
    end
    _advance_head!(queue)
    return nothing
end

"""
    _run_serial_requests!(sim)

Triggers what the phases requested from serial code, in producer order.
"""
function _run_serial_requests!(sim::S) where {S}
    parallel_lane = _parallel_lane(sim)
    for producer in eachindex(parallel_lane.serial_individual_requests)
        for r in parallel_lane.serial_individual_requests[producer]
            trigger_strategy(r.strategy::IStrategy{S}, r.individual, sim)
        end
        empty!(parallel_lane.serial_individual_requests[producer])
        for r in parallel_lane.serial_setting_requests[producer]
            trigger_strategy(r.strategy::SStrategy{S}, r.setting, sim)
        end
        empty!(parallel_lane.serial_setting_requests[producer])
    end
    return nothing
end
