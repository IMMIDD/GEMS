export FindMembers
export sample_size, sample_fraction, condition, follow_up, selectionfilter

###
### STRUCT
###

"""
    FindMembers <: SMeasure

Intervention struct to detect individuals that are associated with a setting
and apply a follow-up strategy to the respective individuals. This 
measure effecively allows to switch between `SStrategy` and `IStrategy`.

# Optional Arguments
- `sample_size::Int64`: Limiting the number of individuals to an integer maximum
- `sample_fraction::Float64`: Limiting the number of individuals to a fraction of the overall assigned members. Must be between (0-1)
- `selectionfilter::Function`: Filters individuals based on their characteristics

# Example

```julia
isolate_str = IStrategy("self-isolation", sim)
add_measure!(isolate_str, SelfIsolation(14))

my_str = SStrategy("find-coworkers", sim)
add_measure!(my_str, FindMembers(isolate_str))
```

The above example first creates an individual strategy (`IStrategy`) called 'isolate\\_str'
and adds an instance of the `SelfIsolation` measure which will send 
the respective individual in self-isolation if excuted. It then creates an
`SStrategy` called 'my\\_str' and adds an instance of the `FindMembers` measure
that detects the setting's members and calls the previously defined
'isolate\\_str' on all of them. This mechanism can, for example, be used
to send all individuals in self-isolation who are associated with a particular office
(maybe beause a symptomatic case was detected).

The `FindMembers` struct can also be used to sample a subset of individuals from a setting.
During the COVID-19 pandemic, many restaurants required a negative antigen test in 
order to serve customers. From a modeling perspective, this is a case where the
`Test`-measure is not triggered by surrounding infection dynamics, but rather randomly.
The `FindMembers` measure can be used to represent these mechanics:

```julia
FindMembers(my_follow_up_str, sample_size = 5)
```

The above measure will always apply the 'my\\_follow\\_up\\_str'
to exactly 5 individuals sampled from the setting.

```julia
FindMembers(my_follow_up_str, sample_fraction = 0.01)
```

This measure will apply the 'my\\_follow\\_up\\_str'
to 1% of the members in the setting. It can be used to randomly 
draw individuals, e.g., from a geographic region (`Municipality`).

```julia
FindMembers(my_follow_up_str, selectionfilter = i -> age(i) >= 65)
```

This measure will apply the 'my\\_follow\\_up\\_str' only 
to individuals of the setting who are 65 years or older. The filter
is always applied before the `sample_size` or `sample_fraction`.
"""
_select_all(::Individual) = true

struct FindMembers <: SMeasure
    follow_up::IStrategy

    sample_size::Int64
    sample_fraction::Float64
    selectionfilter::IPredicate
    has_filter::Bool


    function FindMembers(follow_up::IStrategy;
        sample_size::Int64 = -1, sample_fraction::Float64 = 1.0, selectionfilter::Function = _select_all)

        if sample_size < -1
            throw(ArgumentError("The sample_size for the FindMembers()-measure must be a positive integer."))
        end

        if !(0 <= sample_fraction <= 1)
            throw(ArgumentError("The sample_fraction for the FindMembers()-measure must be between 0 and 1."))
        end

        if sample_size != -1 && sample_fraction != 1.0
            throw(ArgumentError("Please provide either a sample_size or a sample_fraction. Both don't go together."))
        end

        return(
            new(follow_up, sample_size, sample_fraction, IPredicate(selectionfilter), selectionfilter !== _select_all)
        )
    end

end

"""
    sample_size(fs::FindMembers)

Returns the `sample_size` attribute of a `FindMembers` measure struct.
"""
function sample_size(fs::FindMembers)
    return(fs.sample_size)
end

"""
    sample_fraction(fs::FindMembers)

Returns the `sample_fraction` attribute of a `FindMembers` measure struct.
"""
function sample_fraction(fs::FindMembers)
    return(fs.sample_fraction)
end

"""
    selectionfilter(fs::FindMembers)

Returns the `selectionfilter` attribute of a `FindMembers` measure struct.
"""
function selectionfilter(fs::FindMembers)
    return(fs.selectionfilter)
end

"""
    has_filter(fs::FindMembers)

Returns whether a custom `selectionfilter` was provided to the `FindMembers` measure.
"""
function has_filter(fs::FindMembers)
    return(fs.has_filter)
end

"""
    follow_up(fs::FindMembers)

Returns the `follow_up` strategy attribute of a `FindMembers` measure struct.
"""
function follow_up(fs::FindMembers)
    return(fs.follow_up)
end




###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, s::Setting, measure::FindMembers)

Returns the individuals (members) associated with setting `s` and hands over the 
`follow_up` strategy as specified in the `FindMembers` measure. The `sample_size`,
`sample_fraction`, and `selectionfilter` attributes of the `FindMembers` measure
can be used to condition or limit the results.

# Parameters

- `sim::Simulation`: Simulation object
- `s::Setting`: Setting that this measure will be applied to (focus setting)
- `measure::FindMembers`: Measure instance

# Returns

- `Nothing`: Triggers the `follow_up` strategy for each found member (or sampled subset).
"""
function process_measure(sim::Simulation, s::Setting, measure::FindMembers)

    INTERVENTION_DEBUG && @debug "Identifying members of setting $(string(typeof(s)))[$(id(s))] at tick $(sim |> tick)"

    members = individuals(s)
    if has_filter(measure)
        members = filter(selectionfilter(measure), members)
    end

    fu = measure |> follow_up

    # trigger the follow-up for the requested members: a sample of size "sample_size",
    # a sample of size "sample_fraction * length", or all members
    if sample_size(measure) >= 0
        apply_followup!(sim, sample_individuals(members, sample_size(measure), rng=rng(sim)), fu)
    elseif sample_fraction(measure) < 1
        apply_followup!(sim, sample_individuals(members, Int64(ceil((length(members) * sample_fraction(measure)))), rng=rng(sim)), fu)
    else
        apply_followup!(sim, members, fu)
    end
    return nothing
end