export offset, measure, delay, condition

export IStrategy, SStrategy
export name, condition, measures, add_measure!

# Concrete wrappers for the per-strategy callbacks, so their fields are concretely typed and calls are
# static. The focal object is an Individual for IStrategies/IMeasures, a Setting for SStrategies/SMeasures.
const IPredicate = FunctionWrapper{Bool, Tuple{Individual}}
const SPredicate = FunctionWrapper{Bool, Tuple{Setting}}
const IDelayFn = FunctionWrapper{Int, Tuple{Individual}}
const SDelayFn = FunctionWrapper{Int, Tuple{Setting}}

# Tracing probability by days since the contact, for the `success_rate` of tracing measures.
const TraceRateFn = FunctionWrapper{Float64, Tuple{Int}}

# Whether contacts in a setting are re-drawn at a past tick, for the `contact_filter` of tracing measures.
const ContactFilterFn = FunctionWrapper{Bool, Tuple{Setting, Int16}}

# Per-measure process callbacks, built in `add_measure!` with the measure and `sim` captured. They take
# only the focal object, as the abstract `Simulation` type as an argument would make the call dynamic.
const IProcessFn = FunctionWrapper{Any, Tuple{Individual}}
const SProcessFn = FunctionWrapper{Any, Tuple{Setting}}

# Defaults of the `condition` and `delay` callbacks; a strategy tells them from user closures by identity.
_always_true(_) = true
_no_delay(_) = 0
# The same for the `contact_filter` of tracing measures
_any_contact(_, _) = true

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
    process_fn::FunctionWrapper{Any, Tuple{O}}
    # whether this entry can run in the parallel lane
    parallel::Bool
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
mutable struct IStrategy{S<:Simulation} <: Strategy
    name::String
    # OFFSET, MEASURE, DELAY, CONDITION
    measures::Vector{MeasureEntry{Individual}}

    # One-Argument boolean function used to condition the execution of
    # this strategy. The argument will be the focal individual
    condition::IPredicate

    # whether the closures run when the strategy is triggered can run on several threads
    parallel_trigger::Bool

    # the simulation this strategy is bound to; captured by the per-measure process callbacks
    # (see IProcessFn) so `sim` is concretely typed at `add_measure!` time
    sim::S

    # this inner constructor requires the simulation object
    # to register the new strategy with it. Otherwise it will
    # be difficult to get all strategies for the report as 
    # the triggers only refer to a single instance of a strategy
    # whereas measure can trigger further strategies. For the report,
    # this would require to loop up all measures recursively,
    # in order to identify potential nested strategies
    @doc """
        IStrategy(name::String, sim::Simulation; condition::Function = x -> true, threadsafe::Bool = false)

    Creates an IStrategy object.

    # Parameters
      - `name::String`: Name of the strategy
      - `sim::Simulation`: Simulation object (required to interlink test with simulation)
      - `condition::Function = x -> true` *(optional)*: Predicate function than can be used to limit the execution of this strategy to only cerain individuals.
      - `threadsafe::Bool = false` *(optional)*: Promises that `condition` only reads the focal individual and state that does not change while events run, and writes nothing shared, so it can be evaluated on several threads, on large tick triggers and in the parallel lane. Covers only the closures in this call.

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
    function IStrategy(name::String, sim::S; condition::Function = _always_true, threadsafe::Bool = false) where {S<:Simulation}
        _check_condition(condition, Individual, "IStrategy '$name'")
        str = new{S}(name, MeasureEntry{Individual}[], IPredicate(condition), condition === _always_true || threadsafe, sim)
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
mutable struct SStrategy{S<:Simulation} <: Strategy
    name::String
    # OFFSET, MEASURE, DELAY, CONDITION
    measures::Vector{MeasureEntry{Setting}}

    # One-Argument boolean function used to condition the execution of
    # this strategy. The argument will be the focal setting
    condition::SPredicate

    # whether the closures run when the strategy is triggered can run on several threads
    parallel_trigger::Bool

    # the simulation this strategy is bound to; captured by the per-measure process callbacks
    # (see SProcessFn) so `sim` is concretely typed at `add_measure!` time
    sim::S

    # this inner constructor requires the simulation object
    # to register the new strategy with it. Otherwise it will
    # be difficult to get all strategies for the report as 
    # the triggers only refer to a single instance of a strategy
    # whereas measure can trigger further strategies. For the report,
    # this would require to loop up all measures recursively,
    # in order to identify potential nested strategies
    @doc """
        SStrategy(name::String, sim::Simulation; condition::Function = x -> true, threadsafe::Bool = false)

    Creates an SStrategy object.

    # Parameters
    - `name::String`: Name of the strategy
    - `sim::Simulation`: Simulation object (required to interlink test with simulation)
    - `condition::Function = x -> true` *(optional)*: Predicate function than can be used to limit the execution of this strategy to only cerain settings.
    - `threadsafe::Bool = false` *(optional)*: Promises that `condition` only reads the focal setting and state that does not change while events run, and writes nothing shared, so large tick triggers can evaluate it on several threads. Covers only the closures in this call.

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
    function SStrategy(name::String, sim::S; condition::Function = _always_true, threadsafe::Bool = false) where {S<:Simulation}
        _check_condition(condition, Setting, "SStrategy '$name'")
        str = new{S}(name, MeasureEntry{Setting}[], SPredicate(condition), condition === _always_true || threadsafe, sim)
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
    add_measure!(str::Strategy, measure::Measure; offset::Int64 = 0, delay::Function = x -> 0, condition::Function = x -> true, threadsafe::Bool = false)

Adds `IMeasure`s to `IStrategy`s and `SMeasure`s to `SStrategy`s.

# Parameters:

- `str::Strategy`: Strategy that the measure will be added to
-  `measure::Measure`: Measure that will be added to te strategy
- `offset::Int64 = 0` *(optional)*: The number of ticks between the time the measure was triggered and the time the measure will be executed.
- `delay::Function = x -> 0` *(optional)*: Single-argument function that must resolve to an integer. The delay will extend the offset.
- `condition::Function = x -> true` *(optional)*: Predicate function conditioning the exeuction of a measure.
- `threadsafe::Bool = false` *(optional)*: Promises that `delay`, `condition` and functions passed to `measure` (like a `selectionfilter`, or a tracing `success_rate` or `contact_filter`) only read the objects they are given and state that does not change while events run, and write nothing shared, so large tick triggers can evaluate `delay` on several threads and the measure can run in the parallel lane. Covers only the closures in this call.

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
function add_measure!(str::IStrategy{S}, measure::IMeasure; offset::Int64 = 0, delay::Function = _no_delay, condition::Function = _always_true, threadsafe::Bool = false) where {S<:Simulation}
    sim = str.sim
    fn = IProcessFn(ind -> process_measure(sim, ind, measure))
    _check_condition(condition, Individual, "a measure of IStrategy '$(str.name)'")
    push!(str.measures, MeasureEntry{Individual}(offset, measure, IDelayFn(delay), IPredicate(condition), fn, _parallel_entry(measure, delay, condition, threadsafe)))
    str.parallel_trigger &= delay === _no_delay || threadsafe
    return str
end
# `where {S}` forces specialization on the strategy type so `str.sim` is concretely typed and the
# closure captures `sim` concretely.

function add_measure!(str::SStrategy{S}, measure::SMeasure; offset::Int64 = 0, delay::Function = _no_delay, condition::Function = _always_true, threadsafe::Bool = false) where {S<:Simulation}
    sim = str.sim
    fn = SProcessFn(s -> process_measure(sim, s, measure))
    _check_condition(condition, Setting, "a measure of SStrategy '$(str.name)'")
    push!(str.measures, MeasureEntry{Setting}(offset, measure, SDelayFn(delay), SPredicate(condition), fn, _parallel_entry(measure, delay, condition, threadsafe)))
    str.parallel_trigger &= delay === _no_delay || threadsafe
    return str
end

"""
    _check_condition(condition::Function, argtype::Type, owner::AbstractString)

Throws an `ArgumentError` if `condition` can return something other than a `Bool` for an `argtype` argument.
A condition whose return type Julia cannot infer is accepted.
"""
function _check_condition(condition::Function, argtype::Type, owner::AbstractString)
    for R in Base.return_types(condition, (argtype,))
        R === Any || R <: Bool ||
            throw(ArgumentError("The condition that you passed to $owner does not return a boolean value."))
    end
    return nothing
end


"""
    _parallel_entry(measure::Measure, delay::Function, condition::Function, threadsafe::Bool)

Returns whether a strategy entry with these closures can run in the parallel lane.
"""
_parallel_entry(measure::Measure, delay::Function, condition::Function, threadsafe::Bool) =
    _parallel_safe(measure, threadsafe) && (threadsafe || (delay === _no_delay && condition === _always_true))

"""
    _parallel_strategy(str::IStrategy)

Returns whether `str` can run in the parallel lane as a whole, including its condition and delays.
"""
_parallel_strategy(str::IStrategy) = str.parallel_trigger && all(me -> me.parallel, measures(str))

"""
    _closures_hold_back(str::Strategy)

Returns whether marking the closures of `str` as `threadsafe` would let it use more threads.
"""
_closures_hold_back(str::IStrategy) = !isempty(measures(str)) && !_parallel_strategy(str) &&
    all(me -> _parallel_safe(measure(me), true), measures(str))
_closures_hold_back(str::SStrategy) = !isempty(measures(str)) && (!str.parallel_trigger ||
    any(me -> !me.parallel && _parallel_safe(measure(me), true), measures(str)))

"""
    _hint_threadsafe_option(sim::Simulation)

Logs once per session which strategies of a large threaded run are held back by closures not marked `threadsafe`.
"""
function _hint_threadsafe_option(sim::Simulation)
    Threads.nthreads() > 1 || return nothing
    isempty(tick_triggers(sim)) && return nothing
    length(individuals(sim)) < TICK_TRIGGER_THREADING_MIN && return nothing
    held_back = [name(str) for str in strategies(sim) if _closures_hold_back(str)]
    isempty(held_back) && return nothing
    @info "Strategies $(join(held_back, ", ")) run serially because of closures not marked `threadsafe = true`. \
        If a closure only reads its focal individual or setting and state that does not change while events run \
        (like `i -> age(i) >= 65`), and neither reads nor writes other people's state, counters or capacity limits, \
        add `threadsafe = true` to the call that passes it (`IStrategy`, `SStrategy` or `add_measure!`, \
        which also covers functions passed to the measure it adds), \
        so large interventions can use all threads. A mark covers only the closures in its own call. \
        A wrong promise causes races that silently change results. See `?add_measure!`." maxlog = 1
    return nothing
end

###
### PRINTING
###

function Base.show(io::IO, s::Strategy)
    res = "$(typeof(s)): $(name(s))"
    for me in measures(s)
        res *= "\n\u2514 $(offset(me)): $(nameof(typeof(measure(me))))"
    end
    write(io, res)
end