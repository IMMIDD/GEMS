# Post processing

## Overview Structs
```@index
Pages   = ["api_postproc.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_postproc.md"]
Order   = [:function]
```

## Structs
```@docs
PostProcessor
```

## Functions
```@docs
age_incidence
attack_rate(::PostProcessor)
compartment_fill(::PostProcessor)
compartment_periods(::PostProcessor)
cumulative_cases(::PostProcessor)
cumulative_deaths(::PostProcessor)
cumulative_disease_progressions(::PostProcessor)
cumulative_quarantines(::PostProcessor)
cumulative_vaccinations(::PostProcessor)
deathsDF(::PostProcessor)
detected_infections(::PostProcessor)
detected_tick_cases(::PostProcessor)
detection_rate(::PostProcessor)
detection_ticks(::DataFrame)
effectiveR(::PostProcessor)
hospital_df(::PostProcessor)
household_attack_rates(::PostProcessor; ::Int64 = HOUSEHOLD_ATTACK_RATE_SAMPLES)
in_cache(::PostProcessor, ::String)
individuals_per_age_group
infections(::PostProcessor)
load_cache(::PostProcessor, ::String)
observed_R(::PostProcessor)
pooltestsDF(::PostProcessor)
population_pyramid(::PostProcessor)
reported_tick_cases(::PostProcessor)
rolling_observed_SI(::PostProcessor)
settingdata(::PostProcessor)
sim_infectionsDF(::PostProcessor)
simulation(::PostProcessor)
store_cache(::PostProcessor, ::String, ::Any)
testsDF(::PostProcessor)
tick_cases(::PostProcessor)
tick_cases_per_setting(::PostProcessor)
tick_deaths(::PostProcessor)
tick_generation_times(::PostProcessor)
tick_pooltests(::PostProcessor)
tick_serial_intervals(::PostProcessor)
tick_tests(::PostProcessor)
tick_vaccinations(::PostProcessor)
time_to_detection(::PostProcessor)
total_detected_cases(::PostProcessor)
total_quarantines(::PostProcessor)
total_tests(::PostProcessor)
vaccinationsDF(::PostProcessor)
weighted_error_sum
```