# [Base Intervention Model](@id trism)

GEMS models non-pharmaceutical interventions (NPIs) — such as testing, isolation, or setting closures — using a **conceptual framework** based on the idea of **Trigger → Strategy → Measure**, abbreviated as **TriSM**.

This logic forms the foundation for how interventions are defined and applied during a simulation:  
- **Triggers** determine when an intervention should be activated.  
- **Strategies** represent defined response plans that organize one or more measures.
- **Measures** implement the actual effect on the simulation.

The TriSM pattern separates *decision-making* from *action*, enabling users to construct complex intervention policies without hard-coding behavior into the simulation core. Instead, users compose interventions from modular building blocks that are triggered by events or conditions during the simulation.

This page introduces the conceptual structure of TriSM. It is intended as a starting point for users who want to integrate interventions into their GEMS simulations. For hands-on examples and practical walkthroughs, see the [Intervention Tutorials](tut_npi.md).  
For implementation details and code-level instructions, please refer to the [API documentation](api_interventions.md).

```@raw html
<img src="../assets/TriSM-overview.png" width="100%"/>
```

---

## [Triggers](@id trism-triggers)

Triggers are the starting point of every intervention in GEMS. They observe the simulation and activate a response when certain conditions are met.

Triggers can be event-based — such as when an individual develops symptoms or is hospitalized — or time-based, activating at specific ticks or at regular intervals. Most triggers apply to all individuals in the simulation, while only the `STickTrigger` specifically targets individuals within a given setting, such as a school or household.
Every trigger must be defined with a strategy. A trigger cannot exist on its own — it always needs to specify which strategy to activate when it fires.

In short, triggers define *when* an intervention should be considered.

---

## [Strategies](@id trism-strategies)

Strategies define what kind of response should happen when a trigger fires. Conceptually, they represent **intervention plans** — abstract containers for one or more actions.

A strategy may contain several measures or none at all. If it has no measures, triggering it results in no change to the simulation.

Strategies can also include conditions to determine whether they should be applied in a given context (e.g., only apply to children or specific settings).

There are two kinds of strategies:
- **IStrategies** apply to individuals.
- **SStrategies** apply to settings (e.g., a school or office).

---

## [Measures](@id trism-measures)

Measures are the building blocks of actual intervention effects. They change how individuals or settings behave in the simulation — for example, isolating someone, testing a group, or closing a school class.

While triggers and strategies handle the *when* and *what kind of* response, measures implement the *how*. They are the only part of the TriSM structure that directly alters the simulation’s course.

Measures can be immediate, delayed, or conditional. Each measure can be configured to take effect after a fixed offset or with a delay function based on individual properties. The condition handles whether a measure should apply in a given situation, allowing interventions to target only specific individuals or settings.

Some measures can also trigger **follow-up strategies** — secondary intervention plans that are launched in response to the measure's outcome. For example, a positive test might result in isolating that agent.

GEMS provides a wide range of built-in measures for common interventions. 
For advanced use cases, users can also define custom measures to model specific behaviors or policy effects not covered by the defaults.

## [Conditions and Delays](@id trism-condition-delay)

```@raw html
<img src="../assets/TriSM-overview2.png" width="100%"/>
```

In GEMS, measures and strategies can be extended with conditions and (for measures) offsets and delays to fine-tune their behavior:

- **Condition**: Restricts whether a strategy or measure should be applied in a given context.  
  For example, you can specify that an isolation measure should only apply to students, or only to members of households with more than 4 people.

- **Delay**: Postpones the execution of a measure by a fixed time or a function of individual properties.  
  For example, test results might arrive later for older individuals or rural settings.

- **Offset**: A simple time shift; a measure will be applied a fixed number of ticks after the strategy is triggered.  
  This is useful for scheduling follow-up actions (e.g. reopen a school class 10 days after closing it).

These extensions enable more nuanced and realistic modeling of interventions, while keeping the core logic modular and readable.

## [Examples](@id trism-examples)

Together, triggers, strategies, and measures form the building blocks of complex interventions.  
The following examples show how common public health responses — like isolation, testing, and closures — can be constructed using the TriSM model.

---

### Example 1: Symptom-Based Isolation 

```@raw html
<p align="center">
    <img src="../assets/TriSM-example-1.png" width="30%" alt="Diagram showing symptom-based isolation"/>
</p>
```

This example uses a symptom-based trigger to activate an individual strategy that applies a 7-day isolation measure.
The code to set up this scenario is:

```julia
sim = Simulation()

# Define a strategy with a 7-day isolation measure
self_isolation = IStrategy("Self Isolation", sim)
add_measure!(self_isolation, SelfIsolation(7))

# Create a symptom trigger that activates the self-isolation strategy
trigger = SymptomTrigger(self_isolation)
add_symptom_trigger!(sim, trigger)
```

---

### Example 2: Weekly School-Class Testing with Reactive Closures 

```@raw html
<p align="center">
    <img src="../assets/TriSM-example-4.png" width="90%"/>
</p>
```
This intervention is triggered every 7 days starting at tick 20. It checks each school class: if a class is open, all students in that class are tested. If any students test positive, the class is immediately closed and scheduled to reopen 10 days later.
The code to set up this intervention scenario is as follows:

```julia

sim = Simulation()

# Strategy for closing and reopening school classes
class_close_and_reopen = SStrategy("Class Close and Reopen", sim)
add_measure!(class_close_and_reopen, CloseSetting())
add_measure!(class_close_and_reopen, OpenSetting(), offset = 10)

# Strategy with test-all measure for school classes
class_test_all = SStrategy("Test all in Class", sim)
pcr_test = TestType("PCR Test", pathogen(sim), sim)
add_measure!(class_test_all, TestAll("PCR Test", pcr_test, positive_followup = class_close_and_reopen))

# Strategy to check if school classes are open
class_is_open = SStrategy("Class is Open?", sim)
add_measure!(class_is_open, IsOpen(positive_followup = class_test_all))

# Create a tick trigger that activates the class_is_open strategy for each SchoolClass
trigger = STickTrigger(SchoolClass, class_is_open, switch_tick = Int16(20), interval = Int16(7))
add_tick_trigger!(sim, trigger)
```
