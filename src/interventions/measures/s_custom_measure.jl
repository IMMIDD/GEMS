export CustomSMeasure, measure_logic

###
### STRUCT
###

"""
    CustomSMeasure <: SMeasure

Intervention struct to apply custom logic to a setting when this measure is executed.
The field `measure_logic` must contain a two-argument function where the first argument
is a `Setting` and the second argument is the `Simulation` struct.
Upon execution of the measure, this function will be called with these two arguments.

# Example

```julia
my_str = SStrategy("close-large-settings", sim)
add_measure!(my_str, CustomSMeasure((s, simobj) -> (size(s) > 50 ? close!(s) : nothing)))
```

The above example creates an `SStrategy` called 'my\\_str' and adds
an instance of the `CustomSMeasure` measure that is being instantiated with a
function closing the setting if it contains more than 50 individuals. While the above
example does not require the `Simulation` object, it is still being passed,
to make the whole simulation state available at all times. The example above
contains conditioned logic to demonstrate how the `CustomSMeasure` works. You can,
of course, achieve the same effect as in the example, if you use a regular `CloseSetting`
measure and limit its execution to large settings by supplying the `condition` keyword
to the `add_measure!` function.
"""
struct CustomSMeasure <: SMeasure 
    measure_logic::Function
end

"""
    measure_logic(measure::CustomSMeasure)

Returns the `measure_logic` (function) attribute from a `CustomSMeasure` struct. 
"""
function measure_logic(measure::CustomSMeasure)
    return(measure.measure_logic)
end

###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, s::Setting, custom::CustomSMeasure)

Applies a custom logic to the setting as specified in the `CustomSMeasure`'s `measure_logic` field.

# Parameters

- `sim::Simulation`: Simulation object
- `s::Setting`: Setting that this measure will be applied to (focus setting)
- `custom::CustomSMeasure`: Measure instance
"""
function process_measure(sim::Simulation, s::Setting, custom::CustomSMeasure)

    @debug "Custom measure applied to setting $(s |> typeof) $(s |> id) at tick $(sim |> tick)"

    # execute custom logic
    measure_logic(custom)(s, sim)
end
