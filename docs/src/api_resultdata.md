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

## Structs
```@docs
DefaultResultData
EssentialResultData
LightRD
OptimisedResultData
ResultData
ResultDataStyle
```

## Constructors
```@docs
ResultData(::Simulation; ::String)
ResultData(::Vector{Simulation}; ::String, ::Bool)
```

## Functions
```@docs
aggregated_compartment_periods
allempty
attack_rate(::ResultData)
clean_result!(::Dict)
compartment_fill(::ResultData)
compartment_periods(::ResultData)
config_file(::ResultData)
config_file_val
cpu_data(::ResultData)
cpudata
cumulative_cases(::ResultData)
cumulative_deaths(::ResultData)
cumulative_disease_progressions(::ResultData)
cumulative_quarantines(::ResultData)
cumulative_vaccinations(::ResultData)
customlogger(::ResultData)
data(runinfo)
data_hash(::ResultData)
dataframes(::ResultData)
deaths(::ResultData)
detected_tick_cases(::ResultData)
detection_rate(::ResultData)
effectiveR(::ResultData)
execution_date(::ResultData)
execution_date_formatted
exportJLD(::ResultData, ::AbstractString)
exportJSON(::ResultData, ::AbstractString)
extract
extract_unique
final_tick(::ResultData)
GEMS_version(::ResultData)
get_style(::String)
hashes(::ResultData)
hospital_df(::ResultData)
household_attack_rates(::ResultData)
id(::ResultData)
import_resultdata
infections(::ResultData)
infections_hash(::ResultData)
initial_infections(::ResultData)
julia_version(::ResultData)
label(::ResultData)
meta_data(::ResultData)
model_size(::ResultData)
number_of_individuals(::ResultData)
observed_R(::ResultData)
obtain_fields(::ResultData, ::Dict)
obtain_fields(::ResultData, ::String)
pathogens(::ResultData)
population_file(::ResultData)
population_params(::ResultData)
population_pyramid(::ResultData)
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
vaccinations(::ResultData)
vaccination_strategy(::ResultData)
vaccine(::ResultData)
word_size(::ResultData)
```