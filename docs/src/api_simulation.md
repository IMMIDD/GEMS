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


## Structs
```@docs
HospitalizationTrigger
InfectedFraction
NoneInfected
Parameter
Simulation
StartCondition
StopCriterion
TimesUp
```

## Constructors
```@docs
Simulation(; simargs...)
```

## Functions
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
evaluate
event_queue(::Simulation)
fire_custom_loggers!(::Simulation)
fraction(::InfectedFraction)
hospitalization_triggers(::Simulation)
incidence
increment!(::Simulation)
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
populationfile(::Simulation)
quarantinelogger(::Simulation)
quarantines
remove_empty_settings!(::Simulation)
reset!(::Simulation)
region_info(::Simulation)
run!(::Simulation; ::Function, ::Bool)
should_fire
start_condition
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