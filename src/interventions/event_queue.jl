
###
### EVENT QUEUES
###


"""
    EventQueue <: AbstractEventQueue

Tick-bucketed ("calendar") queue for intervention events.

Events are scheduled for a specific (integer) tick and always at a tick `>=` the
current one, and the queue is drained in tick order. Individual events (`IMeasureEvent`)
and setting events (`SMeasureEvent`) are kept in separate, concretely-typed bucket vectors
(`i_buckets`/`s_buckets`). `buckets[t + 1]` holds every event scheduled for tick `t`
(ticks are 0-based). `enqueue!` is an `O(1)` `push!` into the relevant bucket; draining a
tick pops over its buckets, setting events before individual events (each LIFO).
"""
mutable struct EventQueue <: AbstractEventQueue

    # i_buckets[t + 1] / s_buckets[t + 1] hold all individual/setting events for tick t
    i_buckets::Vector{Vector{IMeasureEvent}}
    s_buckets::Vector{Vector{SMeasureEvent}}

    # lowest tick whose buckets may still contain events; every tick below has been drained
    head::Int

    # total number of queued events (across both bucket arrays)
    count::Int

    # Parallelization
    lock::ReentrantLock

    # Per-thread, lock-free staging buffers (one set per event type).
    i_staging::Vector{Vector{Tuple{IMeasureEvent, Int16}}}
    s_staging::Vector{Vector{Tuple{SMeasureEvent, Int16}}}
end

"""
    EventQueue()

Builds an empty `EventQueue`.
"""
EventQueue() = EventQueue(
    Vector{IMeasureEvent}[],
    Vector{SMeasureEvent}[],
    0,
    0,
    ReentrantLock(),
    [Tuple{IMeasureEvent, Int16}[] for _ in 1:Threads.maxthreadid()],
    [Tuple{SMeasureEvent, Int16}[] for _ in 1:Threads.maxthreadid()]
)

"""
    length(eq::EventQueue)

Returns the number of events in the `EventQueue`.
"""
Base.length(eq::EventQueue) = eq.count

"""
    isempty(eq::EventQueue)

Returns true if the `EventQueue` is empty.
"""
Base.isempty(eq::EventQueue) = eq.count == 0

# True if tick bucket `idx` (= tick + 1) is empty in both bucket arrays (or out of range).
@inline function _tick_empty(eq::EventQueue, idx::Int)
    s_empty = idx > length(eq.s_buckets) || isempty(eq.s_buckets[idx])
    i_empty = idx > length(eq.i_buckets) || isempty(eq.i_buckets[idx])
    return s_empty && i_empty
end

# Advance `head` over any leading empty ticks so it points at the earliest tick that still
# has events. Only ever moves `head` forward; safe to call repeatedly.
function _advance_head!(eq::EventQueue)
    n = max(length(eq.i_buckets), length(eq.s_buckets))
    while eq.head + 1 <= n && _tick_empty(eq, eq.head + 1)
        eq.head += 1
    end
    return eq
end

"""
    peek(eq::EventQueue)

Returns (without removing) the next `Event` to be dequeued.
Only valid on a non-empty queue.
"""
function Base.peek(eq::EventQueue)
    _advance_head!(eq)
    idx = eq.head + 1
    # setting events drain before individual events within a tick
    if idx <= length(eq.s_buckets) && !isempty(eq.s_buckets[idx])
        return last(eq.s_buckets[idx])
    end
    return last(eq.i_buckets[idx])
end

"""
    peektick(eq::EventQueue)

Returns the tick of the next `Event` to be dequeued (the earliest scheduled tick).
Only valid on a non-empty queue.
"""
function peektick(eq::EventQueue)
    _advance_head!(eq)
    return Int16(eq.head)
end

"""
    _insert!(queue::EventQueue, event, tick::Int16)

Inserts `event` into the bucket for `tick`, growing the bucket vector if needed and moving
`head` back for re-entrantly scheduled earlier ticks. `O(1)`. Dispatches on the event type
(individual vs setting). Not thread-safe on its own: callers either hold `queue.lock`
(`enqueue!`) or run single-threaded (`flush_staging!`).
"""
function _insert!(queue::EventQueue, event::IMeasureEvent, tick::Int16)
    idx = Int(tick) + 1
    while length(queue.i_buckets) < idx
        push!(queue.i_buckets, Vector{IMeasureEvent}())
    end
    push!(queue.i_buckets[idx], event)
    queue.count += 1
    # a re-entrantly scheduled event may target a tick below the current head
    Int(tick) < queue.head && (queue.head = Int(tick))
    return nothing
end

function _insert!(queue::EventQueue, event::SMeasureEvent, tick::Int16)
    idx = Int(tick) + 1
    while length(queue.s_buckets) < idx
        push!(queue.s_buckets, Vector{SMeasureEvent}())
    end
    push!(queue.s_buckets[idx], event)
    queue.count += 1
    Int(tick) < queue.head && (queue.head = Int(tick))
    return nothing
end

"""
    enqueue!(queue::EventQueue, event, tick::Int16)

Adds a new `Event` to the `EventQueue` at the specified `tick`. `O(1)`.
Thread-safe via `queue.lock`; see `stage!` for the lock-free variant.
"""
function enqueue!(queue::EventQueue, event, tick::Int16)
    lock(queue.lock)
    try
        _insert!(queue, event, tick)
    finally
        unlock(queue.lock)
    end
    return nothing
end

"""
    stage!(queue::EventQueue, event, tick::Int16)

Lock-free variant of `enqueue!` for use inside parallel loops: appends `event` and its
`tick` to the calling thread's staging buffer (selected by event type). Staged events
become visible only once `flush_staging!` merges them into the queue. `O(1)`.
"""
stage!(queue::EventQueue, event::IMeasureEvent, tick::Int16) =
    (push!(queue.i_staging[Threads.threadid()], (event, tick)); nothing)

stage!(queue::EventQueue, event::SMeasureEvent, tick::Int16) =
    (push!(queue.s_staging[Threads.threadid()], (event, tick)); nothing)

"""
    flush_staging!(queue::EventQueue)

Merges all per-thread staging buffers (filled by `stage!`) into the tick buckets and empties
them. Must be called single-threaded; takes no lock. Buffers are merged in thread-index order.
"""
function flush_staging!(queue::EventQueue)
    for buf in queue.i_staging
        for (event, tick) in buf
            _insert!(queue, event, tick)
        end
        empty!(buf)
    end
    for buf in queue.s_staging
        for (event, tick) in buf
            _insert!(queue, event, tick)
        end
        empty!(buf)
    end
    return nothing
end

"""
    dequeue!(queue::EventQueue)

Removes and returns the next `Event` of the `EventQueue`. Within a tick, setting events are
drained before individual events (each LIFO within its own bucket).
"""
function dequeue!(queue::EventQueue)
    _advance_head!(queue)
    idx = queue.head + 1
    if idx <= length(queue.s_buckets) && !isempty(queue.s_buckets[idx])
        event = pop!(queue.s_buckets[idx])
    else
        event = pop!(queue.i_buckets[idx])
    end
    queue.count -= 1
    return event
end

"""
    process_due!(queue::EventQueue, sim, t)

Drains and processes every event scheduled for a tick `<= t`, in tick order (setting events
before individual events within a tick, each LIFO). Used by `process_events!` instead of
`dequeue!`: draining the concretely-typed buckets directly keeps `process_event` statically
dispatched and avoids boxing each event into a `Union{IMeasureEvent, SMeasureEvent}` return.
Re-entrantly scheduled events (follow-ups) are picked up by the surrounding loop.
"""
function process_due!(queue::EventQueue, sim, t)
    _advance_head!(queue)
    while !isempty(queue) && queue.head <= t
        idx = queue.head + 1
        _drain_bucket!(queue.s_buckets, idx, queue, sim)
        _drain_bucket!(queue.i_buckets, idx, queue, sim)
        _advance_head!(queue)
    end
    return nothing
end

# drain one tick bucket (specialized per event type, so `pop!`/`process_event` are concrete)
@inline function _drain_bucket!(buckets, idx::Int, queue::EventQueue, sim)
    idx <= length(buckets) || return nothing
    b = buckets[idx]
    while !isempty(b)
        process_event(pop!(b), sim)
        queue.count -= 1
    end
    return nothing
end

"""
    empty!(queue::EventQueue)

Removes all `Event`s from the `EventQueue`, retaining bucket capacity.
"""
function Base.empty!(queue::EventQueue)
    for b in queue.i_buckets
        empty!(b)
    end
    for b in queue.s_buckets
        empty!(b)
    end
    for buf in queue.i_staging
        empty!(buf)
    end
    for buf in queue.s_staging
        empty!(buf)
    end
    queue.head = 0
    queue.count = 0
    return queue
end
