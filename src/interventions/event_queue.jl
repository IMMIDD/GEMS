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
tick walks over its buckets, setting events before individual events (each FIFO).

A slot that has never been written to holds `nothing`; extending the outer array to reach a
new tick fills any intermediate gap with `nothing` instead of allocating placeholder vectors
that would never be used. A bucket vector is created the moment something is first inserted
into that tick, drawing from a free list (`i_free`/`s_free`) before allocating. Once a tick is
permanently empty (`_advance_head!` has stepped past it), its bucket is recycled onto the free
list and the slot reset to `nothing`; a slot still holding `nothing` needs no cleanup. Draining
(`_drain_bucket!`) leaves a tick's bucket in place rather than recycling it immediately, so
same-tick re-entrant follow-ups reuse it instead of orphaning it.
"""
mutable struct EventQueue <: AbstractEventQueue

    # i_buckets[t + 1] / s_buckets[t + 1] hold all individual/setting events for tick t, or
    # `nothing` if nothing has been scheduled for tick t (yet, or ever).
    i_buckets::Vector{Union{Nothing, Vector{IMeasureEvent}}}
    s_buckets::Vector{Union{Nothing, Vector{SMeasureEvent}}}

    # lowest tick whose buckets may still contain events; every tick below has been drained
    head::Int

    # total number of queued events (across both bucket arrays)
    count::Int

    # Recycled bucket vectors: retired buckets that were used are pushed here so their
    # allocated capacity can be reused for future tick slots
    i_free::Vector{Vector{IMeasureEvent}}
    s_free::Vector{Vector{SMeasureEvent}}
end

"""
    EventQueue()

Builds an empty `EventQueue`.
"""
EventQueue() = EventQueue(
    Union{Nothing, Vector{IMeasureEvent}}[],
    Union{Nothing, Vector{SMeasureEvent}}[],
    0,
    0,
    Vector{IMeasureEvent}[],
    Vector{SMeasureEvent}[]
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

# True if tick bucket `idx` (= tick + 1) is empty in both bucket arrays (or out of range, or
# was never written to and is still `nothing`).
@inline function _tick_empty(eq::EventQueue, idx::Int)
    s_bucket = idx <= length(eq.s_buckets) ? eq.s_buckets[idx] : nothing
    i_bucket = idx <= length(eq.i_buckets) ? eq.i_buckets[idx] : nothing
    return (s_bucket === nothing || isempty(s_bucket)) && (i_bucket === nothing || isempty(i_bucket))
end

# Recycles a passed tick's bucket onto the free list; nothing is scheduled before the current tick.
# The cap bounds the free list when more buckets are used than reused.
@inline function _retire_tick!(eq::EventQueue, idx::Int)
    if idx <= length(eq.i_buckets)
        b = eq.i_buckets[idx]
        if b !== nothing
            length(eq.i_free) < EVENT_QUEUE_FREE_LIST_CAP && push!(eq.i_free, b)
            eq.i_buckets[idx] = nothing
        end
    end
    if idx <= length(eq.s_buckets)
        b = eq.s_buckets[idx]
        if b !== nothing
            length(eq.s_free) < EVENT_QUEUE_FREE_LIST_CAP && push!(eq.s_free, b)
            eq.s_buckets[idx] = nothing
        end
    end
end

# Advance `head` over any leading empty ticks so it points at the earliest tick that still
# has events. Only ever moves `head` forward; safe to call repeatedly.
function _advance_head!(eq::EventQueue)
    n = max(length(eq.i_buckets), length(eq.s_buckets))
    while eq.head + 1 <= n && _tick_empty(eq, eq.head + 1)
        _retire_tick!(eq, eq.head + 1)
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
    s_bucket = idx <= length(eq.s_buckets) ? eq.s_buckets[idx] : nothing
    if s_bucket !== nothing && !isempty(s_bucket)
        return first(s_bucket)
    end
    return first(eq.i_buckets[idx])
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
    _has_due(queue::EventQueue, t)

Returns whether `queue` holds an event due at a tick `<= t`.
"""
_has_due(queue::EventQueue, t) = !isempty(queue) && peektick(queue) <= t

"""
    _insert!(queue::EventQueue, event, tick::Int16)

Inserts `event` into the bucket for `tick`, growing the bucket vector if needed and moving
`head` back if the target tick is below the current head. `O(1)`. Dispatches on the event
type (individual vs setting). Not thread-safe: a queue has one writer at a time.

Extending the array fills any intermediate gap with `nothing` (no allocation). The bucket for
`tick` is created here, on first insert, drawing from the free list before allocating so
capacity grown by earlier ticks is reused rather than abandoned. `head` is pulled back when an
event is inserted into a tick that `_advance_head!` has already passed.
"""
function _insert!(queue::EventQueue, event::IMeasureEvent, tick::Int16)
    idx = Int(tick) + 1
    while length(queue.i_buckets) < idx
        push!(queue.i_buckets, nothing)
    end
    b = queue.i_buckets[idx]
    if b === nothing
        b = isempty(queue.i_free) ? IMeasureEvent[] : pop!(queue.i_free)
        queue.i_buckets[idx] = b
    end
    push!(b, event)
    queue.count += 1
    Int(tick) < queue.head && (queue.head = Int(tick))
    return nothing
end

function _insert!(queue::EventQueue, event::SMeasureEvent, tick::Int16)
    idx = Int(tick) + 1
    while length(queue.s_buckets) < idx
        push!(queue.s_buckets, nothing)
    end
    b = queue.s_buckets[idx]
    if b === nothing
        b = isempty(queue.s_free) ? SMeasureEvent[] : pop!(queue.s_free)
        queue.s_buckets[idx] = b
    end
    push!(b, event)
    queue.count += 1
    Int(tick) < queue.head && (queue.head = Int(tick))
    return nothing
end

"""
    enqueue!(queue::EventQueue, event, tick::Int16)

Adds a new `Event` to the `EventQueue` at the specified `tick`. `O(1)`. Not thread-safe.
"""
function enqueue!(queue::EventQueue, event, tick::Int16)
    _insert!(queue, event, tick)
    return nothing
end

"""
    dequeue!(queue::EventQueue)

Removes and returns the next `Event` of the `EventQueue`. Within a tick, setting events are
drained before individual events (each FIFO within its own bucket).
"""
function dequeue!(queue::EventQueue)
    _advance_head!(queue)
    idx = queue.head + 1
    s_bucket = idx <= length(queue.s_buckets) ? queue.s_buckets[idx] : nothing
    if s_bucket !== nothing && !isempty(s_bucket)
        event = popfirst!(s_bucket)
    else
        event = popfirst!(queue.i_buckets[idx])
    end
    queue.count -= 1
    return event
end

"""
    process_due!(queue::EventQueue, sim, t)

Drains and processes every event scheduled for a tick `<= t`, in tick order (setting events
before individual events within a tick, each FIFO). Used by `process_events!` instead of
`dequeue!`: draining the concretely-typed buckets directly keeps `process_event` statically
dispatched and avoids boxing each event into a `Union{IMeasureEvent, SMeasureEvent}` return.
Re-entrantly scheduled events (follow-ups) are picked up by the surrounding loop. Buckets are
only recycled onto the free lists once `_advance_head!` retires a tick, not on every drain, so
re-entrant refills reuse the existing capacity instead of orphaning it.
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

# Drains one tick bucket in place; `where {E}` makes `pop!` and `process_event` static. The bucket stays
# in `buckets[idx]` until `_advance_head!` recycles it, so events added while draining reuse it.
@inline function _drain_bucket!(buckets::Vector{Union{Nothing, Vector{E}}}, idx::Int, queue::EventQueue, sim) where {E}
    idx <= length(buckets) || return nothing
    b = buckets[idx]
    (b === nothing || isempty(b)) && return nothing
    # FIFO: same-tick follow-ups pushed during processing are reached by the length check
    i = 1
    while i <= length(b)
        process_event(b[i], sim)
        queue.count -= 1
        i += 1
    end
    empty!(b)
    return nothing
end

"""
    empty!(queue::EventQueue)

Removes all `Event`s from the `EventQueue`, retaining bucket capacity for reuse.
Free-list vectors are already empty and are left ready for the next run.
"""
function Base.empty!(queue::EventQueue)
    for b in queue.i_buckets
        b !== nothing && empty!(b)
    end
    for b in queue.s_buckets
        b !== nothing && empty!(b)
    end
    queue.head = 0
    queue.count = 0
    return queue
end

# used by the phases of the parallel lane

"""
    _drain_individual_events!(queue::EventQueue, t, sim)

Processes the individual events scheduled for tick `t`, leaving the bucket in place as `_drain_bucket!` does.
"""
_drain_individual_events!(queue::EventQueue, t, sim) = _drain_bucket!(queue.i_buckets, Int(t) + 1, queue, sim)

"""
    _foreach_due_setting_bucket(f, queue::EventQueue, t)

Calls `f(bucket)` for every due bucket of a queue that holds only setting events, then empties the bucket.
"""
function _foreach_due_setting_bucket(f, queue::EventQueue, t)
    while _has_due(queue, t)
        bucket = queue.s_buckets[queue.head + 1]::Vector{SMeasureEvent}
        f(bucket)
        queue.count -= length(bucket)
        empty!(bucket)
    end
    return nothing
end
