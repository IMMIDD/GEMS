export TraceInfectiousContacts
export success_rate, follow_up

###
### STRUCT
###

"""
    TraceInfectiousContacts <: IMeasure

Intervention struct to trace individuals that have been 
infected by the index individual, this measure is called with.
The `follow_up` argument provides an `IStrategy` that is being
exceuted for all detected contacts. The optional `success_rate` (0-1) argument
can be used to model sub-perfect tracing (the default is 100%).

# Example

```julia
my_str = IStrategy("contact-tracing", sim)
add_measure!(my_str, TraceInfectiousContacts(my_other_str, success_rate = 0.5))
```

The above example creates an `IStrategy` called 'my\\_str' and adds
an instance of the `TraceInfectiousContacts` measure that will trigger
the 'my\\_other\\_str' for all detected infections. The `success_rate` is 50%.
"""
struct TraceInfectiousContacts <: IMeasure
    success_rate::Float64
    follow_up::IStrategy

    function TraceInfectiousContacts(follow_up::IStrategy; success_rate::Real = 1.0)
        if !(0 <= success_rate <= 1)
            throw("success_rate parameter must be between 0 and 1")
        end
        
        return(new(success_rate, follow_up))
    end
end

"""
    success_rate(tic::TraceInfectiousContacts)

Returns the `success_rate` attribute from a `TraceInfectiousContacts` struct. 
"""
function success_rate(tic::TraceInfectiousContacts)
    return(tic.success_rate)
end

"""
    follow_up(tic::TraceInfectiousContacts)

Returns the `follow_up` strategy attribute from a `TraceInfectiousContacts` struct. 
"""
function follow_up(tic::TraceInfectiousContacts)
    return(tic.follow_up)
end


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, ind::Individual, measure::TraceInfectiousContacts)

Detects individuals that have been infected by the index individual. The `TraceInfectiousContacts` measure's
`success_rate` argument can be used to model sub-perfect tracing (the default is 100%).
The `follow_up` strategy of the `TraceInfectiousContacts` measure is handed over to all detected contacts.

# Parameters

- `sim::Simulation`: Simulation object
- `ind::Individual`: Individual that this measure will be applied to (focus individual)
- `measure::TraceInfectiousContacts`: Measure instance

# Returns

- `Handover`: Struct that contains the list of detected infectious individuals and the
    followup `IStrategy` defined in the input `TraceInfectiousContacts` measure.
"""
function process_measure(sim::Simulation, ind::Individual, measure::TraceInfectiousContacts)

    now = sim |> tick
    infectious_at = ind |> infectious_tick
    sr = measure |> success_rate

    # get infectee IDs from logger
    infectee_ids = get_infections_between(sim  |> infectionlogger, ind |> id, infectious_at, now)

    # filter by success_rate
    infectee_ids = infectee_ids[rand(rng(sim), infectee_ids |> length) .< sr]

    @debug "Individual $(ind |> id) identiying $(infectee_ids |> length) infectious contacts between tick $infectious_at and $now: $infectee_ids at tick $(sim |> tick)"

    # return "nothing" default, if list is empty
    if infectee_ids |> length == 0
        return(nothing)
    end

    # return all individuals extracted from IDs
    return Handover([get_individual_by_id(sim |> population, i) for i in infectee_ids], measure |> follow_up)
end