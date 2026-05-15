# Batches

## Overview Structs
```@index
Pages   = ["api_batch.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_batch.md"]
Order   = [:function]
```

## Batch

### Constructors

```@docs
Batch
```

### Functions

```@docs
add!(::NamedTuple, ::Batch)
append!(::Batch, ::Batch)
merge(::Batch...)
process!(::Batch)
simconfigs(::Batch)
```


## BatchProcessor

### Constructors

```@docs
BatchProcessor
```

### Functions

```@docs
attack_rate(::BatchProcessor)
cumulative_cases(::BatchProcessor)
cumulative_disease_progressions(::BatchProcessor)
cumulative_quarantines(::BatchProcessor)
dark_figure(::BatchProcessor)
effectiveR(::BatchProcessor)
generation_times(::BatchProcessor)
n_runs(::BatchProcessor)
median_run(::BatchProcessor)
r0(::BatchProcessor)
rundata(::BatchProcessor)
seed(::BatchProcessor)
tests(::BatchProcessor)
tick_cases(::BatchProcessor)
tick_unit(::BatchProcessor)
total_infections(::BatchProcessor)
total_quarantines(::BatchProcessor)
total_tests(::BatchProcessor)
```

!!! note "Removed functions"
    Several functions available on `BatchProcessor` in earlier versions
    (`config_files`, `pathogens`, `settingdata`, `population_pyramid`,
    `setting_age_contacts`, `strategies`, etc.) are no longer available because
    `BatchProcessor` no longer stores individual `ResultData` objects by default.

    **Alternatives:**
    - *Configuration metadata* (config files, pathogens, strategies, …):
      use `simconfigs(batch)` — the simulation keyword arguments are stored in
      the `Batch` object.
    - *Post-simulation per-run data* (setting data, population pyramid, …):
      process with `keep_rundata = true` and access via `rundata(bp)`.


## BatchData

### Constructors

```@docs
BatchData
```

### Functions

```@docs
allocations(::BatchData)
attack_rate(::BatchData)
cpu_data(::BatchData)
cumulative_cases(::BatchData)
cumulative_disease_progressions(::BatchData)
cumulative_quarantines(::BatchData)
dark_figure(::BatchData)
dataframes(::BatchData)
effectiveR(::BatchData)
execution_date(::BatchData)
exportJLD(::BatchData, ::AbstractString)
free_mem_size(::BatchData)
generation_times(::BatchData)
GEMS_version(::BatchData)
git_branch(::BatchData)
git_commit(::BatchData)
git_repo(::BatchData)
id(::BatchData)
import_batchdata(::AbstractString)
info(::BatchData)
julia_version(::BatchData)
kernel(::BatchData)
merge(::BatchData...; ::String)
meta_data(::BatchData)
number_of_runs(::BatchData)
per_label(::BatchData)
median_run(::BatchData)
runs(::BatchData)
runtime(::BatchData)
seed(::BatchData)
sim_data(::BatchData)
system_data(::BatchData)
tests(::BatchData)
tick_cases(::BatchData)
threads(::BatchData)
total_infections(::BatchData)
total_mem_size(::BatchData)
total_quarantines(::BatchData)
total_tests(::BatchData)
word_size(::BatchData)
```

## BatchDataStyle

```@docs
DefaultBatchData
```
