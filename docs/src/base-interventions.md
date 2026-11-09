# [Base Intervention Model](@id trism)

GEMS models non-pharmaceutical interventions (NPIs) — such as testing, isolation, or setting closures — using a **conceptual framework** based on the idea of **Trigger → Strategy → Measure**, abbreviated as **TriSM**.

This logic forms the foundation for how interventions are defined and applied during a simulation:  
- **Triggers** determine when an intervention should be activated.  
- **Strategies** represent defined response plans that organize one or more measures.
- **Measures** implement the actual effect on the simulation.

The TriSM pattern separates *decision-making* from *action*, enabling users to construct complex intervention policies without hard-coding behavior into the simulation core. Instead, users compose interventions from modular building blocks that are triggered by events or conditions during the simulation.

This page introduces the conceptual structure of TriSM. It is intended as a starting point for users who want to integrate interventions into their GEMS simulations.

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

## [Testtypes](@id trism-testtypes)

```@raw html
<img src="../assets/TriSM-teststypes.png" width="100%"/>
```
For testing measures (like individual test, pool test, or seroprevalence test), you need to specify the type of test being used. This is done by defining a Test Type. 

A **Test Type** represents the properties of a diagnostic test (such as sensitivity and specificity). You define it once, and then you can reuse it in multiple testing measures.
If you want different tests (e.g. antigen vs. PCR), you define multiple Test Types and assign them to the appropriate testing measures.

In short: the Test Type defines the diagnostic test itself, while the testing measure defines how, when, and to whom it is applied.


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


## [Interventions on Several Threads](@id trism-threads)

In large simulations, interventions can take most of the run time. GEMS therefore runs them on all threads where this is safe and keeps the rest in a single serial lane. Which lane a measure takes is decided once, when `add_measure!` adds it to a strategy.

**Measures that run on several threads**

- For individuals: `Test` (also with a `SeroprevalenceTestType`), `SelfIsolation`, `CancelSelfIsolation`, `FindSetting`, `FindSettings`, `FindSettingMembers`, `Vaccinate`, `TraceInfectiousContacts` and `TraceSourceContacts`. Each person's measures run on the thread that owns that person.
- For settings: `FindMembers`, `PoolTest`, `IsOpen` and `TestAll`.
- `CustomIMeasure` and `CustomSMeasure`, if created with `threadsafe = true`.
- Always serial: `CloseSetting`, `OpenSetting`, `ChangeContactMethod`, and custom measures without `threadsafe = true`.

**Your own functions need a promise**

GEMS cannot check what a function you pass does, so it calls your functions on several threads only if you mark them with `threadsafe = true` in the call that passes them:

- a strategy's `condition`, on `IStrategy` or `SStrategy`,
- an entry's `condition` and `delay`, and functions passed to the measure (a `selectionfilter`, or a tracing `success_rate` or `contact_filter`), on `add_measure!`,
- a custom measure's logic, on `CustomIMeasure` or `CustomSMeasure`.

A mark covers only the functions in its own call. Without a mark, GEMS calls the function serially, and the measure that uses it runs serially too. A strategy's condition is the exception: it is checked serially, but the strategy's measures can still run on several threads.

With `threadsafe = true` you promise that the function only reads the individual or setting it is given and state that does not change while interventions run (such as age or the settings a person belongs to), draws random numbers with `gems_rand(sim)`, and changes nothing shared. Counters, other people's state and capacity limits break that promise; leave such functions unmarked, and GEMS calls them serially as before. A wrong promise raises no error and results in a race condition.

```julia
adults = IStrategy("adult screening", sim, condition = i -> age(i) >= 18, threadsafe = true)
add_measure!(adults, Test("antigen", antigen_test), delay = i -> age(i) >= 65 ? 1 : 0, threadsafe = true)
```

For large simulations with tick triggers on several threads, `run!` logs a hint that names the strategies that run serially only because of unmarked functions.

**Order of measures**

Measures due on the same tick run in no fixed order, also when they are listed in one strategy; the order can change with `threadsafe` marks and the number of threads. Only a follow-up is guaranteed to run after the measure that triggered it, so a custom measure that triggers strategies itself should do so after its own changes. To act on what a measure without a follow-up leaves behind (for example a `CloseSetting`), give the later measure an `offset` and check that state in its `condition`. `TestAll` triggers its follow-up once all members are tested, later in the same tick.
