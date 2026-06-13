export MeasureEntry
export offset, measure, delay, condition, process_fn

export IStrategy, SStrategy
export name, condition, measures, add_measure!

# Concrete function-wrapper types for the per-strategy callbacks. Wrapping the user closures in
# these keeps the callback fields (and the measure vector) concretely typed, so calling them on
# the intervention hot path is type-stable instead of a dynamic dispatch. The focal object is an
# Individual for IStrategies/IMeasures and a Setting for SStrategies/SMeasures.
const IPredicate = FunctionWrapper{Bool, Tuple{Individual}}
const SPredicate = FunctionWrapper{Bool, Tuple{Setting}}
const IDelayFn = FunctionWrapper{Int, Tuple{Individual}}
const SDelayFn = FunctionWrapper{Int, Tuple{Setting}}

# Per-measure process callbacks. Built once at `add_measure!` time, where the concrete measure
# type is statically known, so the wrapped closure resolves `process_measure` statically. The
# wrapper type-erases the closure to a single concrete type, turning the intervention-hot-path
# call into a fixed indirect call instead of a dynamic `process_measure` dispatch.
const IProcessFn = FunctionWrapper{Any, Tuple{Simulation, Individual}}
const SProcessFn = FunctionWrapper{Any, Tuple{Simulation, Setting}}

"""
    MeasureEntry{O}

This struct represents a tuple of an intervention-`measure`,
an integer-`offset`, a `delay`-function and a `condition`.
It is the internal data structure for `Strategies`.
The type parameter `O` is the focal object type the `delay` and
`condition` callbacks operate on (`Individual` or `Setting`); it is
uniform across a strategy's measures, which keeps the measure vector
concretely typed. The `measure` field is intentionally abstract and is
resolved through the `process_measure` dispatch (a function barrier).
"""
struct MeasureEntry{O}
    offset::Int
    measure::Measure
    delay::FunctionWrapper{Int, Tuple{O}}
    condition::FunctionWrapper{Bool, Tuple{O}}
    # type-erased `process_measure` callback for this measure (see IProcessFn/SProcessFn above)
    process_fn::FunctionWrapper{Any, Tuple{Simulation, O}}
end


"""
    offset(me::MeasureEntry)

Returns the offset associated with a `MeasureEntry`.
"""
offset(me::MeasureEntry) = me.offset


"""
    measure(me::MeasureEntry)

Returns the measure associated with a `MeasureEntry`.
"""
measure(me::MeasureEntry) = me.measure

"""
    delay(me::MeasureEntry)

Returns the delay function associated with a `MeasureEntry`.
"""
delay(me::MeasureEntry) = me.delay

"""
    condition(me::MeasureEntry)

Returns the condition function associated with a `MeasureEntry`.
"""
condition(me::MeasureEntry) = me.condition

"""
    process_fn(me::MeasureEntry)

Returns the type-erased `process_measure` callback associated with a `MeasureEntry`.
"""
process_fn(me::MeasureEntry) = me.process_fn

"""
    IStrategy <: Strategy

An `IStrategy` is a container for intervention `IMeasure`s.
It contains a collection of specific measures that should be 
executed once this strategy is triggered. All measures must be
associated with individuals (rather than settings), thus being
`IMeasure`s. An `IStrategy` also contains a string `name` and
an optoional `condition` predicate function. The `condition`
must be a one-argument function returning a boolean value. 
The function is called once the strategy was triggered and can
condition its execution. The argument is the respective individual.
"""
struct IStrategy <: Strategy
    name::String
    # OFFSET, MEASURE, DELAY, CONDITION
    measures::Vector{MeasureEntry{Individual}}

    # One-Argument boolean function used to condition the execution of
    # this strategy. The argument will be the focal individual
    condition::IPredicate

    # this inner constructor requires the simulation object
    # to register the new strategy with it. Otherwise it will
    # be difficult to get all strategies for the report as 
    # the triggers only refer to a single instance of a strategy
    # whereas measure can trigger further strategies. For the report,
    # this would require to loop up all measures recursively,
    # in order to identify potential nested strategies
    @doc """
        IStrategy(name::String, sim::Simulation; condition::Function = x -> true)

    Creates an IStrategy object.

    # Parameters
      - `name::String`: Name of the strategy
      - `sim::Simulation`: Simulation object (required to interlink test with simulation)
      - `condition::Function = x -> true` *(optional)*: Predicate function than can be used to limit the execution of this strategy to only cerain individuals.

    # Examples

    ```julia
    my_str = IStrategy("self-isolation", sim)
    add_measure!(my_str, SelfIsolation(14))

    s_trigger = SymptomTrigger(my_str)
    add_symptom_trigger!(sim, s_trigger) 
    ```

    The above code will create a new strategy called, 'self-isolation'.
    Using the `add_measure!` function, you can now begin to populate your strategy
    with specific intervention measures, e.g. with a `SelfIsolation` measure.
    The second part creates a `SymptomTrigger` that will now fire your 
    strategy once an individual experiences symptoms.
    
    If you want to limit the execution of your strategy to only certain individuals
    e.g. based on their age, you can do that be adding a condition predicate function, such as:

    ```julia
    my_str = IStrategy("self-isolation", sim, condition = i -> age(i) > 65)
    add_measure!(my_str, SelfIsolation(14))

    s_trigger = SymptomTrigger(my_str)
    add_symptom_trigger!(sim, s_trigger) 
    ```

    The added condition will cause the strategy only to be executed for
    individuals who experience symptoms and are 65 or older.

    """
    function IStrategy(name::String, sim::Simulation; condition::Function = x -> true)
        str = new(name, MeasureEntry{Individual}[], IPredicate(condition))
        add_strategy!(sim, str)
        return(str)
    end
end

"""
    SStrategy <: Strategy

An `SStrategy` is a container for intervention `SMeasure`s.
It contains a collection of specific measures that should be 
executed once this strategy is triggered. All measures must be
associated with settings (rather than individuals), thus being
`SMeasure`s. An `SStrategy` also contains a string `name` and
an optional `condition` predicate function. The `condition`
must be a one-argument function returning a boolean value. 
The function is called once the strategy was triggered and can
condition its execution. The argument is the respective individual.
"""
struct SStrategy <: Strategy
    name::String
    # OFFSET, MEASURE, DELAY, CONDITION
    measures::Vector{MeasureEntry{Setting}}

    # One-Argument boolean function used to condition the execution of
    # this strategy. The argument will be the focal setting
    condition::SPredicate

    # this inner constructor requires the simulation object
    # to register the new strategy with it. Otherwise it will
    # be difficult to get all strategies for the report as 
    # the triggers only refer to a single instance of a strategy
    # whereas measure can trigger further strategies. For the report,
    # this would require to loop up all measures recursively,
    # in order to identify potential nested strategies
    @doc """
        SStrategy(name::String, sim::Simulation; condition::Function = x -> true)

    Creates an SStrategy object.

    # Parameters
    - `name::String`: Name of the strategy
    - `sim::Simulation`: Simulation object (required to interlink test with simulation)
    - `condition::Function = x -> true` *(optional)*: Predicate function than can be used to limit the execution of this strategy to only cerain settings.

    # Examples

    ```julia
    my_str = SStrategy("close-offices", sim)
    add_measure!(my_str, CloseSetting())

    t_trigger = STickTrigger(Office, my_str, switch_tick = Int16(20))
    add_tick_trigger!(sim, t_trigger)
    ```

    The above code will create a new strategy called, 'close-offices'.
    Using the `add_measure!` function, you can now begin to populate your strategy
    with specific intervention measures, e.g. with a `CloseSetting` measure.
    The second part creates a `STickTrigger` for the setting type `Office` and the
    `switch_tick` 20. Therefore, this trigger will call your strategy for all
    settings of type `Office` at tick 20, closing them indefinitely.
    
    If you want to limit the execution of your strategy to only certain settings
    e.g. based on their size, you can do that be adding a condition predicate function, such as:

    ```julia
    my_str = SStrategy("close-offices", sim, condition = s -> size(s) > 10)
    add_measure!(my_str, CloseSetting())

    t_trigger = STickTrigger(Office, my_str, switch_tick = Int16(20))
    add_tick_trigger!(sim, t_trigger)
    ```

    The added condition will cause the strategy only to be executed for
    settings that have more than 10 individuals associated.

    """
    function SStrategy(name::String, sim::Simulation; condition::Function = x -> true)
        str = new(name, MeasureEntry{Setting}[], SPredicate(condition))
        add_strategy!(sim, str)
        return(str)
    end
end

"""
    name(str::Strategy)

Returns the name of a `Strategy`.
"""
function name(str::Strategy)
    return(str.name)
end

"""
    condition(str::Strategy)

Returns the condition function of a `Strategy`.
"""
function condition(str::Strategy)
    return(str.condition)
end

"""
    measures(str::Strategy)

Returns the measures encapsulated in a `Strategy`; A vector of `MeasureEntry`s
"""
function measures(str::Strategy)
    return(str.measures)
end

"""
    add_measure!(str::Strategy, measure::Measure; offset::Int64 = 0, delay::Function = x -> 0, condition::Function = x -> true)

Adds `IMeasure`s to `IStrategy`s and `SMeasure`s to `SStrategy`s.

# Parameters:

- `str::Strategy`: Strategy that the measure will be added to
-  `measure::Measure`: Measure that will be added to te strategy
- `offset::Int64 = 0` *(optional)*: The number of ticks between the time the measure was triggered and the time the measure will be executed.
- `delay::Function = x -> 0` *(optional)*: Single-argument function that must resolve to an integer. The delay will extend the offset.
- `condition::Function = x -> true` *(optional)*: Predicate function conditioning the exeuction of a measure.

# Examples

```julia
my_str = IStrategy("self-isolation", sim)
add_measure!(my_str, SelfIsolation(14), offset = 2)

s_trigger = SymptomTrigger(my_str)
add_symptom_trigger!(sim, s_trigger) 
```

The above code shows how a `SelfIsolation` measure, putting an individual in self-isolation
for 14 days, is added to a custom `IStrategy`. The strategy is triggered once an individual
experiences symptoms (`SymptomTrigger`). The `offset` argument, however, specifies that it
takes another two ticks before the individual is put into self-isolation.

```julia
my_str = IStrategy("self-isolation", sim)
add_measure!(my_str, SelfIsolation(14), delay = i -> age(i) > 65 ? 2 : 0)
```

This example starts the self-isolation measure with a delay of two ticks if the individual is above 65 and otherwise immediately.

```julia
my_str = IStrategy("self-isolation", sim)
add_measure!(my_str, SelfIsolation(14), condition = i -> age(i) > 65)
```

This example only lets individuals go into self-isolation who are 65 and above.
All these optional arguments and predicate functions can be combined. The
calculated `delay` is added to the `offset` (if specified).
"""
function add_measure!(str::IStrategy, measure::IMeasure; offset::Int64 = 0, delay::Function = x -> 0, condition::Function = x -> true)
    fn = IProcessFn((sim, ind) -> process_measure(sim, ind, measure))
    push!(str.measures, MeasureEntry{Individual}(offset, measure, IDelayFn(delay), IPredicate(condition), fn))
    return str
end

function add_measure!(str::SStrategy, measure::SMeasure; offset::Int64 = 0, delay::Function = x -> 0, condition::Function = x -> true)
    fn = SProcessFn((sim, s) -> process_measure(sim, s, measure))
    push!(str.measures, MeasureEntry{Setting}(offset, measure, SDelayFn(delay), SPredicate(condition), fn))
    return str
end


###
### PRINTING
###

function Base.show(io::IO, s::Strategy)
    res = "$(typeof(s)): $(name(s))"
    for me in measures(s)
        res *= "\n\u2514 $(offset(me)): $(typeof(measure(me)))"
    end
    write(io, res)
end