export IsOpen
export positive_followup, negative_followup

###
### STRUCT
###

"""
    IsOpen <: SMeasure

Intervention struct to differentiate follow-up setting strategies
for currently open or currently closed settings. You can pass
a `positive_followup`- or a `negative_followup` stategy via
the respective optional arguments.

# Example

```julia
isolate_str = IStrategy("self-isolation", sim)
add_measure!(isolate_str, SelfIsolation(14))

find_coworkers_str = SStrategy("find-coworkers", sim)
add_measure!(find_coworkers_str, FindMembers(isolate_str))

my_str = SStrategy("is-open?", sim)
add_measure!(my_str, IsOpen(positive_followup = find_coworkers_str)))
```

The above example first creates an individual strategy (`IStrategy`) called 'isolate\\_str'
and adds an instance of the `SelfIsolation` measure which will send 
the respective individual in self-isolation if excuted. It then creates an
`SStrategy` called 'find\\_coworkers\\_str' and adds an instance of the `FindMembers` measure
that detects the setting's members and calls the previously defined
'isolate\\_str' on all of them. We now only want to send all co-workers,
if the setting is open (and thus might have induced infectious conctacts).
Therefore, another `SStrategy` called 'my\\_str' is instantiated and an
instance of the `IsOpen` measure is added with the 'find\\_coworkers\\_str'
strategy being the positive follow-up.
"""
struct IsOpen <: SMeasure
    positive_followup::Union{SStrategy, Nothing}
    negative_followup::Union{SStrategy, Nothing}

    function IsOpen(;
        positive_followup::Union{SStrategy, Nothing} = nothing,
        negative_followup::Union{SStrategy, Nothing} = nothing)

        isnothing(positive_followup) && isnothing(negative_followup) ? throw("At least one follow-up strategy is required to instantiate the 'IsOpen' measure") : nothing
        return new(positive_followup, negative_followup)
    end
end

"""
    positive_followup(t::IsOpen)

Returns the `positive_followup` strategy attribute of an `IsOpen` measure struct.
"""
function positive_followup(t::IsOpen)
    return(t.positive_followup)
end

"""
    negative_followup(t::IsOpen)

Returns the `negative_followup` strategy attribute of an `IsOpen` measure struct.
"""
function negative_followup(t::IsOpen)
    return(t.negative_followup)
end


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, s::Setting, measure::IsOpen)

Evaluates whether the setting `s` is currently *open* and hands over
the respective follow-up strategies as specified in the `IsOpen` measure.

# Parameters

- `sim::Simulation`: Simulation object
- `s::Setting`: Setting that this measure will be applied to (focus setting)
- `measure::IsOpen`: Measure instance

# Returns

- `Handover`: Struct that contains the focus setting (`s`) and the respective 
    followup `SStrategy` defined in the input `IsOpen` measure depending
    on whether the setting is open or closed.
"""
function process_measure(sim::Simulation, s::Setting, measure::IsOpen)

    @debug "Testing if Setting $(s |> typeof) $(s |> id) is open ($(is_open(s)) at tick $(sim |> tick)"

    return Handover(s, is_open(s) ?  measure |> positive_followup : measure |> negative_followup)
end