export SelfIsolation
export duration

###
### STRUCT
###

"""
    SelfIsolation <: IMeasure

Intervention struct to put an individual into self-isolation
(household isolation) for the time (in ticks) specified in `duration`

# Example

```julia
my_str = IStrategy("self-isolation", sim)
add_measure!(my_str, SelfIsolation(14))
```

The above example creates an `IStrategy` called 'my_str' and adds
an instance of the `SelfIsolation` measure that should last for 14 days
to the strategy.
"""
struct SelfIsolation <: IMeasure
    duration::Int16
end

"""
    duration(si::SelfIsolation)

Returns the `duration` attribute from a `SelfIsolation` struct. 
"""
function duration(si::SelfIsolation)
    return(si.duration)
end


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, ind::Individual, isolation::SelfIsolation)

Puts an individual into self-isolation (household isolation) for the time (in ticks)
specified in the `SelfIsolation`'s `duration` attribute.

# Parameters

- `sim::Simulation`: Simulation object
- `ind::Individual`: Individual that this measure will be applied to (focus individual)
- `isolation::SelfIsolation`: Measure instance
"""
function process_measure(sim::Simulation, ind::Individual, isolation::SelfIsolation)
    
    t = sim |> tick
    d = isolation |> duration

    @debug "Individual $(ind |> id) going into isolation for $d ticks at tick $t"

    # set start and end of isolation
    quarantine_tick!(ind, t)
    quarantine_release_tick!(ind, Int16(t + d))
end