export CancelSelfIsolation

###
### STRUCT
###

"""
    CancelSelfIsolation <: IMeasure

Intervention struct to cancel an individual's (household isolation).

# Example

```julia
my_str = IStrategy("cancel-isolation", sim)
add_measure!(my_str, CancelSelfIsolaton())
```

The above example creates an `IStrategy` called 'my_str' and adds
an instance of the `CancelSelfIsolation` measure to the strategy.
"""
struct CancelSelfIsolation <: IMeasure end


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, ind::Individual, cancel::CancelSelfIsolation)

Cancels an individuals self-isolation (household isolation) by setting the
individual's `quarantine_release_tick` to 'now'.

# Parameters

- `sim::Simulation`: Simulation object
- `ind::Individual`: Individual that this measure will be applied to (focus individual)
- `cancel::CancelSelfIsolation`: Measure instance
"""
function process_measure(sim::Simulation, ind::Individual, cancel::CancelSelfIsolation)
    
    t = sim |> tick

    @debug "Individual $(ind |> id) $(ind |> infected ? "(inf)" : "") leaving isolation at tick $t"

    # set release tick to now; remove quarantine starting tick to prevent triggering another indefinite quarantine
    quarantine_release_tick!(ind, t)
    quarantine_tick!(ind, DEFAULT_TICK)
end
