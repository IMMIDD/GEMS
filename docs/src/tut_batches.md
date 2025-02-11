# 4 - Running Batches

In most situations, running a simulation once is not sufficient.
This tutorial teaches you how to work with so-called batches of simulations.


## Repeating Simulations

You can instantiate a simulation multiple times and add them to a vector.
The `Batch(...)` function creates a batch from multiple simulations.
Running and post-processing of a batch works the same as for single simulations.
Note that the `rd` variable in the example below now contains a vector of `ResultData` objects.

```julia
using GEMS

sims = Simulation[]
for i in 1:5
    sim = Simulation()
    push!(sims, sim)
end

b = Batch(sims...)
run!(b)
rd = ResultData(b)
gemsplot(rd)
```

!!! warning "TODO: PUT PLOT HERE AS IMAGE"

Simulation runs are automatically named (*Simulation 1, Simulation 2, ...*) if no explicit label is provided.
Passing a `label` keyword to the `Simulation()` function causes all simulation results of the same label to be grouped:

```julia
using GEMS

sims = Simulation[]
for i in 1:5
    sim = Simulation(label = "My Experiment")
    push!(sims, sim)
end

b = Batch(sims...)
run!(b)
rd = ResultData(b)
gemsplot(rd)
```

!!! warning "TODO: PUT PLOT HERE AS IMAGE"


## Sweeping Parameter Spaces

If you want to run simulations and systematically scan parameter spaces, you can use batches to do just that.
Here's an example of how to run a basic simulation with varying `transmission_rate`s:

```julia
using GEMS

sims = Simulation[]
for i in 0:0.1:0.5
    sim = Simulation(transmission_rate = i, label = "Transmission Rate $i")
    push!(sims, sim)
end

b = Batch(sims...)
run!(b)
rd = ResultData(b)
gemsplot(rd, legend = :topright)
```

!!! warning "TODO: PUT PLOT HERE AS IMAGE"


## Running Scenarios

GEMS' batch functionalities offer easy options to compare different scenarios and run multiple simulations for each of them.
The example below compares a baseline scenario with a scenario with a lower `transmission_rate` and we assume that this is due to mask-wearing mandates.
It spawns five simulations for each of the scenarios and puts them into the same batch, runs it, and visualizes the processed results:

```julia
using GEMS

sims = Simulation[]
for i in 1:5
    baseline = Simulation(transmission_rate = 0.2, label = "Baseline")
    masks = Simulation(transmission_rate = 0.15, label = "Mask Wearing")
    push!(sims, baseline)
    push!(sims, masks)
end

b = Batch(sims...)
run!(b)
rd = ResultData(b)
gemsplot(rd)
```

!!! warning "TODO: PUT PLOT HERE AS IMAGE"

Use the `combined = :bylabel` keyword to show both scenarios side-by-side (pass the `ylims` attribute to unify axis-scaling):

```julia
gemsplot(rd, type = :TickCases, combined = :bylabel, ylims = (0, 2000))
```

!!! warning "TODO: PUT PLOT HERE AS IMAGE"

Of course, all of this can also be done with much more complex intervention strategies.
Please look up the interventions tutorial for examples.


## Merging Batches

Sometimes it's easier to build up batches individually and then merge them into one for execution.
Here's an example of how that can be done based on the scenario of the previous chapter:

```julia
using GEMS

sims1 = Simulation[]
for i in 1:5
    baseline = Simulation(transmission_rate = 0.2, label = "Baseline")
    push!(sims1, baseline)
end
b1 = Batch(sims1...)

sims2 = Simulation[]
for i in 1:5
    masks = Simulation(transmission_rate = 0.15, label = "Mask Wearing")
    push!(sims2, masks)
end
b2 = Batch(sims2...)

combined_batch = merge(b1, b2)
run!(combined_batch)
rd = ResultData(combined_batch)
gemsplot(rd, type = :TickCases)
```

!!! warning "TODO: PUT PLOT HERE AS IMAGE"


## *BatchData* Objects

While `ResultData` objects are the processed output of single simulation runs, `BatchData` objects are processed output of Batches.
They contain aggregated data on the simulations, e.g., the average number of total infections including standard devation, confidence intervals and ranges.
While you do not necessarily need a `BatchData` object to plot batches, they do contain a lot of helpful data.
Here's an example:

```julia
using GEMS

sims = Simulation[]
for i in 1:5
    sim = Simulation(label = "My Experiment")
    push!(sims, sim)
end

b = Batch(sims...)
run!(b)
bd = BatchData(b)
total_infections(bd)
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

Run the `info(...)` function to get an overview of values that you can retrieve from a `BatchData` object by calling a function of the same name (e.g., `total_infections(...)`) on the `BatchData` object:

```julia
info(bd)
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

It's also possible to directly pass `BatchData` objects to the `gemsplot()` function:

```julia
gemsplot(bd)
```

!!! warning "TODO: PUT PLOT HERE AS IMAGE"

A `BatchData` object contains `ResultData` objects for each of the individual runs.
Creating a `BatchData` object from a `Batch` (as in the example above), triggers the post processing for each of the simulations contained in the batch, i.e., generating their `ResultData` objects.
You can access them like this:

```julia
runs(bd)
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

However, these `ResultData` objects are generated using the batch-optimized `LightRD` style (look up the tutorial on  `ResultDataStyle`s).
This style does not store raw data (such as the `infections` dataframe) as they are usually not particularly relevant for batches, reducing the required memory significantly.

If you still want the raw data for each of the simulation runs, you can pass the `DefaultResultData` style to the `BatchData(...)` function.
Have a look at this example showing how to still get the raw data when working with batches:

```julia
bd = BatchData(b, rd_style = "DefaultResultData")
rns = runs(bd)
infections(rns[1])
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"


## Custom *BatchDataStyles*

t.b.d.