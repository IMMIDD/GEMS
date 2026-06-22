export TimesUp, limit, evaluate


"""
    TimesUp <: StopCriterion

A `StopCriterion` that specifies a time limit.

# Fields
- `limit::Int16`: A time limit. When reached, the simulation should be terminated.

Ticks are stored as `Int16`, so `limit` (and the reachable tick range in general) cannot exceed
`typemax(Int16)` (32767)n
"""
struct TimesUp <: StopCriterion
    limit::Int16

    function TimesUp(;limit::Int)
        (1 <= limit <= typemax(Int16)) || throw(ArgumentError("TimesUp limit must be between 1 and $(typemax(Int16)) (ticks are Int16); got $limit."))
        new(Int16(limit))
    end
end

"""
    limit(timesUp::TimesUp)

Returns time limit of a timesUp stop criterion.
"""
function limit(timesUp::TimesUp)
    return timesUp.limit
end



### NECESSARY INTERFACE

"""
    evaluate(simulation::Simulation, criterion::TimesUp)

Returns true if specified termination tick has been met.
"""
function evaluate(simulation::Simulation, criterion::TimesUp)
    tick(simulation) >= limit(criterion)
end


