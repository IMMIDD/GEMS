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
mutable struct IMeasureEvent <: Event
    individual::Individual
    measure::IMeasure
    condition::Function
end

"""
    SMeasureEvent <: Event

Struct associate a specific `Setting` with a specific `SMeasure`
which is stored in the intervention event queue.
"""
mutable struct SMeasureEvent <: Event
    setting::Setting
    measure::SMeasure
    condition::Function
end



###
### PROCESS EVENTS
###

"""
    process_event(e::IMeasureEvent, sim::Simulation)

Executes a specific `IMeasure` for a secific `Individual` (as stored in the `IMeasureEvent`)
and triggers potential follow-up strategies if specified in the `Handover` object that 
the `process_measure()` functions return.
"""
function process_event(e::IMeasureEvent, sim::Simulation)
    ind = e.individual
    msr = e.measure
    cnd = e.condition

    # PROCESS EVENT

    # do not process measure if condition is not met
    if !cnd(ind)
        return
    end

    res = process_measure(sim, ind, msr)

    # HANDLE NEXT EVENTS

    # if nothing was handed over, end function
    if typeof(res) != Handover
        return
    end

    # if something was handed over, trigger handover strategy for each focal object
    for fo in focal_objects(res)
        !isnothing(follow_up(res)) ? trigger_strategy(follow_up(res), fo, sim) : nothing
    end
end


"""
    process_event(e::SMeasureEvent, sim::Simulation)

Executes a specific `SMeasure` for a secific `Setting` (as stored in the `SMeasureEvent`)
and triggers potential follow-up strategies if specified in the `Handover` object that 
the `process_measure()` functions return.
"""
function process_event(e::SMeasureEvent, sim::Simulation)
    stng = e.setting
    msr = e.measure
    cnd = e.condition

    # PROCESS EVENT

    # do not process measure if condition is not met
    if !cnd(stng)
        return
    end

    res = process_measure(sim, stng, msr)

    # HANDLE NEXT EVENTS

    # if nothing was handed over, end function
    if typeof(res) != Handover
        return
    end

    # if something was handed over, trigger handover strategy for each focal object
    for fo in focal_objects(res)
        !isnothing(follow_up(res)) ? trigger_strategy(follow_up(res), fo, sim) : nothing
    end
end