export EventQueue
export enqueue!, dequeue!, peek, first, isempty

# inspired by FastPriorityQueues package
# https://github.com/gdalle/FastPriorityQueues.jl/blob/main/src/sorted_vector.jl

###
### EVENT QUEUES
###


"""
    EventQueue
    
Data structure to store intervention events.
"""
@with_kw mutable struct EventQueue
    
    # internal priority queue
    pq::Vector{Pair{Event,Int16}} = Vector{Pair{Event,Int16}}[]

    # Parallelization
    lock::ReentrantLock = ReentrantLock()
end

"""
    length(eq::EventQueue)
    
Returns the number of `Event`s in the `EventQueue`.
"""
Base.length(eq::EventQueue) = length(eq.pq)

"""
    isempty(eq::EventQueue)
    
Returns true if the `EventQueue` is empty.
"""
Base.isempty(eq::EventQueue) = isempty(eq.pq)

"""
    first(eq::EventQueue)
    
Returns the first `Event` of the `EventQueue`.
"""
Base.first(eq::EventQueue) = first(eq.pq)

"""
    peek(eq::EventQueue)
    
Returns the first `Event` of the `EventQueue`.
"""
Base.peek(eq::EventQueue) = first(eq)

"""
    enqueue!(queue::EventQueue, event::Event, tick::Int16)
    
Adds a new `Event` to the `EventQueue` at the specified `tick`.
"""
function enqueue!(queue::EventQueue, event::Event, tick::Int16)
    lock(queue.lock) do
        # add event to the sorted event queue
        i = searchsortedfirst(queue.pq, tick; by=last)
        insert!(queue.pq, i, event => tick)
    end

    return nothing
end

"""
    dequeue!(queue::EventQueue)
    
Removes and returns the first `Event` of the `EventQueue`.
"""
function dequeue!(queue::EventQueue)
    event, _ = popfirst!(queue.pq)
    return event
end