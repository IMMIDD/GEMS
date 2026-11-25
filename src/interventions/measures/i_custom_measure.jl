export CustomIMeasure, measure_logic

###
### STRUCT
###

"""
    CustomIMeasure <: IMeasure
    CustomIMeasure(measure_logic::Function; threadsafe::Bool = false)

Intervention struct to apply custom logic to an indivudal when this measure is executed.
The field `measure_logic` must contain a two-argument function where the first argument
is an `Individual` and the second argument is the `Simulation` struct.
Upon execution of the measure, this function will be called with these two arguments.

# Example

```julia
my_str = IStrategy("change-risk-behavior", sim)
add_measure!(my_str, CustomIMeasure((i, simobj) -> mandate_compliance!(i, .8)))
```

The above example creates an `IStrategy` called 'my\\_str' and adds
an instance of the `CustomIMeasure` measure that is being instantiated with a
function changing an individual's `mandate_compliance` attribute to 80%. This could,
for example, be used to model changing risk perceptions over time. While the above
example does not require the `Simulation` object, it is still being passed,
to make the whole simulation state available at all times.

`threadsafe = true` lets large interventions run the measure on several threads. It promises that `measure_logic`
only changes the individual it is given (like `vaccinate!(i, sim, vaccine, tick(sim))` or its quarantine), draws
random numbers with `gems_rand(sim)`, and triggers strategies only after its own changes. It must not change other
individuals, settings, activity plans or shared counters, or infect anyone. A wrong promise causes races that
silently change results.
"""
struct CustomIMeasure <: IMeasure 
    measure_logic::Function
    threadsafe::Bool

    CustomIMeasure(measure_logic::Function; threadsafe::Bool = false) = new(measure_logic, threadsafe)
end

"""
    measure_logic(measure::CustomIMeasure)

Returns the `measure_logic` (function) attribute from a `CustomIMeasure` struct. 
"""
function measure_logic(measure::CustomIMeasure)
    return(measure.measure_logic)
end

_parallel_safe(m::CustomIMeasure, ::Bool) = m.threadsafe

###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, ind::Individual, custom::CustomIMeasure)

Applies a custom logic to the individual as specified in the `CustomIMeasure`'s `measure_logic` field.

# Parameters

- `sim::Simulation`: Simulation object
- `ind::Individual`: Individual that this measure will be applied to (focus individual)
- `custom::CustomIMeasure`: Measure instance
"""
function process_measure(sim::Simulation, ind::Individual, custom::CustomIMeasure)
    
    t = sim |> tick

    INTERVENTION_DEBUG && @debug "Individual $(ind |> id) subjected to custom measure at tick $t"

    # execute custom logic
    measure_logic(custom)(ind, sim)
end
