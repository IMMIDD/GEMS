export TraceSourceContacts
export lookback

###
### STRUCT
###

"""
    TraceSourceContacts <: IMeasure

Intervention struct for backward contact tracing: traces the individual who infected the
index individual, if that infection happened within the last `lookback` ticks and before
the index became infectious. Without an active infection, the index's newest infection,
which has ended, is used. The `follow_up` argument provides an `IStrategy` that is being
executed for all detected contacts. The optional `success_rate` (0-1) models sub-perfect
tracing; it can also be a function of the days since the contact that returns the probability (0-1).

# Example

```julia
siblings = IStrategy("trace-siblings", sim)
add_measure!(siblings, TraceInfectiousContacts(my_other_str))

my_str = IStrategy("backward-tracing", sim)
add_measure!(my_str, TraceSourceContacts(siblings, lookback = 14))
```

The above example traces the source of the index's infection and then everyone the source
infected (the index's 'siblings'), triggering 'my\\_other\\_str' for each of them.

With `resample_contacts = true`, non-infected contacts from the same window are traced as well.
They are re-drawn from the index's settings of the given `settingtypes` (default: `Household`,
`Office`, `SchoolClass`) using today's memberships, so they are a plausible set, not the contacts
drawn during the run. A `contact_filter(setting, tick)` returning `false` skips re-drawing in that
setting at that tick, e.g. to leave out a past school closure.

The optional `max_contacts` caps how many contacts the index names; a random subset of that size is
picked before the `success_rate` draws (default: no cap).
"""
struct TraceSourceContacts <: IMeasure
    success_rate::Union{Float64, TraceRateFn}
    follow_up::IStrategy
    lookback::Int16
    resample_contacts::Bool
    settingtypes::Vector{DataType}
    contact_filter::ContactFilterFn
    max_contacts::Int

    function TraceSourceContacts(follow_up::IStrategy; success_rate::Union{Real, Function} = 1.0,
            lookback::Integer = 14, resample_contacts::Bool = false,
            settingtypes::Vector{DataType} = DataType[Household, Office, SchoolClass],
            contact_filter::Function = (setting, tick) -> true, max_contacts::Integer = typemax(Int))
        if lookback < 0
            throw(ArgumentError("lookback parameter must not be negative"))
        end

        if max_contacts < 0
            throw(ArgumentError("max_contacts parameter must not be negative"))
        end

        if success_rate isa Function
            return(new(TraceRateFn(success_rate), follow_up, Int16(lookback), resample_contacts, settingtypes, ContactFilterFn(contact_filter), max_contacts))
        end

        if !(0 <= success_rate <= 1)
            throw(ArgumentError("success_rate parameter must be between 0 and 1"))
        end

        return(new(success_rate, follow_up, Int16(lookback), resample_contacts, settingtypes, ContactFilterFn(contact_filter), max_contacts))
    end
end

"""
    success_rate(tsc::TraceSourceContacts)

Returns the `success_rate` attribute from a `TraceSourceContacts` struct: a number, or
the wrapped function of the days since the contact.
"""
function success_rate(tsc::TraceSourceContacts)
    return(tsc.success_rate)
end

"""
    follow_up(tsc::TraceSourceContacts)

Returns the `follow_up` strategy attribute from a `TraceSourceContacts` struct.
"""
function follow_up(tsc::TraceSourceContacts)
    return(tsc.follow_up)
end

"""
    lookback(tsc::TraceSourceContacts)

Returns how many ticks a `TraceSourceContacts` struct looks back from the current tick.
"""
function lookback(tsc::TraceSourceContacts)
    return(tsc.lookback)
end

"""
    resample_contacts(tsc::TraceSourceContacts)

Returns whether a `TraceSourceContacts` struct also traces re-drawn, non-infected contacts.
"""
function resample_contacts(tsc::TraceSourceContacts)
    return(tsc.resample_contacts)
end

"""
    settingtypes(tsc::TraceSourceContacts)

Returns the setting types a `TraceSourceContacts` struct re-draws contacts in.
"""
function settingtypes(tsc::TraceSourceContacts)
    return(tsc.settingtypes)
end

"""
    contact_filter(tsc::TraceSourceContacts)

Returns the wrapped function of a `TraceSourceContacts` struct that decides in which settings and at which ticks contacts are re-drawn.
"""
function contact_filter(tsc::TraceSourceContacts)
    return(tsc.contact_filter)
end

"""
    max_contacts(tsc::TraceSourceContacts)

Returns the largest number of contacts an index names to a `TraceSourceContacts` struct.
"""
function max_contacts(tsc::TraceSourceContacts)
    return(tsc.max_contacts)
end


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, ind::Individual, measure::TraceSourceContacts)

Detects the individual who infected the index individual, looking back from the current tick
to just before the index became infectious. With `resample_contacts`, re-drawn contacts from
that window are added. The `follow_up` strategy is handed over to all detected contacts.

# Parameters

- `sim::Simulation`: Simulation object
- `ind::Individual`: Individual that this measure will be applied to (focus individual)
- `measure::TraceSourceContacts`: Measure instance

# Returns

- `Nothing`: Triggers the `follow_up` strategy for each successfully traced contact.
"""
function process_measure(sim::Simulation, ind::Individual, measure::TraceSourceContacts)

    now = sim |> tick
    logger = sim |> infectionlogger
    sr = measure |> success_rate
    pop = sim |> population

    # the active infections, else the newest one, which has ended
    onset = earliest_infectiousness_onset(ind, infection_registry(sim, ind))
    if onset >= 0
        infectious_at = onset
        infections = [(state.infection_id, state.exposure) for state in each_infection(ind, sim)]
    else
        last = _last_infection(logger, ind |> id)
        # never infected, or never infectious
        (isnothing(last) || last.infectiousness_onset < 0) && return nothing
        infectious_at = last.infectiousness_onset
        infections = [(last.infection_id, last.exposure)]
    end

    # the window ends where forward tracing of the index starts
    start_tick = max(Int16(0), now - lookback(measure))
    end_tick = infectious_at - Int16(1)

    # get the living infecters of the index's infections from logger; seeds have none
    contact_ids = Int32[]
    contact_ticks = Int16[]
    for (infection_id, exposure) in infections
        a = _infecter_of(logger, infection_id)
        (a > 0 && start_tick <= exposure <= end_tick) || continue
        dead(get_individual_by_id(pop, a)) && continue
        push!(contact_ids, a)
        push!(contact_ticks, exposure)
    end

    INTERVENTION_DEBUG && @debug "Individual $(ind |> id) tracing $(contact_ids |> length) sources between tick $start_tick and $end_tick: $contact_ids at tick $now"

    # add re-drawn contacts; each contact keeps its latest tick and is traced once, in id order
    if resample_contacts(measure)
        last_contact = _sample_past_contacts(ind, sim, settingtypes(measure), start_tick, end_tick, contact_filter(measure))
        mergewith!(max, last_contact, Dict(zip(contact_ids, contact_ticks)))
        contact_ids = sort!(collect(keys(last_contact)))
        contact_ticks = [last_contact[c] for c in contact_ids]
    end

    # the index names at most max_contacts of them, picked at random
    if length(contact_ids) > max_contacts(measure)
        keep = sort!(gems_sample(sim, 1:length(contact_ids), max_contacts(measure); replace = false))
        contact_ids = contact_ids[keep]
        contact_ticks = contact_ticks[keep]
    end

    # filter by success_rate (one draw per contact, in order) and trigger the follow-up
    fu = measure |> follow_up
    for (cid, t) in zip(contact_ids, contact_ticks)
        gems_rand(sim) < _trace_probability(sr, Int(now - t)) || continue
        trigger_strategy(fu, get_individual_by_id(pop, cid), sim)
    end
    return nothing
end
