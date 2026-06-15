export EventQueue
export enqueue!, dequeue!, peek, peektick, isempty

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
    enqueue!(queue::EventQueue, event::Event, tick::Int16)

Adds a new `Event` to the `EventQueue` at the specified `tick`. `O(1)`.
"""
function enqueue!(queue::EventQueue, event::Event, tick::Int16)
    idx = Int(tick) + 1
    lock(queue.lock)
    try
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
    finally
        unlock(queue.lock)
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
    queue.head = 0
    queue.count = 0
    return queue
end
