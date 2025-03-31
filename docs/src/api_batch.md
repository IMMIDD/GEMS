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
Batch(;::Integer::Bool, simargs...)
Batch(::Simulation...)
Batch(::Vector{Simulation})
Batch(::Batch...)
Batch(::Vector{Batch})
```

### Functions

```@docs
add!(::Simulation, ::Batch)
append!(::Batch, ::Batch)
customlogger!(::Batch, ::CustomLogger)
merge(::Batch...)
remove!(::Simulation, ::Batch)
run!(::Batch; ::Function)
simulations(::Batch)
```


## BatchProcessor

### SConstructors

```@docs
BatchProcessor(::Vector{ResultData})
BatchProcessor(::Batch; ::Bool)
```

### Functions

```@docs
allocations(::BatchProcessor)
attack_rate(::BatchProcessor)
config_files(::BatchProcessor)
cumulative_disease_progressions(::BatchProcessor)
cumulative_quarantines(::BatchProcessor)
effectiveR(::BatchProcessor)
number_of_individuals(::BatchProcessor)
pathogens(::BatchProcessor)
pathogens_by_name(::BatchProcessor)
population_files(::BatchProcessor)
population_pyramid(::BatchProcessor)
run_ids(::BatchProcessor)
rundata(::BatchProcessor)
runtime(::BatchProcessor)
setting_age_contacts(::BatchProcessor, ::DataType)
settingdata(::BatchProcessor)
start_conditions(::BatchProcessor)
stop_criteria(::BatchProcessor)
strategies(::BatchProcessor)
symptom_triggers(::BatchProcessor)
tests(::BatchProcessor)
testtypes(::BatchProcessor)
tick_cases(::BatchProcessor)
tick_unit(::BatchProcessor)
total_infections(::BatchProcessor)
total_quarantines(::BatchProcessor)
total_tests(::BatchProcessor)
```

## BatchData

### Constructors

```@docs
BatchData(::BatchProcessor; ::String)
BatchData(::Batch; ::String, ::String)
BatchData(::Vector{ResultData}; ::String)
BatchData(::BatchData...; ::String)
BatchData(::Vector{BatchData}; ::String)
```

### Functions

```@docs
allocations(::BatchData)
attack_rate(::BatchData)
cpu_data(::BatchData)
cumulative_disease_progressions(::BatchData)
cumulative_quarantines(::BatchData)
dataframes(::BatchData)
effectiveR(::BatchData)
execution_date(::BatchData)
exportJLD(::BatchData, ::AbstractString)
free_mem_size(::BatchData)
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
runs(::BatchData)
runtime(::BatchData)
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