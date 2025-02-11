# Batch Runs

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

## Structs
```@docs
Batch
BatchData
BatchProcessor
DefaultBatchData
DefaultBatchDataStyle
```
## Constructors
```@docs
BatchProcessor(::Batch; ::Bool)
```

## Functions
```@docs
add!(::Simulation, ::Batch)
customlogger!(::Batch, ::CustomLogger)
exportJLD(::BatchData, ::AbstractString)
exportJSON(::BatchData, ::AbstractString)
import_batchdata(::AbstractString)
remove!(::Simulation, ::Batch)
run!(::Batch; ::Function)
runs(::BatchData)
sim_data(::BatchData)
simulations(::Batch)
system_data(::BatchData)
```


## Deprecated Batches
```@docs
allocations
attack_rate(::BatchData)
attack_rate(::BatchProcessor)
batch
config_files
cpu_data(::BatchData)
create_batch_configs
cumulative_disease_progressions(::BatchProcessor)
cumulative_disease_progressions(::BatchData)
cumulative_quarantines
cumulative_quarantines(::BatchData)
cumulative_quarantines(::BatchProcessor)
dataframes(::BatchData)
effectiveR(::BatchData)
effectiveR(::BatchProcessor)
execution_date(::BatchData)
generate_batch_info
id(::BatchData)
julia_version(::BatchData)
meta_data(::BatchData)
number_of_individuals(::BatchProcessor)
number_of_runs(::BatchData)
parameterset(::BatchProcessor, ::Vector{String})
pathogens(::BatchProcessor)
pathogens_by_name
population_files
population_pyramid(::BatchProcessor)
run_ids
rundata
runtime
settingdata(::BatchProcessor)
start_conditions
stop_criteria
symptom_triggers(::BatchProcessor)
systemdata(::BatchData)
tests(::BatchData)
tests(::BatchProcessor)
testtypes(::BatchProcessor)
threads(::BatchData)
tick_cases(::BatchData)
tick_cases(::BatchProcessor)
tick_unit(::BatchProcessor)
total_infections(::BatchData)
total_infections(::BatchProcessor)
total_mem_size(::BatchData)
total_quarantines(::BatchData)
total_quarantines(::BatchProcessor)
total_tests(::BatchData)
total_tests(::BatchProcessor)
totalonly!(::BatchTickTests, ::Bool)
totalonly(::BatchTickTests)
word_size(::BatchData)
```