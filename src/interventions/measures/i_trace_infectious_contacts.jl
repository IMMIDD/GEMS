export TraceInfectiousContacts
export success_rate, follow_up, resample_contacts, contact_filter, max_contacts

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

Contacts are traced from the index's infectiousness onset until the previous tick, or until its recovery if its
newest infection has already ended, but at most `lookback` ticks back (default: 14). Infectees who have
died since are not traced.

With `resample_contacts = true`, non-infected contacts are traced as well. They are re-drawn in the index's settings of the given `settingtypes`
(default: all built-in types except `GlobalSetting` and `Municipality`), from today's members and scales, so they are a
plausible set, not the contacts drawn during the run. A `contact_filter(setting, tick)` returning `false` skips a setting
at that tick, e.g. to leave out a past closure.
Infectees the re-draw missed replace re-drawn contacts of a shared setting where possible, keeping the count.

The optional `max_contacts` caps how many contacts the index names; a random subset of that size is
picked before the `success_rate` draws (default: no cap).
"""
struct TraceInfectiousContacts{FU<:IStrategy} <: IMeasure
    success_rate::Union{Float64, TraceRateFn}
    follow_up::FU
    lookback::Int16
    resample_contacts::Bool
    settingtypes::Vector{DataType}
    contact_filter::ContactFilterFn
    has_contact_filter::Bool
    max_contacts::Int

    function TraceInfectiousContacts(follow_up::IStrategy; success_rate::Union{Real, Function} = 1.0,
            lookback::Integer = 14, resample_contacts::Bool = false,
            settingtypes::Vector{DataType} = DataType[Household, SchoolClass, SchoolYear, School, SchoolComplex, Office, Department, Workplace, WorkplaceSite],
            contact_filter::Function = _any_contact, max_contacts::Integer = typemax(Int))
        if lookback < 1
            throw(ArgumentError("lookback parameter must be at least 1"))
        end

        if max_contacts < 0
            throw(ArgumentError("max_contacts parameter must not be negative"))
        end

        if success_rate isa Function
            return(new{typeof(follow_up)}(TraceRateFn(success_rate), follow_up, Int16(lookback), resample_contacts, settingtypes, ContactFilterFn(contact_filter), contact_filter !== _any_contact, max_contacts))
        end

        if !(0 <= success_rate <= 1)
            throw(ArgumentError("success_rate parameter must be between 0 and 1"))
        end

        return(new{typeof(follow_up)}(success_rate, follow_up, Int16(lookback), resample_contacts, settingtypes, ContactFilterFn(contact_filter), contact_filter !== _any_contact, max_contacts))
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
    lookback(tic::TraceInfectiousContacts)

Returns how many ticks a `TraceInfectiousContacts` struct looks back from the current tick.
"""
function lookback(tic::TraceInfectiousContacts)
    return(tic.lookback)
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

"""
    max_contacts(tic::TraceInfectiousContacts)

Returns the largest number of contacts an index names to a `TraceInfectiousContacts` struct.
"""
function max_contacts(tic::TraceInfectiousContacts)
    return(tic.max_contacts)
end


# a `success_rate` function, or a `contact_filter` when resampling, is a user closure, so it needs the entry's mark
_parallel_safe(tic::TraceInfectiousContacts, threadsafe::Bool) =
    threadsafe || (success_rate(tic) isa Float64 && !(resample_contacts(tic) && tic.has_contact_filter))

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
    logger = sim |> infectionlogger
    sr = measure |> success_rate
    pop = sim |> population

    # the infectious period of the active infection, else of the newest one, which has ended
    onset = earliest_infectiousness_onset(ind, infection_registry(sim, ind))
    if onset >= 0
        infectious_from = onset
        end_tick = now - Int16(1)
    else
        last = _last_infection(logger, ind |> id)
        # never infected, or never infectious
        (isnothing(last) || last.infectiousness_onset < 0) && return nothing
        infectious_from = last.infectiousness_onset
        end_tick = min(last.recovery, now - Int16(1))
    end
    start_tick = max(infectious_from, now - lookback(measure))
    start_tick > end_tick && return nothing

    # get infectee IDs and infection ticks from logger
    infectee_ids, infection_ticks = _infections_with_ticks_between(logger, ind |> id, start_tick, end_tick)

    # the dead cannot be traced, so they take no `max_contacts` slot and replace no re-drawn contact
    alive = [!dead(get_individual_by_id(pop, iid)) for iid in infectee_ids]
    keepat!(infectee_ids, alive)
    keepat!(infection_ticks, alive)

    INTERVENTION_DEBUG && @debug "Individual $(ind |> id) tracing $(infectee_ids |> length) infectious contacts between tick $start_tick and $end_tick: $infectee_ids at tick $now"

    # add re-drawn contacts; each contact keeps its latest tick and is traced once, in id order
    if resample_contacts(measure)
        last_contact = _sample_past_contacts(ind, sim, settingtypes(measure), start_tick, end_tick, contact_filter(measure))
        _merge_infectees!(last_contact, infectee_ids, infection_ticks, ind, sim, settingtypes(measure))
        infectee_ids = sort!(collect(keys(last_contact)))
        infection_ticks = [last_contact[c] for c in infectee_ids]
    end

    # the index names at most max_contacts of them, picked at random
    if length(infectee_ids) > max_contacts(measure)
        keep = sort!(gems_sample(sim, 1:length(infectee_ids), max_contacts(measure); replace = false))
        infectee_ids = infectee_ids[keep]
        infection_ticks = infection_ticks[keep]
    end

    # filter by success_rate (one draw per infectee, in order) and trigger the follow-up
    fu = measure |> follow_up
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
            s = _first_shared_setting(ind, get_individual_by_id(pop, iid), sim, settingtypes)
            if !isnothing(s)
                # a member of two of a container's leaves is listed twice
                replaceable = unique!([id(m) for m in individuals(s, sim) if haskey(last_contact, id(m)) && !(id(m) in logged)])
                isempty(replaceable) || delete!(last_contact, gems_rand(sim, replaceable))
            end
        end
        last_contact[iid] = max(get(last_contact, iid, t), t)
    end
    return last_contact
end

"""
    _first_shared_setting(a::Individual, b::Individual, sim::Simulation, settingtypes::Vector{DataType})

Returns the first setting of the given `settingtypes` that `a` and `b` both belong to, or `nothing`.
"""
function _first_shared_setting(a::Individual, b::Individual, sim::Simulation, settingtypes::Vector{DataType})
    for T in settingtypes
        b_ids = setting_ids(b, T, sim)
        for sid in setting_ids(a, T, sim)
            sid in b_ids && return settings(sim, T)[sid]
        end
    end
    return nothing
end