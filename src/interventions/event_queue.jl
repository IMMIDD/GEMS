export EventQueue
export enqueue!, dequeue!, peek, peektick, isempty
export stage!, flush_staging!

###
### EVENT QUEUES
###


"""
    EventQueue

Tick-bucketed ("calendar") queue for intervention events.

Events are scheduled for a specific (integer) tick and always at a tick `>=` the
current one, and the queue is drained in tick order. Events are stored in 
per-tick buckets: `buckets[t + 1]` holds every event scheduled for tick `t`. 
`enqueue!` is then an `O(1)` `push!` into the relevant bucket, and draining a
tick is a pop over its bucket.
"""
@with_kw mutable struct EventQueue

    # buckets[t + 1] holds all events scheduled for tick t (ticks are 0-based).
    buckets::Vector{Vector{Event}} = Vector{Event}[]

    # lowest tick whose bucket may still contain events; every tick below this has been fully drained
    head::Int = 0

    # total number of queued events
    count::Int = 0

    # Parallelization
    lock::ReentrantLock = ReentrantLock()

    # Per-thread, lock-free staging buffers. 
    staging::Vector{Vector{Tuple{Event, Int16}}} = [Tuple{Event, Int16}[] for _ in 1:Threads.maxthreadid()]
end

"""
    length(eq::EventQueue)

Returns the number of `Event`s in the `EventQueue`.
"""
Base.length(eq::EventQueue) = eq.count

"""
    isempty(eq::EventQueue)

Returns true if the `EventQueue` is empty.
"""
Base.isempty(eq::EventQueue) = eq.count == 0

# Advance `head` over any leading empty buckets so it points at the earliest tick
# that still has events. Only ever moves `head` forward; safe to call repeatedly.
function _advance_head!(eq::EventQueue)
    n = length(eq.buckets)
    while eq.head + 1 <= n && isempty(eq.buckets[eq.head + 1])
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
    return last(eq.buckets[eq.head + 1])
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
    _insert!(queue::EventQueue, event::Event, tick::Int16)

Inserts `event` into the bucket for `tick`, growing the bucket vector if needed and moving
`head` back for re-entrantly scheduled earlier ticks. `O(1)`. Not thread-safe on its own:
callers either hold `queue.lock` (`enqueue!`) or run single-threaded (`flush_staging!`).
"""
function _insert!(queue::EventQueue, event::Event, tick::Int16)
    idx = Int(tick) + 1
    # grow the bucket vector if this tick is beyond the current horizon
    while length(queue.buckets) < idx
        push!(queue.buckets, Vector{Event}())
    end
    push!(queue.buckets[idx], event)
    queue.count += 1
    # a re-entrantly scheduled event may target a tick below the current head
    # (e.g. a follow-up at offset 0 while that bucket is being drained)
    if Int(tick) < queue.head
        queue.head = Int(tick)
    end
    return nothing
end

"""
    enqueue!(queue::EventQueue, event::Event, tick::Int16)

Adds a new `Event` to the `EventQueue` at the specified `tick`. `O(1)`.
Thread-safe via `queue.lock`; see `stage!` for the lock-free variant.
"""
function enqueue!(queue::EventQueue, event::Event, tick::Int16)
    lock(queue.lock)
    try
        _insert!(queue, event, tick)
    finally
        unlock(queue.lock)
    end
    return nothing
end

"""
    stage!(queue::EventQueue, event::Event, tick::Int16)

Lock-free variant of `enqueue!` for use inside parallel loops: appends `event` and its
`tick` to the calling thread's staging buffer. Staged events become visible only once
`flush_staging!` merges them into the queue. `O(1)`.
"""
function stage!(queue::EventQueue, event::Event, tick::Int16)
    push!(queue.staging[Threads.threadid()], (event, tick))
    return nothing
end

"""
    flush_staging!(queue::EventQueue)

Merges all per-thread staging buffers (filled by `stage!`) into the tick buckets and empties
them. Must be called single-threaded; takes no lock. Buffers are merged in thread-index order.
"""
function flush_staging!(queue::EventQueue)
    for buf in queue.staging
        for (event, tick) in buf
            _insert!(queue, event, tick)
        end
        empty!(buf)
    end
    return nothing
end

"""
    dequeue!(queue::EventQueue)

Removes and returns the next `Event` of the `EventQueue`.
"""
function dequeue!(queue::EventQueue)
    _advance_head!(queue)
    event = pop!(queue.buckets[queue.head + 1])
    queue.count -= 1
    return event
end

"""
    empty!(queue::EventQueue)

Removes all `Event`s from the `EventQueue`, retaining bucket capacity.
"""
function Base.empty!(queue::EventQueue)
    for b in queue.buckets
        empty!(b)
    end
    for buf in queue.staging
        empty!(buf)
    end
    queue.head = 0
    queue.count = 0
    return queue
end
