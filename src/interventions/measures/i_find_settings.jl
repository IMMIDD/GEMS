export FindSettings

###
### STRUCT
###

"""
    FindSettings <: IMeasure

Intervention struct to detect every setting of a particular type an individual belongs to and
apply a follow-up strategy to each of them. Where `FindSetting` acts on the individual's
primary setting of the type, this acts on all of them, e.g. every office of someone with two
jobs. A container type is found above each of those settings and handed over once.

# Example

```julia
close_str = SStrategy("close-office", sim)
add_measure!(close_str, CloseSetting())

my_str = IStrategy("find-offices", sim)
add_measure!(my_str, FindSettings(Office, close_str))
```

The above example closes every office the individual works in.
"""
struct FindSettings <: IMeasure
    settingtype::DataType
    follow_up::SStrategy
end

"""
    settingtype(fs::FindSettings)

Returns the `settingtype` attribute from a `FindSettings` struct.
"""
function settingtype(fs::FindSettings)
    return(fs.settingtype)
end

"""
    follow_up(fs::FindSettings)

Returns the `follow_up` strategy attribute from a `FindSettings` struct.
"""
function follow_up(fs::FindSettings)
    return(fs.follow_up)
end


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, ind::Individual, measure::FindSettings)

Hands the `follow_up` strategy to every setting of the measure's `settingtype` the individual
belongs to, each once.

# Parameters

- `sim::Simulation`: Simulation object
- `ind::Individual`: Individual that this measure will be applied to (focus individual)
- `measure::FindSettings`: Measure instance

# Returns

- `Nothing`: Triggers the `follow_up` strategy for each detected setting.
"""
function process_measure(sim::Simulation, ind::Individual, measure::FindSettings)
    single = FindSetting(measure |> settingtype, measure |> follow_up)
    for sid in setting_ids(ind, measure |> settingtype, sim)
        process_measure(sim, ind, single, sid)
    end
    return nothing
end
