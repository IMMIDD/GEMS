export OpenSetting

###
### STRUCT
###

"""
    OpenSetting <: SMeasure

Intervention struct to *open* a setting, effectively re-enabling
the setting and allow contacts.

# Example

```julia
my_str = SStrategy("reopen-school", sim)
add_measure!(my_str, OpenSetting())
```

The above example creates an `SStrategy` called 'my\\_str' and adds
an instance of the `OpenSetting` measure which will *open* the respective
setting once called. You can, for example, use an `STickTrigger` to
reopen all schools at a given simulation time (after they were closed earlier).
The following code would open all schools at tick 20:

```julia
stt = STickTrigger(SchoolClass, my_str, switch_tick = Int16(20))
add_tick_trigger!(sim, stt)
```
"""
struct OpenSetting <: SMeasure end


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, s::Setting, close::OpenSetting)

(Re-)Opens the passed setting `s` indefinitely, again allowing contacts to happen.

# Parameters

- `sim::Simulation`: Simulation object
- `s::Setting`: Setting that this measure will be applied to (focus setting)
- `close::OpenSetting`: Measure instance
"""
function process_measure(sim::Simulation, s::Setting, close::OpenSetting)
    
    #println("Open Setting $(s |> typeof) $(s |> id) at tick $(sim |> tick)")
    @debug "Open Setting $(s |> typeof) $(s |> id) at tick $(sim |> tick)"

    open!(s, sim)    
end
