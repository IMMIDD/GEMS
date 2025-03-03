# 9 - Intervention Strategies

GEMS offers extensive options for intervention modeling.
We represent interventions using the **"Trigger-Strategy-Measure"** (TriSM) notation.
Find an introduction to the TriSM notation [here](@ref trism).

TriSM is more of a modeling paradigm and as such offers countless scenarios that could be modeled.
This chapter contains a selection of examples to give you a broad idea.
The examples will always compare an invervention scenario with a non-restricted baseline scnario to verify that there is an effect.

!!! info "Where's the list of measures I can use to build up strategies?"
    Run `i_measuretypes()` to get a list of all measures that apply to individuals or `s_measuretypes()` for a list of all measures that apply to settings. If you want to learn more about any of the measure types, put a `?` into the Julia REPL and call `help?> SelfIsolation` (replace `SelfIsolation` with the measure name you want to learn about). 

## Self-Isolation With Symptoms

Here's an example that sends individuals into household-isolation for 14 days, if they are symptomatic.
To do so, we set up an `IStrategy` called "self\_isolation" and add an instance of the `SelfIsolation` measure with the duration parameter set to `14`.

**Scenario Summary**:
  - Individuals go into self-isolation for 14 days, immediately upon experiencing symptoms
  - Isolation prevents out-household contacts, but not in-household contacts
  - Individuals end their isolation after 14 days, regardless of their infection state

```julia
using GEMS
# simulation without interventions
baseline = Simulation(label = "Baseline")

# simulation with 14-day isolation (at home) upon experiencing symptoms
scenario = Simulation(label = "Scenario")
self_isolation = IStrategy("Self Isolation", scenario)
add_measure!(self_isolation, SelfIsolation(14))
trigger = SymptomTrigger(self_isolation)
add_symptom_trigger!(scenario, trigger)

run!(baseline)
run!(scenario)

rd_b = ResultData(baseline)
rd_s = ResultData(scenario)

gemsplot([rd_b, rd_s], type = (:TickCases, :CumulativeDiseaseProgressions, :CumulativeIsolations))
```


**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_interventions_self-isolation.png" width="80%"/>
</p>
``` 

The results show the difference between daily cases in both scenarios.
It also displays that there are around one third of asymptomatic cases in both experiments that would not be affected by this measure.
Using the `:CumulativeIsolations` plot, you can inspect the number of people who are currently in isolation at any given time.


## Conditioned Measures (Isolation)

The execution of measures and strategies can be conditioned.
Here's the self-isolation scenario again but it shall only apply to students.
School kids that are symptomatic shall be isolated for 14 days.
We can achieve this by passing the optional `condition`-argument to the `add_measure!(...)` function.
The condition itself must be a one-argument predicate function (a function that returns `true` or `false`) that is being evaluated once the measure is being triggered.
In the example below, we pass the `is_student(individual)` function that returns `true` if an individual is a student.

**Scenario Summary**:
  - Students go into self-isolation for 14 days, immediately upon experiencing symptoms
  - Isolation prevents out-household contacts, but not in-household contacts
  - Students end their isolation after 14 days, regardless of their infection state

```julia
using GEMS
# simulation without interventions
baseline = Simulation(label = "Baseline")

# simulation with 14-day isolation (at home)
# upon experiencing symptoms if you are a student
scenario = Simulation(label = "Isolate Students")
self_isolation = IStrategy("Self Isolation", scenario)
add_measure!(self_isolation, SelfIsolation(14), condition = is_student)
trigger = SymptomTrigger(self_isolation)
add_symptom_trigger!(scenario, trigger)

run!(baseline)
run!(scenario)

rd_b = ResultData(baseline)
rd_s = ResultData(scenario)

gemsplot([rd_b, rd_s], type = :TickCases)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_interventions_conditioned-isolation-1.png" width="60%"/>
</p>
```

You can also setup a custom condition-function.
Here's an example where people who are older than 50 should be isolated.

**Scenario Summary**:
  - Individuals of age 50+ go into self-isolation for 14 days, immediately upon experiencing symptoms
  - Isolation prevents out-household contacts, but not in-household contacts
  - Students end their isolation after 14 days, regardless of their infection state

```julia
using GEMS
# simulation without interventions
baseline = Simulation(label = "Baseline")

# function to evaluate whether an individual is over 50
function is_over_50(individual)
    return age(individual) >= 50
end

# simulation with 14-day isolation (at home)
# upon experiencing symptoms if you are 50+
scenario = Simulation(label = "Isolate 50+")
self_isolation = IStrategy("Self Isolation", scenario)
add_measure!(self_isolation, SelfIsolation(14), condition = is_over_50)
trigger = SymptomTrigger(self_isolation)
add_symptom_trigger!(scenario, trigger)

run!(baseline)
run!(scenario)

rd_b = ResultData(baseline)
rd_s = ResultData(scenario)

gemsplot([rd_b, rd_s], type = :TickCases)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_interventions_conditioned-isolation-2.png" width="60%"/>
</p>
```

It's also possible to pass (one-argument) lambda functions where the argument will be the individual.
In this is example, we only send people into self-isolation who are living in households larger than 5.


**Scenario Summary**:
  - Individuals living in households of size 5+ go into self-isolation for 14 days, immediately upon experiencing symptoms
  - Isolation prevents out-household contacts, but not in-household contacts
  - Students end their isolation after 14 days, regardless of their infection state

```julia
using GEMS
# simulation without interventions
baseline = Simulation(label = "Baseline")

# simulation with 14-day isolation (at home)
# upon experiencing symptoms if you are a in a 5+ household
scenario = Simulation(label = "Isolate if in Large Household")
self_isolation = IStrategy("Self Isolation", scenario)
add_measure!(self_isolation, SelfIsolation(14),
    condition = i -> size(household(i, scenario)) > 5)
trigger = SymptomTrigger(self_isolation)
add_symptom_trigger!(scenario, trigger)

run!(baseline)
run!(scenario)

rd_b = ResultData(baseline)
rd_s = ResultData(scenario)

gemsplot([rd_b, rd_s], type = :TickCases)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_interventions_conditioned-isolation-3.png" width="60%"/>
</p>
```

!!! info "Does it work the same way for SStrategies and SMeasures?"
    Yes. In the above examples, we condition measures that apply to individuals (`IMeasure`s). The argument in the condition-functions is the focus individual that this measure applies to. For `SMeasure`s, the argument for the condition-functions is the respective setting.


## Household Isolation

The previous examples let a symptomatic individual stay at home but did not force the other household members to do too.
If you want to isolate the entire household of symptomatic individuals, the following code will help you.
It is very similar to the previous example but instead of triggering the isolation strategy directly, an individual becoming symptomatic will trigger the "find\_household\_members" strategy that contains a `FindSettingMembers` measure.
This measure is parameterized to detect all members of the individual's `Household` setting.
The members are then all isolated individually, the same way as in the previous example.
This can also be considered a form of contact tracing.

**Scenario Summary**:
  - One individual experiencing symptoms will cause all household members to go into isolation for 14 days
  - This prevents all out-household contacts, within household contacts are still possible
  - After 14 days, all household members end their isolation, regardless of any of their infection states

```julia
using GEMS
# simulation without interventions
baseline = Simulation(label = "Baseline")

# simulation with 14-day isolation for all household members
scenario = Simulation(label = "Scenario")
self_isolation = IStrategy("Self Isolation", scenario)
add_measure!(self_isolation, SelfIsolation(14))
# identify list of household members
find_household_members = IStrategy("Find Household Members", scenario)
add_measure!(find_household_members, FindSettingMembers(Household, self_isolation))
# trigger "household tracing"
trigger = SymptomTrigger(find_household_members)
add_symptom_trigger!(scenario, trigger)

run!(baseline)
run!(scenario)

rd_b = ResultData(baseline)
rd_s = ResultData(scenario)

gemsplot([rd_b, rd_s], type = (:TickCases, :CumulativeIsolations))
```


**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_interventions_household-isolation.png" width="80%"/>
</p>
``` 

The numbers suggest, that isolating the entire household prevents more cases, compared to isolating only the symptomatic individual, but also causes more isolations.
Using `gemsplot`, you can compare both scenarios and the baseline.
The following code combines the previous two examples:

```julia
using GEMS
# simulation without interventions
baseline = Simulation(label = "Baseline")

# simulation with 14-day isolation (at home) upon experiencing symptoms
scenario_1 = Simulation(label = "Symptomatic Isolation")
self_isolation = IStrategy("Self Isolation", scenario_1)
add_measure!(self_isolation, SelfIsolation(14))
trigger = SymptomTrigger(self_isolation)
add_symptom_trigger!(scenario_1, trigger)

# simulation with 14-day isolation for all household members
scenario_2 = Simulation(label = "Household Isolation")
self_isolation = IStrategy("Self Isolation", scenario_2)
add_measure!(self_isolation, SelfIsolation(14))
find_household_members = IStrategy("Find Household Members", scenario_2)
add_measure!(find_household_members, FindSettingMembers(Household, self_isolation))
trigger = SymptomTrigger(find_household_members)
add_symptom_trigger!(scenario_2, trigger)

run!(baseline)
run!(scenario_1)
run!(scenario_2)

rd_b = ResultData(baseline)
rd_s1 = ResultData(scenario_1)
rd_s2 = ResultData(scenario_2)

gemsplot([rd_b, rd_s1, rd_s2],
    type = (:TickCases, :CumulativeIsolations, :EffectiveReproduction),
    legend = :topright)
```


**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_interventions_household-isolation2.png" width="80%"/>
</p>
``` 


## Testing and Isolation

GEMS comes with pre-defined building blocks for modeling testing strategies.
The following example subjects symptomatic individuals to a test and isolates them for `14` days, once the test is positive.
For that, a `TestType` is being defined, providing a name ("PCR\_Test"), the pathogen (taken from the `Simulation` object), and the `Simulation` object itself.
The self-isolation strategy is the same as in the first example.
However, it is only fired, once an individual is tested positive.
This is configured via a second strategy that we call "testing" where we add a `Test` measure that should use the previously defined "PCR_Test" and follow a positive test up with the "self\_isolation" strategy.
A `SymptomTrigger` fires the "testing" strategy once an individual becomes symptomatic.

**Scenario Summary**:
  - Upon experiencing symptoms, individuals are being tested immediately
  - The test has a 100% sensitivity and 100% specificity
  - Test results are available immediately
  - If the test result is positive, the individual goes into isolation for 14 days

```julia
using GEMS
# simulation without interventions
baseline = Simulation(label = "Baseline")

# simulation with 14-day isolation after positive test
scenario = Simulation(label = "Scenario")
# define test type (PCR test)
PCR_Test = TestType("PCR Test", pathogen(scenario), scenario)
# define self isolation strategy
self_isolation = IStrategy("Self Isolation", scenario)
add_measure!(self_isolation, SelfIsolation(14))
# define testing strategy that triggers self isolation
testing = IStrategy("Testing", scenario)
add_measure!(testing, Test("Test", PCR_Test, positive_followup = self_isolation))

trigger = SymptomTrigger(testing)
add_symptom_trigger!(scenario, trigger)

run!(baseline)
run!(scenario)

rd_b = ResultData(baseline)
rd_s = ResultData(scenario)

gemsplot([rd_b, rd_s], type = (:TickCases, :TickTests, :ActiveDarkFigure), size = (800, 800))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_interventions_testing.png" width="80%"/>
</p>
``` 

The results are very similar to the first example as all symptomatic individuals are immediately screened with a "perfect" test (100% sensitivity & specificity) and immediately sent in isolation.
Of course, in reality this not very realistic.
Therefore, GEMS offers options to delay measures (e.g., only getting a test one day after symptom onset).
Please look up the respective tutorial.


## Delayed Measures (Testing)

The timing of intervention strategies is crucial in most applications.
GEMS has two mechanisms to define the execution time of a measure.
Both can be passed as optional arguments to the `add_measure!(...)` function.
The `offset` defines how many ticks should be between the trigger event of a measure's parent strategy and the execution of the respective measure.
It's default value is `0`.
The `delay` takes a one-argument function that is being evaluated at runtime and needs to return an integer value.
These functions work very similar to the `condition`-function.
Please look up the previous example on conditioned measures.
The results of this delay-function is added on top of the offset.
It can be used to delay the execution of measures, e.g., based on  an individual's personal characteristics.
In the following scenarios, we compare two scenarios: (1) where individuals get a test immediately and go into isolation if the results come back positive (as in the previous tutorial) and (2) where individuals below the age of 50 get the test immediately an 50+ individuals get them one day after.

**Scenario Summary**:
  - Upon experiencing symptoms, individuals are being tested
  - In scenario 1, tests are being applied immediately. In scenario 2, tests are being applied with a one-day delay for people above the age of 50
  - The test has a 100% sensitivity and 100% specificity
  - Test results are available immediately
  - If the test result is positive, the individual goes into isolation for 14 days

```julia
using GEMS, Plots

# SCENARIO 1: No testing delay
scenario_1 = Simulation(label = "No Delay")
PCR_Test_1 = TestType("PCR Test", pathogen(scenario_1), scenario_1)
self_isolation_1 = IStrategy("Self Isolation", scenario_1)
add_measure!(self_isolation_1, SelfIsolation(14))
testing_1 = IStrategy("Testing", scenario_1)
add_measure!(testing_1, Test("Test", PCR_Test_1, positive_followup = self_isolation_1))
trigger_1 = SymptomTrigger(testing_1)
add_symptom_trigger!(scenario_1, trigger_1)

# SCENARIO 2: 1-day delay for 50+ people
scenario_2 = Simulation(label = "1-Day delay for 50+")
PCR_Test_2 = TestType("PCR Test", pathogen(scenario_2), scenario_2)
self_isolation_2 = IStrategy("Self Isolation", scenario_2)
add_measure!(self_isolation_2, SelfIsolation(14))
testing_2 = IStrategy("Testing", scenario_2)
add_measure!(testing_2, Test("Test", PCR_Test_2, positive_followup = self_isolation_2),
    delay = i -> age(i) >= 50 ? 1 : 0) # delay function
trigger_2 = SymptomTrigger(testing_2)
add_symptom_trigger!(scenario_2, trigger_2)

# run everything
b = Batch(scenario_1, scenario_2)
run!(b)
rd = ResultData(b)

plot(
    gemsplot(rd, type = :TickCases),
    gemsplot(rd, type = :TimeToDetection, ylims = (0, 6)),
    layout = (2, 1),
    size = (800, 800)
)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_interventions_delayed-testing.png" width="80%"/>
</p>
``` 

## Varying Test Sensitivity (or Specificity)

Here's an example of how you can vary intervention-related parameter such as the sensitivity of a test and inspect their influence on the overall dynamics.
The code below defines what we call a "scenario-function" (`testing_scenario!()`).
It takes the `Simulation` object and a sensitivity argument to parameterize the test.
That way, it is much easier to set up multiple intervention scenarios with varying parameters.
Moreover, the example uses the `Batch` functionality to easily aggregate all simulations and facilitate the execution and post-processing.

```julia
using GEMS

# to facilitate parameterization, set up a function
# that adds a scenario to a simulation object
function testing_scenario!(sim, sens)
    # define test type (PCR test) and pass sensitivity
    PCR_Test = TestType("PCR Test", pathogen(sim), sim, sensitivity = sens)
    # define self isolation strategy
    self_isolation = IStrategy("Self Isolation", sim)
    add_measure!(self_isolation, SelfIsolation(14))
    # define testing strategy that triggers self isolation
    testing = IStrategy("Testing", sim)
    add_measure!(testing, Test("Test", PCR_Test, positive_followup = self_isolation))

    trigger = SymptomTrigger(testing)
    add_symptom_trigger!(sim, trigger)
end

# use batch functionality to compare results
sims = Simulation[]
push!(sims, Simulation(label = "Baseline"))

# add scenarios with varying test sensitivities between 50% and 100%
for i in 0.5:0.1:1.0
    s = Simulation(label = "Sensitivity: $(100 * i)%")
    testing_scenario!(s, i)
    push!(sims, s)
end

b = Batch(sims...)
run!(b)
rd = ResultData(b)

gemsplot(rd, type = (:TickCases, :CumulativeIsolations), legend = :topright)
```


**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_interventions_testing2.png" width="80%"/>
</p>
``` 

!!! info "Can I run experiments that vary a test's specificity the same way?"
    Yes. 


## Pool Testing

Besides individual testing, GEMS also offers the option to perform so-called "pool tests".
Such tests return a positive result if at least one individual in a given setting is infected.
Working with pool tests is very similar to other testing scenarios with the main difference being, that pool tests are applied to settings, not to individuals.
Consequently, a positive pool test does not provide any information about whom of the individuals is infected.
The example below tests all school classes every seven days and closes the class for the following week if the pool test result is positive.
We furthermore add a `CustomLogger` to track the number of currently closed school classes.

**Scenario Summary**:
  - Pool-testing every school class once a week
  - If test is positive, school class is closed for the week

```julia
using GEMS
# simulation without interventions
baseline = Simulation(label = "Baseline")

self_isolation = IStrategy("Self Isolation", scenario_1)
add_measure!(self_isolation, SelfIsolation(14))
trigger = SymptomTrigger(self_isolation)
add_symptom_trigger!(scenario_1, trigger)

# simulation with school class closure for 7 days if pool test positive
scenario = Simulation(label = "Scenario")
# define test type (PCR test)
PCR_Test = TestType("PCR Test", pathogen(scenario), scenario)
# strategy that closes classes for the next 6 days
class_close_and_reopen = SStrategy("Class Close and Reopen", scenario)
add_measure!(class_close_and_reopen, CloseSetting())
add_measure!(class_close_and_reopen, OpenSetting(), offset = 6)
# strategy that tests whether at least one infected individual is in class
class_pool_test = SStrategy("Class Monday Pool Testing", scenario)
add_measure!(class_pool_test, PoolTest("monday_pool_testing", PCR_Test,
    positive_followup = class_close_and_reopen))
# add trigger that is being fired every 7 days for each school class
stt = STickTrigger(SchoolClass, class_pool_test, interval = Int16(7))
add_tick_trigger!(scenario, stt)

b = Batch(baseline, scenario)

# add logger to track number of currently closed school classes
cl = CustomLogger(closed_classes = sim -> sum(.!is_open.(schoolclasses(sim))))
customlogger!(b, cl)

run!(b)
rd = ResultData(b)

gemsplot(rd, type = (:TickCases, :CustomLoggerPlot))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_interventions_pool-testing.png" width="80%"/>
</p>
``` 


## Recurrent Testing

Let's consider an example where individuals can get tested multiple times.
The code below compares two scenarios where individuals go into self-isolation for 10 days upon experiencing symptoms.
In the second example, individuals can get tested after five days and leave isolation if the test is negative.
With a positive test, individuals can get another test two days later.
We neglect the fact that this will cause some tests to be performed on day 11.

**Scenario Summary**:
  - A symptomatic individual goes into self-isolation for 10 days
  - After day 5, they can get a test
  - If the test is negative, the individual may leave isolation
  - If the test is positive, the individual remains isolated and may test again after 48 hours
  - Individuals will get tested in a two-day interval as long as they are infected

```julia
using GEMS

# SCENARIO 1: simulation with self-isolation only
scenario_1 = Simulation(label = "Isolation Only")
self_isolation = IStrategy("Self Isolation", scenario_1)
add_measure!(self_isolation, SelfIsolation(14))
trigger_1 = SymptomTrigger(self_isolation)
add_symptom_trigger!(scenario_1, trigger_1)

# SCENARIO 2: simulation with self-isolation and recurrent testing
scenario_2 = Simulation(label = "Recurrent Testing")
# define test type (PCR test)
PCR_test = TestType("PCR Test", pathogen(scenario_2), scenario_2)
# strategy that ends isolation
end_isolation = IStrategy("End Isolation", scenario_2)
add_measure!(end_isolation, CancelSelfIsolation())
# testing strategy that triggers itself after two days if positive
recurrent_test = IStrategy("Recurrent Testing", scenario_2)
add_measure!(recurrent_test,
    Test("Recurrent Test", PCR_test,
        positive_followup = recurrent_test,
        negative_followup = end_isolation),
    offset = 2)
# self-isolation and initial testing strategy
isolation_and_test = IStrategy("Self Isolation", scenario_2)
add_measure!(isolation_and_test, SelfIsolation(10))
add_measure!(isolation_and_test,
    Test("First Test", PCR_test,
        positive_followup = recurrent_test,
        negative_followup = end_isolation),
    offset = 5)
trigger_2 = SymptomTrigger(isolation_and_test)
add_symptom_trigger!(scenario_2, trigger_2)

b = Batch(scenario_1, scenario_2)
run!(b)
rd = ResultData(b)

gemsplot(rd, type = (:DetectedCases, :CumulativeIsolations))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_intreventions_recurrent_tests.png" width="80%"/>
</p>
``` 

The results show that the overall case numbers are similar in both scenarios.
The extensive testing can lower the person-days spent in isolation as not all individuals will stay in isolation for the full 10 days.
However, as all positive tests lead to a reported new case, we observe a substantial number of double reports (green area in the "Detected Cases"-plot).
The testing measure only tests an individual for a pathogen but cannot differentiate whether it is the same infection or not.
It is possible to specify that a test should not lead to a new case being reported.
Please look up the [Test](@ref Test) measure's parameterization options.
The next tutorial considers two test types where one of them does not lead to a reported case (self-applied test).

## Multiple Test Types

Tutorial coming soon ...

## Contact Reduction

Tutorial coming soon ...

## Setting Closure

Tutorial coming soon ...

## Custom Measures

Tutorial coming soon ...

## Varying Mandate Adherence

Tutorial coming soon ...

## Adapting Behavior

Tutorial coming soon ...
