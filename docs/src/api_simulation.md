# Simulation
alles aus setup folder
configuration des sim objects

## Overview Structs
```@index
Pages   = ["api_simulation.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_simulation.md"]
Order   = [:function]
```


## Simulation

### Struct

```@docs
Simulation
```

### Functions

```@docs
add_hospitalization_trigger!
add_strategy!
add_symptom_trigger!
add_testtype!
add_tick_trigger!
ags(::PatientZeros)
configfile(::Simulation)
customlogger!(::Simulation, ::CustomLogger)
customlogger(::Simulation)
customlogs
deaths(::Simulation)
deathlogger(::Simulation)
event_queue(::Simulation)
fire_custom_loggers!(::Simulation)
fraction(::InfectedFraction)
hospitalization_triggers(::Simulation)
incidence
increment!(::Simulation)
infectionlogger(::Simulation)
infections(::Simulation)
info(::Simulation)
interval
label(::Simulation)
limit
parameters
pathogen!(::Simulation, ::Pathogen)
pathogen
pooltests
pooltestlogger
population(::Simulation)
populationDF(::Simulation)
populationfile(::Simulation)
process_events!
quarantinelogger(::Simulation)
quarantines
remove_empty_settings!(::Simulation)
reset!(::Simulation)
region_info(::Simulation)
rng(::Simulation)
run!(::Simulation; ::Function, ::Bool)
seroprevalencelogger(::Simulation)
seroprevalencetests(::Simulation)
settings(::Simulation)
settings(::Simulation, ::DataType)
settingscontainer(::Simulation)
should_fire
start_condition
statelogger(::Simulation)
statelogger!(::Simulation, ::StateLogger)
states(::Simulation)
step!
stepmod
stop_criterion(::Simulation)
strategies(::Simulation)
symptom_triggers(::Simulation)
testlogger(::Simulation)
tests(::Simulation)
testtypes(::Simulation)
tick(::Simulation)
tick_triggers(::Simulation)
tickunit(::Simulation)
```

## Start Conditions

### Structs

```@docs
StartCondition
InfectedFraction
PatientZero
PatientZeros
RegionalSeeds
```

### Functions

```@docs
initialize!
seeds
```




## Stop Criteria

### Structs

```@docs
StopCriterion
NoneInfected
TimesUp
```

### Functions

```@docs
evaluate
```