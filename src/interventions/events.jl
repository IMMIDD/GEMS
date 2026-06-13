export IMeasureEvent
export SMeasureEvent

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
    trigger_handover!(objs::Vector, fu::Strategy, sim::Simulation)

Triggers the follow-up strategy `fu` for every focal object in `objs`. Acts as a
function barrier: `focal_objects(::Handover)` is abstractly typed
(`Union{Vector{<:Individual}, Vector{<:Setting}}`), so resolving the concrete types once
here lets the per-object loop run type-stable instead of dynamically dispatching
`trigger_strategy` for each focal object.
"""
function trigger_handover!(objs::Vector, fu::Strategy, sim::Simulation)
    for o in objs
        trigger_strategy(fu, o, sim)
    end
end


"""
    process_event(e::IMeasureEvent, sim::Simulation)

Executes a specific `IMeasure` for a secific `Individual` (as stored in the `IMeasureEvent`)
and triggers potential follow-up strategies if specified in the `Handover` object that 
the `process_measure()` functions return.
"""
function process_event(e::IMeasureEvent, sim::Simulation)
    ind = e.individual
    cnd = e.condition

    # PROCESS EVENT

    # do not process measure if condition is not met
    if !cnd(ind)
        return
    end

    # call the prebuilt, type-erased process callback
    res = e.process_fn(sim, ind)

    # HANDLE NEXT EVENTS

    # if nothing was handed over, end function
    if !(res isa Handover)
        return
    end

    # if no follow-up strategy was handed over, end function
    fu = follow_up(res)
    if isnothing(fu)
        return
    end

    # trigger the handover strategy for each focal object (function barrier for type stability)
    trigger_handover!(focal_objects(res), fu, sim)
end


"""
    process_event(e::SMeasureEvent, sim::Simulation)

Executes a specific `SMeasure` for a secific `Setting` (as stored in the `SMeasureEvent`)
and triggers potential follow-up strategies if specified in the `Handover` object that 
the `process_measure()` functions return.
"""
function process_event(e::SMeasureEvent, sim::Simulation)
    stng = e.setting
    cnd = e.condition

    # PROCESS EVENT

    # do not process measure if condition is not met
    if !cnd(stng)
        return
    end

    # call the prebuilt, type-erased process callback
    res = e.process_fn(sim, stng)

    # HANDLE NEXT EVENTS

    # if nothing was handed over, end function
    if !(res isa Handover)
        return
    end

    # if no follow-up strategy was handed over, end function
    fu = follow_up(res)
    if isnothing(fu)
        return
    end

    # trigger the handover strategy for each focal object (function barrier for type stability)
    trigger_handover!(focal_objects(res), fu, sim)
end