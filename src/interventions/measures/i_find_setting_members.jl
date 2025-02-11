export FindSettingMembers
export settingtype, follow_up

###
### STRUCT
###

"""
    FindSettingMembers <: IMeasure

Intervention struct that returns members of a setting which is associated
with an index-individual, e.g., 'People I know at work'. It requires
a `settingtype`, defining which of the individual's settings shall be 
quieried, as well as a `follow_up` `IStrategy` that will be applied to all
found setting members. An optional `nonself` boolean flag indicates
whether this measure shall also return the index individual. 

# Examples

```julia
my_str = IStrategy("identify-household-members", sim)
add_measure!(my_str, FindSettingMembers(Household, my_other_strategy, nonself = true))
```

The above example creates an `IStrategy` called 'my\\_str' and adds
an instance of the `FindSettingMembers` measure that should return all household
members *except* the index individual (all people that the individual lives with).
It will trigger the follow-up strategy 'my\\_other\\_strategy' for all members.

```julia
my_str = IStrategy("identify-household-members", sim)
add_measure!(my_str, FindSettingMembers(Office, my_other_strategy))
```

The above example creates an `IStrategy` called 'my\\_str' and adds
an instance of the `FindSettingMembers` measure that should return all Office
members *including* the index individual. It will trigger the follow-up strategy
'my\\_other\\_strategy' for everyone in that office.

"""
struct FindSettingMembers <: IMeasure
    settingtype::DataType
    follow_up::IStrategy
    nonself::Bool # flag whether measure should returning focal individual or only everyone else

    function FindSettingMembers(settingtype::DataType, follow_up::IStrategy;
        nonself::Bool = false)
        return(new(settingtype, follow_up, nonself))
    end
end

"""
    settingtype(fsm::FindSettingMembers)

Returns the `settingtype` attribute from a `FindSettingMembers` struct. 
"""
function settingtype(fsm::FindSettingMembers)
    return(fsm.settingtype)
end

"""
    follow_up(fsm::FindSettingMembers)

Returns the `follow_up` strategy attribute from a `FindSettingMembers` struct. 
"""
function follow_up(fsm::FindSettingMembers)
    return(fsm.follow_up)
end

"""
    nonself(fsm::FindSettingMembers)

Returns the `nonself` strategy attribute from a `FindSettingMembers` struct. 
"""
function nonself(fsm::FindSettingMembers)
    return(fsm.nonself)
end

###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, ind::Individual, measure::FindSettingMembers)

Finds all members of one of the settings an individual is associated with. the measure's 
field `settingtype` specifies which kind of setting shall be queried, the `nonself` 
boolean flag indicates whether the index individual shall be among the returning members.
The `follow_up` strategy is handed over to all found members (and enqueued in the
`EventQueue` in a subsequent step)

# Parameters

- `sim::Simulation`: Simulation object
- `ind::Individual`: Individual that this measure will be applied to (focus individual)
- `measure::FindSettingMembers`: Measure instance

# Returns

- `Handover`: Struct that contains the list of detected setting members and the
    followup `IStrategy` defined in the input `FindSettingMemers` measure.
"""
function process_measure(sim::Simulation, ind::Individual, measure::FindSettingMembers)

    # setting type
    st = measure |> settingtype

    # setting id
    sid = setting_id(ind, st)

    # setting object
    s = sim |> settingscontainer |>
        x -> setting(x, st, sid)

    @debug "Individual $(ind |> id) identiying $(settingchar(s)) contacts $(map(x -> GEMS.id(x), [i for i in individuals(s) if i != ind])) at tick $(sim |> tick)"

    # return all individuals and filter out focal individual if nonself flag is set
    return Handover(nonself(measure) ? filter(x -> x != ind, individuals(s, sim)) : individuals(s, sim), measure |> follow_up)
end