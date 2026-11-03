export SymptomTrigger, HospitalizationTrigger, ITickTrigger, STickTrigger
export strategy, settingtype, switch_tick, interval
export should_fire

# Predicate on the Simulation that can suppress a TickTrigger from firing at all,
# checked in addition to the switch_tick/interval schedule (see should_fire below).
const SimPredicate = FunctionWrapper{Bool, Tuple{Simulation}}

###
### SYMPTOM TRIGGERS
###

"""
    SymptomTrigger <: ITrigger

A struct defining an `IStrategy` that
shall be fired upon an individual experiencing symptoms.
The strategy's condition and delays are evaluated serially, after the tick's disease update.
"""
struct SymptomTrigger <: ITrigger
    strategy::IStrategy
end

"""
    strategy(trigger::SymptomTrigger)

Returns the `IStrategy` object associated with a `SymptomTrigger`.
"""
function strategy(trigger::SymptomTrigger)
    return(trigger.strategy)
end


###
### HOSPITALIZATION TRIGGERS
###

"""
    HospitalizationTrigger <: ITrigger

A struct defining an `IStrategy` that
shall be fired upon an individual's admittance to hospital.
"""
struct HospitalizationTrigger <: ITrigger
    strategy::IStrategy
end

"""
    strategy(trigger::HospitalizationTrigger)

Returns the `IStrategy` object associated with a `HospitalizationTrigger`.
"""
function strategy(trigger::HospitalizationTrigger)
    return(trigger.strategy)
end



###
### TICK TRIGGERS
###

"""
    ITickTrigger <: TickTrigger

A struct defining an `IStrategy` with timed execution for all individuals in the model.
The `switch_tick` sets a threshold for the onset of strategy execution based on the current tick.
The `interval` defines a reoccurence (optional). If no `switch_tick` is given, the
strategy will be fired in each tick. If only the `interval` is given, the strategy
will be fired from tick 1 onwards in the specified interval.
An optional `condition` predicate can be used to suppress firing entirely (e.g. based on
simulation-wide state), regardless of `switch_tick`/`interval`.
For large populations, the strategy's condition and delays are evaluated on several threads only if it has none or they are marked `parallel = true`.

# Parameters

- `strategy::IStrategy`: Strategy that will be triggered
- `switch_tick::Int16 = Int16(-1)` *(optional)*: Threshold for the strategy onset
- `interval::Int16 = Int16(-1)` *(optional)*: Trigger strategy in reoccuring intervals
- `condition::Function = sim -> true` *(optional)*: Predicate function on the `Simulation` that can be used to suppress this trigger from firing at all

# Examples

```
ITickTrigger(my_daily_testing_strategy)
```
will trigger `my_daily_testing_strategy` each tick for each individuals.

```
ITickTrigger(my_home_office_strategy, switch_tick = Int16(20), interval = Int16(7))
```
will trigger `my_home_office_strategy` from tick 20 in a 7-tick interval for each individuals.

```
ITickTrigger(my_lockdown_strategy, switch_tick = Int16(50)
```
will trigger the `my_lockdown_strategy` once on tick 50.

```
ITickTrigger(my_surveillance_strategy, switch_tick = Int16(10), interval = Int16(7),
    condition = is_disease_active)
```
will trigger `my_surveillance_strategy` from tick 10 in a 7-tick interval, but only
while the disease is still active, so the trigger stops firing (and the simulation
can go dormant) once it has died out.
"""
struct ITickTrigger <: TickTrigger
    strategy::IStrategy
    switch_tick::Int16 # if -1, the strategy is triggered every tick. If >= 0, this strategy is triggered at the defined tick
    interval::Int16 # if X == -1, the trigger is not fired regularly. If X >= 1, this strategy is triggered every X ticks
    condition::SimPredicate # predicate on the Simulation that can suppress firing entirely

    function ITickTrigger(strategy::IStrategy; switch_tick::Int16 = Int16(-1), interval::Int16 = Int16(-1), condition::Function = sim -> true)
        if switch_tick <= 0 && switch_tick != -1
            throw(ArgumentError("The switch_tick must either be a positive integer or -1"))
        end

        if interval <= 0 && interval != -1
            throw(ArgumentError("The interval must either be a positive integer or -1"))
        end

        _check_condition(condition, Simulation, "a tick trigger")
        new(strategy, switch_tick, interval, SimPredicate(condition))
    end
end


"""
    STickTrigger <: TickTrigger

A struct defining an `SStrategy` with timed execution for all settings of a specified `settingtype` in the model.
The `switch_tick` sets a threshold for the onset of strategy execution based on the current tick.
The `interval` defines a reoccurence (optional). If no `switch_tick` is given, the
strategy will be fired in each tick. If only the `interval` is given, the strategy
will be fired from tick 1 onwards in the specified interval.
An optional `condition` predicate can be used to suppress firing entirely (e.g. based on
simulation-wide state), regardless of `switch_tick`/`interval`.
For many settings, the strategy's condition and delays are evaluated on several threads only if it has none or they are marked `parallel = true`.

# Parameters

- `settingtype::DataType`: Type of settings (e.g. `Household`) that the triggered strategy will be applied to
- `strategy::SStrategy`: Strategy that will be triggered
- `switch_tick::Int16 = Int16(-1)` *(optional)*: Threshold for the strategy onset
- `interval::Int16 = Int16(-1)` *(optional)*: Trigger strategy in reoccuring intervals
- `condition::Function = sim -> true` *(optional)*: Predicate function on the `Simulation` that can be used to suppress this trigger from firing at all

# Examples

```
STickTrigger(School, my_daily_testing_strategy)
```
will trigger `my_daily_testing_strategy` each tick for each school.

```
STickTrigger(Office, my_pool_testing_strategy, switch_tick = Int16(20), interval = Int16(7))
```
will trigger `my_pool_testing_strategy` from tick 20 in a 7-tick interval for each office.

```
STickTrigger(School, my_schhool_closure_strategy, switch_tick = Int16(50)
```
will trigger the `my_schhool_closure_strategy` once on tick 50 for all schools.
"""
struct STickTrigger <: TickTrigger
    settingtype::DataType
    strategy::SStrategy
    switch_tick::Int16 # if X == -1, the strategy is triggered every tick. If X >= 0, this strategy is triggered at the defined tick
    interval::Int16 # if X == -1, the trigger is not fired regularly. If X >= 1, this strategy is triggered every X ticks
    condition::SimPredicate # predicate on the Simulation that can suppress firing entirely

    function STickTrigger(settingtype::DataType, strategy::SStrategy; switch_tick::Int16 = Int16(-1), interval::Int16 = Int16(-1), condition::Function = sim -> true)
        if !(settingtype <: Setting)
            throw(ArgumentError("The first argument must be a DataType inheriting from 'Setting'"))
        end

        if switch_tick <= 0 && switch_tick != -1
            throw(ArgumentError("The switch_tick must either be a positive integer or -1"))
        end

        if interval <= 0 && interval != -1
            throw(ArgumentError("The interval must either be a positive integer or -1"))
        end

        _check_condition(condition, Simulation, "a tick trigger")
        new(settingtype, strategy, switch_tick, interval, SimPredicate(condition))
    end
end

"""
    settingtype(trigger::STickTrigger)

Returns the `settingtype` associated with a `STickTrigger`.
"""
function settingtype(trigger::STickTrigger)
    return(trigger.settingtype)
end

"""
    strategy(trigger::TickTrigger)

Returns the intervention `strategy` associated with a `TickTrigger`.
"""
function strategy(trigger::TickTrigger)
    return(trigger.strategy)
end

"""
    switch_tick(trigger::TickTrigger)

Returns the `switch_tick` associated with a `TickTrigger`.
"""
function switch_tick(trigger::TickTrigger)
    return(trigger.switch_tick)
end

"""
    interval(trigger::TickTrigger)

Returns the `interval` associated with a `TickTrigger`.
"""
function interval(trigger::TickTrigger)
    return(trigger.interval)
end

"""
    condition(trigger::TickTrigger)

Returns the trigger-level `condition` predicate associated with a `TickTrigger`.
This is separate from the per-individual/per-setting condition on the trigger's
`strategy`; it is consulted (alongside `switch_tick`/`interval`) to decide whether
the trigger fires at all.
"""
function condition(trigger::TickTrigger)
    return(trigger.condition)
end

"""
    should_fire(trigger::TickTrigger, tick::Int16)

Evaluates whether a trigger should be fired at a given tick.
Considers `switch_tick` and `interval`.

# Returns

- `Bool`: True, if the trigger should fire at this tick. False otherwise.
"""
function should_fire(trigger::TickTrigger, tick::Int16)

    # if the switch_tick lies in the future, this trigger cannot be fired
    if tick < switch_tick(trigger)
        return(false)
    end

    # if no switch_tick and no interval is given, this trigger should always fire
    if switch_tick(trigger) == interval(trigger) == -1
        return(true)
    end

    # if the switch_tick matches the current tick and intervals
    # are disabled, this trigger should fire 
    if switch_tick(trigger) == tick && interval(trigger) == -1
        return(true)
    end

    # if interval condition is met (after the tick_trigger), fire trigger
    if interval(trigger) > 0 && (tick - max(switch_tick(trigger), 0)) % interval(trigger) == 0
        return(true)
    end

    # return false in any other case
    return(false)
end

"""
    should_fire(trigger::TickTrigger, sim::Simulation)

Evaluates whether a trigger should be fired in the given simulation at its
current tick. Considers `switch_tick`, `interval`, and the trigger's
trigger-level `condition`.

# Returns

- `Bool`: True, if the trigger should fire now. False otherwise.
"""
function should_fire(trigger::TickTrigger, sim::Simulation)
    should_fire(trigger, tick(sim)) || return(false)

    return(condition(trigger)(sim))
end


###
### TRIGGER STRATEGIES
###

"""
    trigger(st::SymptomTrigger, i::Individual, sim::Simulation)

Triggers the execution of the `IStrategy` associated with a `SymptomTrigger`.

# Parameters

- `st::SymptomTrigger`: Trigger instance
- `i::Individual`: Individual that the `IStrategy` contained in the `SymptomTrigger` is executed for
- `sim::Simulation`: Simulation object
"""
function trigger(st::SymptomTrigger, i::Individual, sim::Simulation)
    trigger_strategy(st |> strategy, i, sim)
end

"""
    trigger(ht::HospitalizationTrigger, i::Individual, sim::Simulation)

Triggers the execution of the `IStrategy` associated with a `HospitalizationTrigger`.

# Parameters

- `ht::HospitalizationTrigger`: Trigger instance
- `i::Individual`: Individual that the `IStrategy` contained in the `HospitalizationTrigger` is executed for
- `sim::Simulation`: Simulation object
"""
function trigger(ht::HospitalizationTrigger, i::Individual, sim::Simulation)
    trigger_strategy(ht |> strategy, i, sim)
end

"""
    trigger(itt::ITickTrigger, sim::Simulation)

Triggers the execution of the `IStrategy` associated with an `ITickTrigger` for all individuals in the model.
"""
function trigger(itt::ITickTrigger, sim::Simulation)
    _trigger_all!(itt |> strategy, sim |> population |> individuals, sim)
end

"""
    trigger(stt::STickTrigger, sim::Simulation)

Triggers the execution of the `SStrategy` for all settings of the specified `settingtype`
associated with an `STickTrigger`.
"""
function trigger(stt::STickTrigger, sim::Simulation)
    _trigger_all!(stt |> strategy, get(settingscontainer(sim), stt |> settingtype), sim)
end

"""
    trigger_strategy(str::IStrategy, i::Individual, sim::Simulation)

Enqueues an `IMeasureEvent` for all `IMeasures` of the provided `IStrategy` and the specified `Individual`:
in the owner's queue for entries of the parallel lane, otherwise in the `Simulation` event queue. Inside a
phase of the parallel lane, anything but a parallel strategy on this shard's own people becomes a request.

# Parameters

- `str::IStrategy`: Strategy that is being triggered
- `i::Individual`: Individual that the tiggered strategy is applied to
- `sim::Simulation`: Simulation object
"""
function trigger_strategy(str::IStrategy, i::Individual, sim::Simulation)
    context = _event_context(sim)
    shard = _owner_shard(id(i))
    if _in_slot(context)
        if !_parallel_strategy(str)
            push!(_parallel_lane(sim).serial_individual_requests[context.slot], _IStrategyRequest(i, str))
            return
        elseif shard != context.owner
            # no shard matches `context.owner` outside the owner phase
            _request_from_owner!(str, i, sim, context, shard)
            return
        end
    end

    # if condition is not met, return without executing measures
    cond = str.condition(i)

    if !cond
        return
    end

    # generate one MeasureEvent for each associated measure and push it to its queue
    for me in str |> measures
        ev = IMeasureEvent(i, measure(me)::IMeasure, condition(me), process_fn(me))
        # schedule for the current tick plus the measure's offset and added delay
        t = Int16(tick(sim) + offset(me) + delay(me)(i))
        enqueue!(me.parallel ? _owner_queue(sim, shard) : event_queue(sim), ev, t)
    end
end

"""
    trigger_strategy(str::SStrategy, s::Setting, sim::Simulation)

Enqueues an `SMeasureEvent` for all `SMeasures` of the provided `SStrategy` and the specified `Setting`:
in the setting queue for entries of the parallel lane, otherwise in the `Simulation` event queue.
Inside a phase of the parallel lane, it becomes a request to serial code.

# Parameters

- `str::SStrategy`: Strategy that is being triggered
- `s::Setting`: Setting that the tiggered strategy is applied to
- `sim::Simulation`: Simulation object
"""
function trigger_strategy(str::SStrategy, s::Setting, sim::Simulation)
    context = _event_context(sim)
    if _in_slot(context)
        push!(_parallel_lane(sim).serial_setting_requests[context.slot], _SStrategyRequest(s, str))
        return
    end

    _foreach_setting_event(str, s, sim) do ev, t, queue
        enqueue!(queue, ev, t)
    end
end

"""
    _foreach_setting_event(f, str::SStrategy, s::Setting, sim::Simulation)

Calls `f(event, tick, queue)` for every measure of `str`, if the condition of `str` holds for `s`. `queue` is where the event belongs.
"""
@inline function _foreach_setting_event(f, str::SStrategy, s::Setting, sim::Simulation)
    # if condition is not met, return without executing measures
    str.condition(s) || return nothing

    # generate one MeasureEvent for each associated measure
    for me in str |> measures
        ev = SMeasureEvent(s, measure(me)::SMeasure, condition(me), process_fn(me))
        # schedule for the current tick plus the measure's offset and added delay
        f(ev, Int16(tick(sim) + offset(me) + delay(me)(s)), me.parallel ? _setting_queue(sim) : event_queue(sim))
    end
    return nothing
end

###
### THREADED TICK TRIGGERS
###

"""
    _trigger_all!(str::Strategy, objs::AbstractVector, sim::Simulation)

Triggers `str` for every object in `objs`. From `TICK_TRIGGER_THREADING_MIN` objects on it
uses all threads if `_can_thread_trigger` allows it, keeping the order of `objs`.
"""
function _trigger_all!(str::Strategy, objs::AbstractVector, sim::Simulation)
    n = length(objs)
    if n < TICK_TRIGGER_THREADING_MIN || !_can_thread_trigger(str)
        for o in objs
            trigger_strategy(str, o, sim)
        end
        return nothing
    end
    _foreach_chunk(sim, n) do range
        for k in range
            _trigger_in_chunk!(str, @inbounds(objs[k]), sim)
        end
    end
    _merge_staged_setting_events!(sim)
    return nothing
end

"""
    _can_thread_trigger(str::Strategy)

Returns whether `_trigger_all!` can use all threads for `str`.
"""
_can_thread_trigger(str::IStrategy) = _parallel_strategy(str)
_can_thread_trigger(str::SStrategy) = str.parallel_trigger

"""
    _trigger_in_chunk!(str::Strategy, focal, sim::Simulation)

Triggers `str` for `focal` in a chunk of a threaded tick trigger: an individual is requested from its owner, the events of a setting are staged.
"""
_trigger_in_chunk!(str::IStrategy, i::Individual, sim::Simulation) = trigger_strategy(str, i, sim)
function _trigger_in_chunk!(str::SStrategy, s::Setting, sim::Simulation)
    buffer = _parallel_lane(sim).staged_setting_events[_event_context(sim).slot]
    _foreach_setting_event(str, s, sim) do ev, t, queue
        push!(buffer, (ev, t, queue))
    end
end

"""
    _merge_staged_setting_events!(sim)

Moves the setting events a threaded tick trigger staged into their queues, in slot order.
"""
function _merge_staged_setting_events!(sim)
    for buffer in _parallel_lane(sim).staged_setting_events
        for (event, t, queue) in buffer
            enqueue!(queue, event, t)
        end
        empty!(buffer)
    end
    return nothing
end

###
### PRINTING
###

Base.show(io::IO, it::ITrigger) = write(io, "$(typeof(it))($(it |> strategy |> name))")
Base.show(io::IO, tt::TickTrigger) = write(io, "$(typeof(tt))($(tt |> strategy |> name); switch_tick: $(switch_tick(tt)); interval: $(interval(tt)))")
