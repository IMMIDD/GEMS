# 5 - Running Batches

In most situations, running a simulation once is not sufficient.
This tutorial teaches you how to work with so-called batches of simulations.


## Repeating Simulations

Use `Batch(n_runs = N, ...)` to create a batch of N identical simulation runs.
Any keyword argument accepted by `Simulation()` can be passed here.
Call `BatchData(b)` to run all simulations and collect the results:

```julia
using GEMS

b = Batch(n_runs = 5)
bd = BatchData(b)
gemsplot(bd)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_batches.png" width="80%"/>
</p>
``` 


Passing a `label` keyword groups all runs under that name:

```julia
using GEMS

b = Batch(n_runs = 5, label = "My Experiment")
bd = BatchData(b)
gemsplot(bd)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_batches_labels.png" width="80%"/>
</p>
``` 


## Sweeping Parameter Spaces

To scan parameter spaces, create one single-run batch per configuration and merge them:

```julia
using GEMS

b = merge([Batch(n_runs = 1, transmission_rate = tr, label = "Transmission Rate $tr")
           for tr in 0:0.1:0.5]...)
bd = BatchData(b)
gemsplot(bd, legend = :topright)
```


**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_batches_parameter-spaces.png" width="80%"/>
</p>
``` 

You can also vary multiple parameters at once and show the results in a heatmap.
This example runs simulations varying the `transmission_rate` and daily `household_contacts`, and plots the calculated `r0` value of all combinations in a heatmap:

```julia
using GEMS

xvals = []
yvals = []
outvals = []

# vary transmission rate
for tr in 0.05:0.01:0.15
    # vary household contacts
    for con in 0:0.5:5
        sim = Simulation(transmission_rate = tr, household_contacts = con)
        run!(sim)
        rd = ResultData(sim, style = "LightRD")

        # extract data for heatmap
        push!(xvals, tr)
        push!(yvals, con)
        push!(outvals, r0(rd))
    end
end

gemsheatmap(xvals, yvals, outvals,
    xlabel = "Transmission Rate",
    ylabel = "Daily Household Contacts",
    colorbar_title = "Basic Reproduction Number",
    color = :r0) 
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_batches_sweep_heatmap.png" width="80%"/>
</p>
``` 


!!! info "How can I run more than one repetition per combination?"
    You can enclose the experiment in another loop, running each combination as many times as you want. The `gemsheatmap()` function can take multiple entries of the same (`xvals`, `yvals`) combinations. It automatically generates the mean value across observations. You can also change the aggregation function. Please lookup the `gemsheatmap()` documentation.

## Running Scenarios

GEMS' batch functionalities offer easy options to compare different scenarios and run multiple simulations for each of them.
The example below compares a baseline scenario with a scenario with a lower `transmission_rate` and we assume that this is due to mask-wearing mandates.
It spawns five simulations for each of the scenarios, merges them into one batch, and visualizes the results:

```julia
using GEMS

baseline = Batch(n_runs = 5, transmission_rate = 0.2, label = "Baseline")
masks = Batch(n_runs = 5, transmission_rate = 0.15, label = "Mask Wearing")
bd = BatchData(merge(baseline, masks))
gemsplot(bd)
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_batches_scenarios.png" width="80%"/>
</p>
``` 


When a `BatchData` object contains multiple labels, `gemsplot` automatically shows
one mean±CI ribbon per label, coloured differently:

```julia
gemsplot(bd, type = :TickCases)
```


**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_batches_combined.png" width="60%"/>
</p>
``` 


Of course, all of this can also be done with much more complex intervention strategies.
Please look up the interventions tutorial for examples.


## Merging Batches

Sometimes it's easier to build up batches individually and then merge them into one for execution.
Here's an example of how that can be done based on the scenario of the previous chapter:

```julia
using GEMS

b1 = Batch(n_runs = 5, transmission_rate = 0.2, label = "Baseline")
b2 = Batch(n_runs = 5, transmission_rate = 0.15, label = "Mask Wearing")
bd = BatchData(merge(b1, b2))
gemsplot(bd, type = :TickCases)
```


**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_batches_2.png" width="60%"/>
</p>
``` 



## *BatchData* Objects

While `ResultData` objects are the processed output of single simulation runs, `BatchData` objects are processed output of batches.
They contain aggregated data on the simulations, e.g., the average number of total infections including standard deviation, confidence intervals and ranges.
Here's an example:

```julia
using GEMS

b = Batch(n_runs = 5, label = "My Experiment")
bd = BatchData(b)
total_infections(bd)
```

**Output**

```
Dict{String, Real} with 6 entries:
  "upper_95" => 76052.5
  "max"      => 76088
  "min"      => 75363
  "lower_95" => 75415.1
  "mean"     => 75733.8
  "std"      => 256.672
```

Run the `info(...)` function to get an overview of values that you can retrieve from a `BatchData` object by calling a function of the same name (e.g., `total_infections(...)`) on the `BatchData` object:

```julia
info(bd)
```

**Output**

```
BatchData Entries
└ meta_data
  └ GEMS_version
  └ id
  └ execution_date
  └ seed
└ dataframes
  └ tick_cases
  └ effectiveR
  └ cumulative_disease_progressions
  └ cumulative_quarantines
  └ tests
  └ dark_figure
  └ cumulative_cases
  └ generation_times
  └ per_label
└ sim_data
  └ total_tests
  └ number_of_runs
  └ attack_rate
  └ total_infections
  └ total_quarantines
  └ median_run
  └ tick_unit
└ system_data
...
```

It's also possible to directly pass `BatchData` objects to the `gemsplot()` function:

```julia
gemsplot(bd)
```


**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_batches_batchdata.png" width="80%"/>
</p>
``` 

By default, `gemsplot(bd)` shows a mean line with a 95% confidence interval ribbon.
To see the individual simulation traces, process with `keep_rundata = true` and pass
`runs(bd)` to `gemsplot`:

```julia
bd = BatchData(b; keep_rundata = true)
gemsplot(runs(bd))  # one faded line per run, coloured by label
```

By default, `runs(bd)` returns `nothing` to keep memory usage low.
Use `keep_rundata = true` only when you need the individual `ResultData` objects, for
example to access per-run raw data:

```julia
bd = BatchData(b, rd_style = "DefaultResultData", keep_rundata = true)
rns = runs(bd)
infections(rns[1])
```


## Custom *BatchDataStyles*

t.b.d.


## Reproducibility

Every batch run uses a randomly generated seed internally so that individual simulation
runs are reproducible. Pass `seed` to get the same sequence of results every time:

```julia
using GEMS

b = Batch(n_runs = 5)
bd1 = BatchData(b; seed = 42)
bd2 = BatchData(b; seed = 42)
total_infections(bd1) == total_infections(bd2)  # true
seed(bd1)  # → 42
```


## Median Run

By default, GEMS identifies the simulation whose total infections are closest to the
median across all runs, re-runs it with the same seed (producing the exact same result),
and stores it as the *median run*.
This is a single `ResultData` object that can be used as a stand-in for
a typical run:

```julia
using GEMS

b = Batch(n_runs = 10)
bp = process!(b)
rep = median_run(bp)
gemsplot(rep, type = :TickCases)
```

You can customise the selection criterion by passing a different `median_by`
function, or disable it entirely with `median_by = nothing`:

```julia
# Select the run with median deaths instead
bp = process!(b; median_by = pp -> nrow(deathsDF(pp)))

# Disable median run selection
bp = process!(b; median_by = nothing)
```

## Multi-Label Median Runs

If your batch contains multiple labels, you can extract the median run for each label simultaneously using the median_runs() function. Because this function returns a vector of representative ResultData objects, you can pass it directly to `gemsplot()`.

```julia
baseline = Batch(n_runs = 5, transmission_rate = 0.2, label = "Baseline")
masks = Batch(n_runs = 5, transmission_rate = 0.15, label = "Mask Wearing")

b = merge(baseline, masks)
bd = BatchData(b)

gemsplot(median_runs(bd))
```

**Plot**

```@raw html
<p align="center">
    <img src="../assets/tutorials/tut_batches_median_runs.png" width="80%"/>
</p>
``` 