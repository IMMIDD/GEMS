export SymptomTrigger, HospitalizationTrigger, ITickTrigger, STickTrigger
export strategy, settingtype, switch_tick, interval
export should_fire

###
### SYMPTOM TRIGGERS
###

"""
    SymptomTrigger <: ITrigger

A struct defining an `IStrategy` that
shall be fired upon an individual experiencing symptoms.
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

# Parameters

- `strategy::IStrategy`: Strategy that will be triggered
- `switch_tick::Int16 = Int16(-1)` *(optional)*: Threshold for the strategy onset
- `interval::Int16 = Int16(-1)` *(optional)*: Trigger strategy in reoccuring intervals

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
"""
struct ITickTrigger <: TickTrigger
    strategy::IStrategy
    switch_tick::Int16 # if -1, the strategy is triggered every tick. If >= 0, this strategy is triggered at the defined tick
    interval::Int16 # if X == -1, the trigger is not fired regularly. If X >= 1, this strategy is triggered every X ticks

    function ITickTrigger(strategy::IStrategy; switch_tick::Int16 = Int16(-1), interval::Int16 = Int16(-1))
        if switch_tick <= 0 && switch_tick != -1
            throw("The switch_tick must either be a positive integer or -1")
        end
        
        if interval <= 0 && interval != -1
            throw("The interval must either be a positive integer or -1")
        end

        new(strategy, switch_tick, interval)
    end
end


"""
    STickTrigger <: TickTrigger

A struct defining an `SStrategy` with timed execution for all settings of a specified `settingtype` in the model.
The `switch_tick` sets a threshold for the onset of strategy execution based on the current tick.
The `interval` defines a reoccurence (optional). If no `switch_tick` is given, the 
strategy will be fired in each tick. If only the `interval` is given, the strategy
will be fired from tick 1 onwards in the specified interval.

# Parameters

- `settingtype::DataType`: Type of settings (e.g. `Household`) that the triggered strategy will be applied to
- `strategy::SStrategy`: Strategy that will be triggered
- `switch_tick::Int16 = Int16(-1)` *(optional)*: Threshold for the strategy onset
- `interval::Int16 = Int16(-1)` *(optional)*: Trigger strategy in reoccuring intervals

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

    function STickTrigger(settingtype::DataType, strategy::SStrategy; switch_tick::Int16 = Int16(-1), interval::Int16 = Int16(-1))
        if !(settingtype <: Setting)
            throw("The first argument must be a DataType inheriting from 'Setting'")
        end

        if switch_tick <= 0 && switch_tick != -1
            throw("The switch_tick must either be a positive integer or -1")
        end

        if interval <= 0 && interval != -1
            throw("The interval must either be a positive integer or -1")
        end

        new(settingtype, strategy, switch_tick, interval)
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
    for i in sim |> population |> individuals 
        trigger_strategy(itt |> strategy, i, sim)
    end
end

"""
    trigger(stt::STickTrigger, sim::Simulation)

Triggers the execution of the `SStrategy` for all settings of the specified `settingtype`
associated with an `STickTrigger`.
"""
function trigger(stt::STickTrigger, sim::Simulation)
    for s in settings(sim, stt |> settingtype)
        trigger_strategy(stt |> strategy, s, sim)
    end
end

"""
    trigger_strategy(str::IStrategy, i::Individual, sim::Simulation)

Enqueues an `IMeasureEvent` in the `Simulation` event queue for all `IMeasures` 
of the provided `IStrategy` and the specified `Individual`.

# Parameters

- `str::IStrategy`: Strategy that is being triggered
- `i::Individual`: Individual that the tiggered strategy is applied to
- `sim::Simulation`: Simulation object
"""
function trigger_strategy(str::IStrategy, i::Individual, sim::Simulation)
    # if condition is not met, return without executing measures
    cond = try
        Bool(str.condition(i))
    catch
        # throw error if user provided a function that doesn't return a boolean value
        throw("The condition that you passed to IStrategy '$(str.name)' does not return a boolean value.")
    end

    if !cond
        return
    end
    
    # generate one MeasureEvent for each associated measure and push it to the Simulation's event queue
    for me in str |> measures
        # enqueue measure events with the current tick and the added delay
        sim |> event_queue |>
            x -> enqueue!(x, 
                IMeasureEvent(i, measure(me), condition(me)),
                Int16(tick(sim) + offset(me) + delay(me)(i))
            )
    end
end

"""
    trigger_strategy(str::SStrategy, s::Setting, sim::Simulation)

Enqueues an `SMeasureEvent` in the `Simulation` event queue for all `SMeasures` 
of the provided `SStrategy` and the specified `Setting`.

# Parameters

- `str::SStrategy`: Strategy that is being triggered
- `s::Setting`: Setting that the tiggered strategy is applied to
- `sim::Simulation`: Simulation object
"""
function trigger_strategy(str::SStrategy, s::Setting, sim::Simulation)
    # if condition is not met, return without executing measures
    cond = try
        Bool(str.condition(s))
    catch
        # throw error if user provided a function that doesn't return a boolean value
        throw("The condition that you passed to SStrategy '$(str.name)' does not return a boolean value.")
    end

    if !cond
        return
    end
    
    # generate one MeasureEvent for each associated measure and push it to the Simulation's event queue
    for me in str |> measures
        # enqueue measure events with the current tick and the added delay
        sim |> event_queue |>
            x -> enqueue!(x, 
                SMeasureEvent(s, measure(me), condition(me)),
                Int16(tick(sim) + offset(me) + delay(me)(s))
            )
    end
end

###
### PRINTING
###

Base.show(io::IO, it::ITrigger) = write(io, "$(typeof(it))($(it |> strategy |> name))")
Base.show(io::IO, tt::TickTrigger) = write(io, "$(typeof(tt))($(tt |> strategy |> name); switch_tick: $(switch_tick(tt)); interval: $(interval(tt)))")
