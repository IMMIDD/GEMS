# German Epidemic Microsimulation System

Link to Documentation / Pipeline Badge / Coverage Badge

The **G**erman **E**pidemic **M**icrosimulation **S**ystem (GEMS) is a high-performance geo-referential agent-based infectious disease modeling framework with.
It is being developed in the BMBF-funded OptimAgent research projejct.
It comes with a full model of the German Population and allows to simulate the spread of infectious diseases and potential countermeasures such as isolation, testing, school- or workplace closure, contact-tracing, and many others.
GEMS provides interfaces to load custom populations, adapt infection rules, or change contact patterns.
It also comes with comprehensive post-processing and plotting features.
All simulated data can be easily exported to be used in other applications. 

This page contains a few examples on how to use GEMS.
You'll find an extensive list of tutorials and examples in the official [GEMS documentation](https://immidd.github.io/GEMS/).



## Quick Start

Assuming you have [Julia](https://julialang.org/downloads/) readily installed on your machine, getting GEMS is quite straight forward.
Load the package manager and install the GEMS-package:

```julia
using Pkg
Pkg.add(url = "https://github.com/IMMIDD/GEMS")
using GEMS
```

> [!NOTE]
> Simulations in GEMS and the post-processing routines are optimizeed for [multi-threading](https://docs.julialang.org/en/v1/manual/multi-threading/). Taking advantage of these features requires the Julia process to be started with multiple threads like `$ julia --threads 4` or like this to automatically start Julia with the maximum number of threads `$ julia --threads auto`.


## Simulations

This code creates the default simulation, runs it, processes the data and outputs a plot:

```julia
using GEMS
sim = Simulation()
run!(sim)
rd = ResultData(sim)
gemsplot(rd, xlims = (0, 200))
```

**Output**

```
[ Info: 09:52:18 | Initializing Simulation [Simulation 1]
[ Info: 09:52:18 | └ Creating population
[ Info: 09:52:19 | └ Creating simulation object
[ Info: 09:52:19 | Running Simulation Simulation 1
100.0%┣████████████████████████┫ 365 days/365 days [00:01<00:00, 387 days/s]
[ Info: 09:52:20 | Processing simulation data
        09:52:22 | └ Done  
```

**Plot**

![Hello World Simulation](./docs/src/assets/tutorials/tut_gs_hello-world.png)

The `gemsplot()` takes post-processed data (the `ResultData` object) and generates plots.
You can pass an optional type argument(e.g., `type = :TickCases`) to generate a specific plot.
Look up the documentation for the plot types that are available.

The `Simulation()` object can be created with many optional parameters.
Here's an example where we change the transmission rate and the average household size in the generated population:

```julia
using GEMS
sim = Simulation(transmission_rate = 0.3, avg_household_size = 5)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = :TickCases, xlims = (0, 200), size = (600, 300))
```

![Custom Parameter Simulation](./docs/src/assets/tutorials/tut_gs_custom-parameters.png)


## Populations

The above examples use a default (radom) population which is being generated on-the-fly.
GEMS comes with population models for all German states and a full population model.
This example loads the population model for the state of Schleswig-Holstein and prints a map of the population density:

```julia
using GEMS
sim = Simulation(population = "SH")
gemsmap(sim, type = :PopDensityMap, clims = (0, 250))
```

![SH Density Map](./docs/src/assets/tutorials/tut_pops_SH_map.png)


If you want to add your own population, you can do that via a CSV-file or pass a `DataFrame` like this:

```julia
using GEMS, DataFrames
pop_df = DataFrame(
    id = collect(1:100_000),
    age = rand(1:100, 100_000),
    sex = rand(1:2, 100_000),
    household = append!(collect(1:50_000), collect(1:50_000))
)
my_pop = Population(pop_df)
sim = Simulation(population = my_pop)
```

The above example generates a population of 100,000 agents in 50,000 two-person households and randomly assigned ages (between 0 and 100) and sexes.


## Batches

In most cases, you probably want to run you simulation experiment multiple times.
Here's how to do that using GEMS' `Batch(...)` construct:

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
gemsplot(rd, type = :TickCases, xlims = (0, 200), size = (600, 200))
```

![Simple Batch](./docs/src/assets/tutorials/tut_batches_repeats.png)


Using batches, you can also sweep parameter spaces, e.g., for the transmission rate that applies when two individuals meet:

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
gemsplot(rd, type = (:TickCases, :EffectiveReproduction), xlims = (0, 200), size = (600, 600))
```

![Sweeping Parameter Spaces](./docs/src/assets/tutorials/tut_batches_sweeping.png)

The above example scratch the surface of GEMS.
For more examples, please refer to the tutorials in the [package documentation](https://immidd.github.io/GEMS/).


## Resources Requirements

To run GEMS, you will need ~1GB per million agents.
The execution time scales with the number of infected agents.

## License

All files that belong to the GEMS are available under GPL-3.0 license.