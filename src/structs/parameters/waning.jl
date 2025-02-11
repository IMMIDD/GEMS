###
### WANINGSTRUCT (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export AbstractWaning, WaningFunction, DiscreteWaning
export duration, time_to_effectiveness

"Supertype for all Waning Structs"
abstract type AbstractWaning end


"""
    DiscreteWaning <: AbstractWaning

A type of waning. This waning considers the agent as completely immune
for a fixed duration and completely susceptible for the rest of the time.

# Fields
- `time_to_effectiveness::Int16`: Fixed time till the vaccine takes effect.
- `duration::Int16`: Fixed time for which the vaccine is effective.
"""
@with_kw mutable struct DiscreteWaning <: AbstractWaning
    time_to_effectiveness::Int16
    duration::Int16
end

### INTERFACE
"""
    time_to_effectiveness(waning)

Returns the time till it takes effect.
"""
function time_to_effectiveness(waning::DiscreteWaning)::Int16
    return waning.time_to_effectiveness
end

"""
    duration(waning)

Returns the effect duration.
"""
function duration(waning::DiscreteWaning)::Int16
    return waning.duration
end
