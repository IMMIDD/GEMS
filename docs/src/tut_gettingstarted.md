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
It then applies default post-processing methods, generating the `ResultData` object before a summary of the simulation run is being plotted.

```julia
using GEMS
sim = Simulation()
run!(sim)
rd = ResultData(sim)
gemsplot(rd)
```

**Output**

```
[ Info: 12:46:49 | Initializing Simulation with default configuration
[ Info: 12:46:49 | └ Creating population
[ Info: 12:46:49 | └ Creating simulation object
[ Info: 12:46:50 | Running Simulation Simulation 1
100.0%┣█████████████████████████████┫ 365 days/365 days [00:01<00:00, 448 days/s]

[ Info: 12:46:51 | Processing simulation data
        12:46:51 | └ Done 
```

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_gs_hello-world2.png" width="80%"/>
</p>
``` 


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

**Output**

```
[ Info: 12:54:33 | Initializing Simulation with default configuration and additional parameter(s): transmission_rate, avg_household_size
[ Info: 12:54:33 | └ Creating population
[ Info: 12:54:33 | └ Creating simulation object
[ Info: 12:54:34 | Running Simulation Simulation 2
100.0%┣█████████████████████████████┫ 365 days/365 days [00:01<00:00, 656 days/s]
[ Info: 12:54:35 | Processing simulation data
        12:54:35 | └ Done  
``` 

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_gs_custom-parameters2.png" width="80%"/>
</p>
``` 

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
Here's an example that spawns two simulations, runs them, and calls the `gemsplot()` function with a vector of `ResultData` objects, displaying both runs:

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

**Output**

```
[ Info: 13:08:05 | Initializing Simulation with default configuration and additional parameter(s): label
[ Info: 13:08:06 | └ Creating population
[ Info: 13:08:13 | └ Creating simulation object
[ Info: 13:08:18 | Initializing Simulation with default configuration and additional parameter(s): transmission_rate, avg_household_size, label
[ Info: 13:08:18 | └ Creating population
[ Info: 13:08:18 | └ Creating simulation object
[ Info: 13:08:21 | Running Simulation Baseline
100.0%┣█████████████████████████████┫ 365 days/365 days [00:02<00:00, 151 days/s]
[ Info: 13:08:23 | Running Simulation More Infectious
100.0%┣█████████████████████████████┫ 365 days/365 days [00:01<00:00, 706 days/s]
[ Info: 13:08:29 | Processing simulation data                                                                                                                               
        13:09:06 | └ Done                                                                                                                                                    
        13:09:07 | └ Done 
```

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_gs_comparing-scenarios.png" width="80%"/>
</p>
``` 

## Getting the Raw Data

Both raw data (via the internal loggers) and processed data (via the `ResultData` object) are accessible.
Try this to run a simulation and get the infections as a dataframe. Then visualize it using VSCode's internal table printing feature (of course only if you are using [Visual Studio Code](https://code.visualstudio.com/) as your IDE):

```julia
using GEMS
sim = Simulation()
run!(sim)
df = sim |> infectionlogger |> dataframe
vscodedisplay(df)
```

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_gs_vs_code_table.png" width="80%"/>
</p>
```

Alternatively, you can use the DataFrames package to get a look at the data in REPL:

```julia
using DataFrames
describe(df)
```

!!! info "What do the columns mean?"
    Put a `?` into the Julia REPL and call `help?> InfectionLogger` to get an overview of what the `InfectionLogger` stores or look up the Logger section of the API documentation.
