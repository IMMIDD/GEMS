# 1 - Getting Started

Assuming you have Julia readily installed on your machine, getting GEMS is quite straight forward.
Load the package manager and install the GEMS-package:

```julia
using Pkg
Pkg.add(url = "https://github.com/IMMIDD/GEMS")
using GEMS
```

The tutorials make intense use of Julia's pipelining feature, utilized through the `|>` operator.
It allows for the output of one function to be seamlessly passed as the input to another, enabling a clear and concise expression of a sequence of operations.
That means: `mean(squared(vector))` is the same as `vector |> squared |> mean`.
GEMS tutorials rely heavily on this feature, therefore it's important to make sure everybody is familiar with it!

GEMS relies heavily on the `DataFrames.jl` and `Plots.jl` packages.
Being vaguely familiar with their core functionalities might help when following these tutorials.


## Hello World

This code creates the default simulation and runs it.
It then applies default post-processing methods, genrating the `ResultData` object before a summary of the simulation run is being plotted.

```julia
using GEMS
sim = Simulation()
run!(sim)
rd = ResultData(sim)
gemsplot(rd)
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

!!! warning "TODO: PUT PLOT HERE AS IMAGE"


## Changing Parameters

You can pass a variety of keyword arguments to the `Simulation()` function.
Try changing the general transmission rate and increasing the average household size like this:

```julia
using GEMS
sim = Simulation(transmission_rate = 0.3, avg_household_size = 5)
run!(sim)
rd = ResultData(sim)
gemsplot(rd)
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

!!! warning "TODO: PUT PLOT HERE AS IMAGE"

!!! info "Where's the list of parameters I can change?"
    Put a `?` into the Julia REPL and call `help?> Simulation` to get an overview of arguments that you can pass to customize a simulation or look up the [Simulation](@ref Simulation(; simargs...)) section of the API documentation.


## Passing Parameters as Dictionaries

Sometimes having long function calls with many parameters is confusing.
In GEMS, you can define a dictionary of parameters and pass it to the `Simulation()` function.
The respective arguments must be stored as symbols (with a leading `:`):

```julia
pars = Dict(
    :transmission_rate => 0.3,
    :avg_household_size => 5
)
sim = Simulation(pars)
run!(sim)
```

## Comparing Scenarios

GEMS makes it very easy to run and compare infection scenarios.
Here's an example that spanws two simulations, runs them, and calls the `gemsplot()` function with a vector of `ResultData` objects:

```julia
using GEMS
sim1 = Simulation(label = "Baseline")
sim2 = Simulation(transmission_rate = 0.3, avg_household_size = 5, label = "More Infectious")
run!(sim1)
run!(sim2)
rd1 = ResultData(sim1)
rd2 = ResultData(sim2)
gemsplot([rd1, rd2])
```

!!! warning "TODO: PUT CONSOLE OUTPUT HERE"

!!! warning "TODO: PUT PLOT HERE AS IMAGE"

Pass the `combined = :bylabel` keyword to show the results side-by-side:

```julia
gemsplot([rd1, rd2], combined = :bylabel)
```

!!! warning "TODO: PUT PLOT HERE AS IMAGE"


## Getting the Raw Data

Both raw data (via the internal loggers) and processed data (via the `ResultData` object) are accessible.
Try this to run a simulation and get the infections as a dataframe. Then visualize it using VSCode's internal table printing feature:

```julia
using GEMS
sim = Simulation()
run!(sim)
df = sim |> infectionlogger |> dataframe
vscodedisplay(df)
```

!!! warning "TODO: PUT VSCODE SCREENSHOT HERE AS IMAGE"

!!! info "What do the columns mean?"
    Put a `?` into the Julia REPL and call `help?> InfectionLogger` to get an overview of what the `InfectionLogger` stores or look up the Logger section of the API documentation.