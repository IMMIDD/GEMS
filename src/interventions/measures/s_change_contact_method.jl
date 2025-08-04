export ChangeContactMethod
export sampling_method

###
### STRUCT
###

"""
    ChangeContactMethod <: SMeasure

Intervention struct to replace a setting's contact sampling method.
Needs to be initialized with an argument of type `ContactSamplingMethod`.

# Example

```julia
    my_str = SStrategy("reduce-contacts", sim)
    add_measure!(my_str, ChangeContactMethod(ContactparameterSampling(1)))
```

The above example creates an `SStrategy` called 'my\\_str' and adds
an instance of the `ChangeContactMethod` measure that should change the
contact sampling method to a `ContactparameterSampling` method with 
1 contact per tick. We call this strategy 'reduce-contacts', of course assuming that
the previous contact sampling methdod generated more contacts per tick
(which of course depends on your particular initial configuration)
"""
struct ChangeContactMethod <: SMeasure
    sampling_method::ContactSamplingMethod
end


"""
    sampling_method(measure::ChangeContactMethod)

Returns the `sampling_method` attribute from a `ChangeContactMethod` struct. 
"""
function sampling_method(measure::ChangeContactMethod)
    return(measure.sampling_method)
end


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, s::Setting, measure::ChangeContactMethod)

Replaces the contact sampling method in the setting that was passed with a
new sampling method specified in the `ChangeContactMethod` measure.

# Parameters

- `sim::Simulation`: Simulation object
- `s::Setting`: Setting that this measure will be applied to (focus setting)
- `measure::ChangeContactMethod`: Measure instance
"""
function process_measure(sim::Simulation, s::Setting, measure::ChangeContactMethod)

    @debug "Update contact sampling method of $(s |> typeof) $(s |> id) from $(s |> contact_sampling_method) to $(measure |> sampling_method) at tick $(sim |> tick)"

    # update contact method
    contact_sampling_method!(s, measure |> sampling_method)
end