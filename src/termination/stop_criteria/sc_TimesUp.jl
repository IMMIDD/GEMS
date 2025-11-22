export TimesUp, limit, evaluate


"""
    TimesUp <: StopCriterion

A `StopCriterion` that specifies a time limit.

# Fields
- `limit::Int16`: A time limit. When reached, the simulation should be terminated.
"""
struct TimesUp <: StopCriterion
    limit::Int16

    function TimesUp(;limit::Int) 
        limit <= 0 && throw(ArgumentError("TimesUp must be 1 or larger!"))
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


