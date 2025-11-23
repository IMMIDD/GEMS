# Result data

## Overview Structs
```@index
Pages   = ["api_resultdata.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_resultdata.md"]
Order   = [:function]
```

## ResultData

### Constructors

```@docs
ResultData(::Simulation; ::String)
ResultData(::PostProcessor; ::String)
ResultData(::Vector{PostProcessor}; ::String, ::Bool)
ResultData(::Vector{Simulation}; ::String, ::Bool)
ResultData(::Batch; ::String, ::Bool)
```

### Functions
```@docs
aggregated_compartment_periods
allempty
attack_rate(::ResultData)
compartment_fill(::ResultData)
compartment_periods(::ResultData)
config_file(::ResultData)
config_file_val
cpu_data(::ResultData)
cumulative_cases(::ResultData)
cumulative_deaths(::ResultData)
cumulative_disease_progressions(::ResultData)
cumulative_quarantines(::ResultData)
cumulative_vaccinations(::ResultData)
customlogger(::ResultData)
data_hash(::ResultData)
dataframes(::ResultData)
deaths(::ResultData)
detected_tick_cases(::ResultData)
detection_rate(::ResultData)
effectiveR(::ResultData)
execution_date(::ResultData)
execution_date_formatted
exportJLD(::ResultData, ::AbstractString)
final_tick(::ResultData)
free_mem_size(::ResultData)
GEMS_version(::ResultData)
git_branch(::ResultData)
git_commit(::ResultData)
git_repo(::ResultData)
hashes(::ResultData)
tick_hosptitalizations(::ResultData)
household_attack_rates(::ResultData)
id(::ResultData)
import_resultdata
infections(::ResultData)
infections_hash(::ResultData)
info(::ResultData)
initial_infections(::ResultData)
julia_version(::ResultData)
kernel(::ResultData)
label(::ResultData)
meta_data(::ResultData)
model_size(::ResultData)
number_of_individuals(::ResultData)
observed_R(::ResultData)
pathogens(::ResultData)
population_file(::ResultData)
population_params(::ResultData)
population_pyramid(::ResultData)
population_size(::ResultData)
region_info(::ResultData)
rolling_observed_SI(::ResultData)
setting_data(::ResultData)
setting_sizes(::ResultData)
sim_data(::ResultData)
someempty
start_condition(::ResultData)
stop_criterion(::ResultData)
strategies(::ResultData)
symptom_triggers(::ResultData)
system_data(::ResultData)
tests(::ResultData)
testtypes(::ResultData)
threads(::ResultData)
tick_cases(::ResultData)
tick_cases_per_setting(::ResultData)
tick_deaths(::ResultData)
tick_generation_times(::ResultData)
tick_pooltests(::ResultData)
tick_serial_intervals(::ResultData)
tick_serotests(::ResultData)
tick_tests(::ResultData)
tick_unit(::ResultData)
tick_vaccinations(::ResultData)
time_to_detection(::ResultData)
timer_output!(::ResultData, ::TimerOutput)
timer_output(::ResultData)
total_infections(::ResultData)
total_mem_size(::ResultData)
total_quarantines(::ResultData)
total_tests(::ResultData)
word_size(::ResultData)
```

## ResultDataStyle

### Constructors
```@docs
ResultDataStyle
DefaultResultData
LightRD
```