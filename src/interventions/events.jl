export IMeasureEvent, SMeasureEvent

###
### EVENT STRUCTS
###

"""
    IMeasureEvent <: Event

Struct associate a specific `Individual` with a specific `IMeasure`
which is stored in the intervention event queue.
"""
struct IMeasureEvent <: Event
    individual::Individual
    measure::IMeasure
    condition::IPredicate
    # type-erased `process_measure` callback for `measure` (see IProcessFn in strategies.jl)
    process_fn::IProcessFn
end

# convenience constructor that builds the process callback from the measure; used in tests.
# The intervention hot path passes a prebuilt wrapper from the MeasureEntry instead.
IMeasureEvent(individual::Individual, measure::IMeasure, condition) =
    IMeasureEvent(individual, measure, condition, IProcessFn((sim, ind) -> process_measure(sim, ind, measure)))

"""
    SMeasureEvent <: Event

Struct associate a specific `Setting` with a specific `SMeasure`
which is stored in the intervention event queue.
"""
struct SMeasureEvent <: Event
    setting::Setting
    measure::SMeasure
    condition::SPredicate
    # type-erased `process_measure` callback for `measure` (see SProcessFn in strategies.jl)
    process_fn::SProcessFn
end

# convenience constructor that builds the process callback from the measure; used in tests.
SMeasureEvent(setting::Setting, measure::SMeasure, condition) =
    SMeasureEvent(setting, measure, condition, SProcessFn((sim, s) -> process_measure(sim, s, measure)))


###
### PROCESS EVENTS
###

"""
    process_event(e::IMeasureEvent, sim::Simulation)

Executes a specific `IMeasure` for a secific `Individual` (as stored in the `IMeasureEvent`).
If the `process_measure` returns a `Handover`, its follow-up strategy is triggered.
"""
function process_event(e::IMeasureEvent, sim::Simulation)
    ind = e.individual

    # do not process measure if condition is not met
    if !e.condition(ind)
        return
    end

    # call the prebuilt, type-erased process callback
    res = e.process_fn(sim, ind)

    res isa Handover && apply_followup!(sim, focal_objects(res), follow_up(res))
    return
end


"""
    process_event(e::SMeasureEvent, sim::Simulation)

Executes a specific `SMeasure` for a secific `Setting` (as stored in the `SMeasureEvent`).
If the `process_measure` returns a `Handover`, its follow-up strategy is triggered.
"""
function process_event(e::SMeasureEvent, sim::Simulation)
    stng = e.setting

    # do not process measure if condition is not met
    if !e.condition(stng)
        return
    end

    # call the prebuilt, type-erased process callback
    res = e.process_fn(sim, stng)

    res isa Handover && apply_followup!(sim, focal_objects(res), follow_up(res))
    return
end