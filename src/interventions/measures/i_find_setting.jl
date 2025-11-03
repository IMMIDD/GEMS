export FindSetting
export settingtype, follow_up

###
### STRUCT
###

"""
    FindSetting <: IMeasure

Intervention struct to detect a particular setting of an individual
and apply follow-up strategy to the respective setting. This 
measure effecively allows to switch between `IStrategy` and `SStrategy`. 

# Example

```julia
close_str = SStrategy("close-office", sim)
add_measure!(close_str, CloseSetting())

my_str = IStrategy("find-office", sim)
add_measure!(my_str, FindSetting(Office, close_str))

s_trigger = SymptomTrigger(my_str)
add_symptom_trigger!(sim, s_trigger) 
```

The above example first creates a setting strategy (`SStrategy`) called 'close\\_str'
and adds an instance of the `CloseSetting` measure which will close
the respective setting indefinitely if excuted. It then creates an
`IStrategy` called 'my\\_str' and adds an instance of the `FindSetting` measure
that detects the individual's office setting and calls the previously defined
'close\\_str' on it. Lastly, a `SymptomTrigger` is defined to run this cascade
of strategy once an individual experiences symptoms. The example will
close the office an individual is associated with if it experiences symptoms.
"""
struct FindSetting <: IMeasure
    settingtype::DataType
    follow_up::SStrategy
end

"""
    settingtype(fs::FindSetting)

Returns the `settingtype` attribute from a `FindSetting` struct. 
"""
function settingtype(fs::FindSetting)
    return(fs.settingtype)
end

"""
    follow_up(fs::FindSetting)

Returns the `follow_up` strategy attribute from a `FindSetting` struct. 
"""
function follow_up(fs::FindSetting)
    return(fs.follow_up)
end


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, ind::Individual, measure::FindSetting)

Detects a particular setting (specified by the `FindSetting` measure's `settingtype` attribute)
for an individual and hands over a `follow_up` strategy for the respective setting object.

# Parameters

- `sim::Simulation`: Simulation object
- `ind::Individual`: Individual that this measure will be applied to (focus individual)
- `measure::FindSetting`: Measure instance

# Returns

- `Handover`: Struct that contains the detected setting and the
    followup `SStrategy` defined in the input `FindSetting` measure.
"""
function process_measure(sim::Simulation, ind::Individual, measure::FindSetting)

    # setting type
    st = measure |> settingtype

    # setting object
    s = getsetting(ind, sim, st)

        @debug "Individual $(ind |> id) identifying $(string(st))[$sid] at tick $(sim |> tick)"

    # return setting
    return Handover(s, measure |> follow_up)
end