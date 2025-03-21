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

**Output**

```
[ Info: 23:40:26 | Initializing Simulation [Simulation 79] with default configuration 
[ Info: 23:40:26 | └ Creating population
[ Info: 23:40:28 | └ Creating simulation object
[ Info: 23:40:29 | Running Simulation Simulation 79
100.0%┣████████████████████████████████████████┫ 365 days/365 days [00:29<00:00, 13 days/s]
75908×19 DataFrame
   Row │ infection_id  tick   id_a   id_b   infectious_tick  removed_tick  death_tick  ⋯
       │ Int32         Int16  Int32  Int32  Int16            Int16         Int16       ⋯
───────┼───────────────────────────────────────────────────────────────────────────────────
     1 │            1      0     -1  74571                5            13          -1   ⋯         
     2 │            2      0     -1  48307                1             7          -1   ⋯  
   ⋮   │      ⋮          ⋮      ⋮      ⋮           ⋮              ⋮            ⋮             ⋮ 
 75907 │        75907    177   4685  36171              177           183          -1   ⋯ 
 75908 │        75908    181   4685  33557              185           191          -1   ⋯  
                                                        10 columns and 75904 rows omitted
```

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

**Output**

```
[ Info: 23:41:39 | Initializing Simulation [Simulation 80] with default configuration 
[ Info: 23:41:39 | └ Creating population
[ Info: 23:41:40 | └ Creating simulation object
[ Info: 23:41:41 | Running Simulation Simulation 80
100.0%┣█████████████████████████████████████████┫ 365 days/365 days [00:57<00:00, 6 days/s]
75798×47 DataFrame
Row │ infection_id  tick   id_a   id_b    infectious_tick  removed_tick  ⋯
    │ Int32         Int16  Int32  Int32   Int16            Int16         ⋯
    ┼────────────────────────────────────────────────────────────────────────
  1 │         7180     36  61265       1               38            44  ⋯    
  2 │        71586     88  77749       2               91            98  ⋯
⋮     │        ⋮          ⋮      ⋮      ⋮                 ⋮              ⋮      
75798 │        42048     60  61117  100000             64            72  ⋯      
38 columns and 75794 rows omitted
```

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

**Output**

```
[ Info: 23:43:16 | Initializing Simulation [Simulation 81] with default configuration 
[ Info: 23:43:16 | └ Creating population
[ Info: 23:43:18 | └ Creating simulation object
[ Info: 23:43:19 | Running Simulation Simulation 81
100.0%┣█████████████████████████████████████████┫ 365 days/365 days [01:25<00:00, 4 days/s]
365×7 DataFrame
 Row │ tick   effective_R  in_hh_effective_R  out_hh_effective_R  rolling_R   ⋯  
     │ Int64  Float64      Float64            Float64             Float64     ⋯  
─────┼──────────────────────────────────────────────────────────────────────────
   1 │     1      2.21429           0.571429            1.64286     2.21429   ⋯  
   2 │     2      1.45833           0.541667            0.916667    1.83631   ⋯  
  ⋮  │   ⋮         ⋮               ⋮                  ⋮               ⋮           
 364 │   364      0.0               0.0                 0.0         0.0       ⋯  
 365 │   365      0.0               0.0                 0.0         0.0       ⋯  
361 rows omitted
```


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

**Output**

```
[ Info: 23:45:19 | Initializing Simulation [Simulation 82] with default configuration 
[ Info: 23:45:19 | └ Creating population
[ Info: 23:45:21 | └ Creating simulation object
[ Info: 23:45:22 | Running Simulation Simulation 82
100.0███████████████████████████████████████████┫ 365 days/365 days [00:54<00:00, 7 days/s]
143×2 DataFrame
 Row │ tick   count 
     │ Int16  Int64
─────┼──────────────
   1 │     0      3
   2 │     1      7
   ⋮  │   ⋮      ⋮
 142 │   155      1
 143 │   171      1
    139 rows omitted
```

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

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_pp_plot.png" width="80%"/>
</p>
``` 


The `ResultData` object now contains a dataframe that contains the collected data of the custom logger with one column per argument function that was passed to the `CustomLogger(...)`

```julia
customlogger(rd)
```

**Output**

```
365×2 DataFrame
 Row │ infected_in_large_households  tick 
     │ Any                           Any
─────┼────────────────────────────────────
   1 │ 82                            0
   2 │ 92                            1
  ⋮  │              ⋮                 ⋮
 364 │ 0                             363
 365 │ 0                             364
                          361 rows omitted
```


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