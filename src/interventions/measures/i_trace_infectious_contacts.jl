export TraceInfectiousContacts
export success_rate, follow_up, resample_contacts, contact_filter

###
### STRUCT
###

"""
    TraceInfectiousContacts <: IMeasure

Intervention struct to trace individuals that have been 
infected by the index individual, this measure is called with.
The `follow_up` argument provides an `IStrategy` that is being
exceuted for all detected contacts. The optional `success_rate` (0-1) argument
can be used to model sub-perfect tracing (the default is 100%). It can also be a
function of the days since the infection that returns the probability (0-1).

# Example

```julia
my_str = IStrategy("contact-tracing", sim)
add_measure!(my_str, TraceInfectiousContacts(my_other_str, success_rate = 0.5))
```

The above example creates an `IStrategy` called 'my\\_str' and adds
an instance of the `TraceInfectiousContacts` measure that will trigger
the 'my\\_other\\_str' for all detected infections. The `success_rate` is 50%.

```julia
add_measure!(my_str, TraceInfectiousContacts(my_other_str, success_rate = dt -> 0.9 * exp(-dt / 7)))
```

Here, the chance to trace an infection falls with the days since it happened.

With `resample_contacts = true`, non-infected contacts are traced as well. They are re-drawn
from the index's settings of the given `settingtypes` (default: `Household`, `Office`, `SchoolClass`)
using today's memberships, so they are a plausible set, not the contacts drawn during the run.
Infectees the re-draw missed replace re-drawn contacts of a shared setting where possible, keeping the count.
Past closures are unknown to GEMS; a `contact_filter(setting, tick)` returning `false` skips
re-drawing in that setting at that tick, e.g. `(s, t) -> !(s isa SchoolClass && 30 <= t <= 44)`.
"""
struct TraceInfectiousContacts <: IMeasure
    success_rate::Union{Float64, TraceRateFn}
    follow_up::IStrategy
    resample_contacts::Bool
    settingtypes::Vector{DataType}
    contact_filter::ContactFilterFn

    function TraceInfectiousContacts(follow_up::IStrategy; success_rate::Union{Real, Function} = 1.0,
            resample_contacts::Bool = false, settingtypes::Vector{DataType} = DataType[Household, Office, SchoolClass],
            contact_filter::Function = (setting, tick) -> true)
        if success_rate isa Function
            return(new(TraceRateFn(success_rate), follow_up, resample_contacts, settingtypes, ContactFilterFn(contact_filter)))
        end

        if !(0 <= success_rate <= 1)
            throw(ArgumentError("success_rate parameter must be between 0 and 1"))
        end

        return(new(success_rate, follow_up, resample_contacts, settingtypes, ContactFilterFn(contact_filter)))
    end
end

"""
    success_rate(tic::TraceInfectiousContacts)

Returns the `success_rate` attribute from a `TraceInfectiousContacts` struct: a number, or
the wrapped function of the days since the infection.
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

"""
    resample_contacts(tic::TraceInfectiousContacts)

Returns whether a `TraceInfectiousContacts` struct also traces re-drawn, non-infected contacts.
"""
function resample_contacts(tic::TraceInfectiousContacts)
    return(tic.resample_contacts)
end

"""
    settingtypes(tic::TraceInfectiousContacts)

Returns the setting types a `TraceInfectiousContacts` struct re-draws contacts in.
"""
function settingtypes(tic::TraceInfectiousContacts)
    return(tic.settingtypes)
end

"""
    contact_filter(tic::TraceInfectiousContacts)

Returns the wrapped function of a `TraceInfectiousContacts` struct that decides in which settings and at which ticks contacts are re-drawn.
"""
function contact_filter(tic::TraceInfectiousContacts)
    return(tic.contact_filter)
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

- `Nothing`: Triggers the `follow_up` strategy for each successfully traced infectee.
"""
function process_measure(sim::Simulation, ind::Individual, measure::TraceInfectiousContacts)

    now = sim |> tick
    infectious_at = earliest_infectiousness_onset(ind, infection_registry(sim, ind))
    sr = measure |> success_rate

    # get infectee IDs and infection ticks from logger
    infectee_ids, infection_ticks = _infections_with_ticks_between(sim  |> infectionlogger, ind |> id, infectious_at, now)

    INTERVENTION_DEBUG && @debug "Individual $(ind |> id) tracing $(infectee_ids |> length) infectious contacts between tick $infectious_at and $now: $infectee_ids at tick $(sim |> tick)"

    # add re-drawn contacts; each contact keeps its latest tick and is traced once, in id order
    if resample_contacts(measure) && infectious_at >= 0
        last_contact = _sample_past_contacts(ind, sim, settingtypes(measure), infectious_at, now, contact_filter(measure))
        _merge_infectees!(last_contact, infectee_ids, infection_ticks, ind, sim, settingtypes(measure))
        infectee_ids = sort!(collect(keys(last_contact)))
        infection_ticks = [last_contact[c] for c in infectee_ids]
    end

    # filter by success_rate (one draw per infectee, in order) and trigger the follow-up
    fu = measure |> follow_up
    pop = sim |> population
    for (iid, t) in zip(infectee_ids, infection_ticks)
        gems_rand(sim) < _trace_probability(sr, Int(now - t)) || continue
        trigger_strategy(fu, get_individual_by_id(pop, iid), sim)
    end
    return nothing
end


###
### HELPERS
###

"""
    _trace_probability(success_rate, dt::Int)

Returns the chance to trace a contact from `dt` days ago, given a tracing measure's `success_rate`.
"""
_trace_probability(success_rate::Float64, ::Int) = success_rate

function _trace_probability(success_rate::TraceRateFn, dt::Int)
    p = success_rate(dt)
    if !(0 <= p <= 1)
        throw(ArgumentError("success_rate function returned $p for $dt days; it must return a value between 0 and 1"))
    end
    return p
end

"""
    _merge_infectees!(last_contact::Dict{Int32, Int16}, infectee_ids::Vector{Int32}, infection_ticks::Vector{Int16}, ind::Individual, sim::Simulation, settingtypes::Vector{DataType})

Adds the logged infectees to the re-drawn `last_contact`. Each infectee the re-draw missed replaces a random re-drawn
non-infectee of the first listed setting it shares with `ind`, or is added on top if there is none.
"""
function _merge_infectees!(last_contact::Dict{Int32, Int16}, infectee_ids::Vector{Int32}, infection_ticks::Vector{Int16},
        ind::Individual, sim::Simulation, settingtypes::Vector{DataType})
    logged = Set(infectee_ids)
    pop = sim |> population
    for (iid, t) in zip(infectee_ids, infection_ticks)
        if !haskey(last_contact, iid)
            infectee = get_individual_by_id(pop, iid)
            for T in settingtypes
                s = _member_setting(ind, sim, T)
                (isnothing(s) || _member_setting(infectee, sim, T) !== s) && continue
                pool = [id(m) for m in individuals(s, sim) if haskey(last_contact, id(m)) && !(id(m) in logged)]
                isempty(pool) || delete!(last_contact, gems_rand(sim, pool))
                break
            end
        end
        last_contact[iid] = max(get(last_contact, iid, t), t)
    end
    return last_contact
end