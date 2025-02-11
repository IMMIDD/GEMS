export CloseSetting

###
### STRUCT
###

"""
    CloseSetting <: SMeasure

Intervention struct to *close* a setting, effectively preventing
all contacts from happening during closure.

# Example

```julia
my_str = SStrategy("close-school", sim)
add_measure!(my_str, CloseSetting())
```

The above example creates an `SStrategy` called 'my\\_str' and adds
an instance of the `CloseSetting` measure which will *close* the respective
setting once called. You can, for example, use an `STickTrigger` to
close all schools at a given simulation time. The following code would
close all schools at tick 20:

```julia
stt = STickTrigger(SchoolClass, my_str, switch_tick = Int16(20))
add_tick_trigger!(sim, stt)
```
"""
struct CloseSetting <: SMeasure end


###
### PROCESS MEASURE
###


"""
    process_measure(sim::Simulation, s::Setting, close::CloseSetting)

Closes the passed setting `s` indefinitely, effectively preventing all contacts.

# Parameters

- `sim::Simulation`: Simulation object
- `s::Setting`: Setting that this measure will be applied to (focus setting)
- `close::CloseSetting`: Measure instance
"""
function process_measure(sim::Simulation, s::Setting, close::CloseSetting)
    
    #println("Close Setting $(s |> typeof) $(s |> id) at tick $(sim |> tick)")
    @debug "Close Setting $(s |> typeof) $(s |> id) at tick $(sim |> tick)"

    close!(s, sim)    
end
