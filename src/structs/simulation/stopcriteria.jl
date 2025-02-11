###
### TIMESUP (TYPE DEFINITION & BASIC FUNCTIONALITY)
###

### EXPORTS
export limit
export evaluate
export NoneInfected, TimesUp
export parameters



"""
    parameters(criterion::NoneInfected)

Fallback parameters function for the `StopCriterion`.
"""
function parameters(criterion::StopCriterion)
    return Dict("type" => typeof(criterion) |> string)
end

"""
    TimesUp <: StopCriterion

A `StopCriterion` that specifies a time limit.

# Fields
- `limit::Int16`: A time limit. When reached, the simulation should be terminated.
"""
struct TimesUp <: StopCriterion
    # TODO throw exception when intialized with negative values
    limit::Int16
end

"""
    limit(timesUp)

Returns time limit of a timesUp stop criterion.
"""
function limit(timesUp::TimesUp)
    return timesUp.limit
end

### NECESSARY INTERFACE
"""
    evaluate(simulation, criterion)

Returns true if specified termination tick has been met.
"""
function evaluate(simulation::Simulation, criterion::TimesUp)
    tick(simulation) >= limit(criterion)
end

"""
    parameters(criterion::TimesUp)

Returns a dictionary with the type and limit of the `criterion`.
"""
function parameters(criterion::TimesUp)
    return Dict("type" => "TimesUp",
                "limit" => limit(criterion))
end

"""
    NoneInfected <: StopCriterion

A `StopCriterion` that stops the simulation once no individual is infected.
"""
struct NoneInfected <: StopCriterion
end

### NECESSARY INTERFACE
"""
    evaluate(simulation, criterion)

Returns true if none of the individuals are infected.
"""
function evaluate(simulation::Simulation, criterion::NoneInfected)
    valid = true
    Threads.@threads for i in (simulation |> population |> individuals)
        if infected(i)
            return valid = false
        end
    end
    return valid
end

"""
    parameters(criterion::NoneInfected)

Returns a dictionary with the type of the `NoneInfected` stop criterion.
"""
function parameters(criterion::NoneInfected)
    return Dict("type" => "NoneInfected")
end