# 7 - Logging & Post-Processing

GEMS offers a variety of options to collect data during simulation runs and process them to obtain aggregated statistics.
This tutorial teaches you how to access the data and customize how data is being collected and processed.

## Internal Loggers

Accessing a simulation's internal loggers is easy.
They can be accessed via `infectionlogger(sim)`,  `deathlogger(sim)`,  `testlogger(sim)`,  `pooltestlogger(sim)`,  `quarantinelogger(sim)`,  or `customlogger(sim)`.
Here's the data that is being logged for all infections:

```julia
using GEMS
sim = Simulation()
run!(sim)
inf_logger = infectionlogger(sim)
dataframe(inf_logger)
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

!!! info "Where can I find out what these columns mean?"
    Put a `?` into the Julia REPL and call `help?> dataframe(::InfectionLogger)` to get an overview of the columns that are available in the `InfectionLogger`'s dataframe. Replace the argument `::InfectionLogger` with any of the other logger types to see their descriptions or look up the Logger section in the API documentation.


## The PostProcessor

The `PostProcessor` is the binding element between the raw data coming from the simulation's internal loggers and the `ResultData` object.
It is instantiated with the `Simulation` object and performs some initial operations and joins on the raw data, and stores the results in internal dataframes (`infectionsDF`, `populationDF`, `deathsDF`, `testsDF`, `pooltestsDF`, `quarantinesDF`).
An exception is the `sim_infectionsDF`-dataframe which only contains infections that happend during the simulation, exluding all initial, seeding infections.
This example shows how the `PostProcessor`'s internal infections-dataframe is already joined with data from the population-dataframe:

```julia
using GEMS
sim = Simulation()
run!(sim)
pp = PostProcessor(sim)

infectionsDF(pp)
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

You might have noticed, that this dataframe contains characteristics about the infecting and infected individuals (e.g., `age` or `sex`) or whether they were detected.
It is now much easier to use this data to calculate more sophisticated statistics such as an age-age contact matrix for infections.
Many processing functions are already available.
Here's how you can calculate the effective reproduction rate per time unit using the `PostProcessor`:

```julia
using GEMS
sim = Simulation()
run!(sim)
pp = PostProcessor(sim)

effectiveR(pp)
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

!!! info "Where's the list of availble post-processing functions?"
    Look up the Post-Processor section in the API documentation for a full list of available options.


## Custom Post-Processing

In some cases, you might want to add custom functionalities to the `PostProcessor`.
The following example add a new post-processor function that calculates the number of infections where a older person infected a younger person:

```julia
using GEMS, DataFrames

function old_infects_young(pp::PostProcessor)
    infs = sim_infectionsDF(pp) # load the simulated infections
    filtered = infs[infs.age_a .> infs.age_b, :] # filter for Age A > Age B
    grouped = groupby(filtered, :tick) # group by simulation time (tick)
    res = combine(grouped, nrow => :count) # combine count
    return res
end

sim = Simulation()
run!(sim)
pp = PostProcessor(sim)

old_infects_young(pp)
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

We advise doing any post-processing via the `PostProcessor` infrastructure whenever possible, as this will make it very easy to forward you custom results to a custom `ResultData` object.
These things will be explained in the subsequent sections.

## The ResultData object

## Custom ResultDataStyles

- how to get custom post-processing functions in here?

## Custom Loggers

A lot of data is recorded automatically, i.e., infections or deaths.
If you want to collect data during the simulation run that is not available via the default loggers, you can add custom mechanics.
The example below tracks how many infected individuals live in households that have 3 or more members.
Doing so requires to set up a `CustomLogger(...)`.
It takes an arbitrary number of arguments that must be one-argument functions whereas the argument has to be the simulation object.
These functions are called once every step when running a simulation.

```julia
using GEMS
sim = Simulation()

function logging_func(sim)
    cnt = 0 # counting variable
    inds = individuals(sim)
    for i in inds
        h = household(i, sim)
        if infected(i) && size(h) >= 3
            cnt += 1
        end
    end
    return cnt
end

cl = CustomLogger(infected_in_large_households = logging_func)
customlogger!(sim, cl)

run!(sim)
rd = ResultData(sim)

gemsplot(rd, type = (:TickCases, :CustomLoggerPlot))
```

!!! warning "TODO: PUT PLOT HERE AS IMAGE"

The `ResultData` object now contains a dataframe that contains the collected data of the custom logger with one column per argument function that was passed to the `CustomLogger(...)`

```julia
customlogger(rd)
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

You might have noticed, that loggers can severely slow down the simulation runtime if implemented inefficiently as they are executed in every step and potentially require iterations through all individuals every time.
Julia provides a number of handy techniques that can speed up calculations significantly.
If you feel confident using so-called lambda-functions, you can rewrite the above example to prevent unnecessary memory allocations.
The code below does exactly the same as the code above, but takes a fraction of the time. 

```julia
using GEMS
sim = Simulation()

pred_func(i, sim) = infected(i) && size(household(i, sim)) >= 3

cl = CustomLogger(infected_in_large_households =
    sim -> count(i -> pred_func(i, sim), population(sim)))
customlogger!(sim, cl)

run!(sim)
rd = ResultData(sim)

gemsplot(rd, type = (:TickCases, :CustomLoggerPlot))
```