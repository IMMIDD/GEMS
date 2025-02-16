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
AbstractScheduler
Asymptomatic
Critical
DiseaseProgressionStrat
HospitalizationTrigger
Mild
NoneInfected
Parameter
Runinfo
Severe
Simulation
StartCondition
StopCriterion
SymptomCategory
TimesUp
waning
```

## Constructors
```@docs
DiseaseProgressionStrat()
Simulation(::String, ::StartCondition, ::StopCriterion, ::Population, ::SettingsContainer, ::String)
Simulation(; simargs...)
Simulation(::String, ::String, ::String, ::String, ::Function, ::Dict)
```

## Functions
```@docs
add_hospitalization_trigger!
add_strategy!
add_symptom_trigger!
add_testtype!
add_tick_trigger!
configfile(::Simulation)
create_simulation
create_waning
customlogger!(::Simulation, ::CustomLogger)
customlogger(::Simulation, ::CustomLogger)
customlogger(::Simulation)
customlogs
deaths(::Simulation)
deathlogger(::Simulation)
dequeue!(::EventQueue)
enqueue!(::EventQueue, ::Event, ::Int16)
evaluate
event_queue(::Simulation)
final_tick(::ResultData)
fire_custom_loggers!(::Simulation)
hospitalization_triggers(::Simulation)
incidence
increment!(::Simulation)
info(::Simulation)
interval
label(::Simulation)
main
main_r
model_size(::ResultData)
parameters
pathogen!(::Simulation, ::Pathogen)
pathogen
pooltests
pooltestlogger
population(::Simulation)
populationfile(::Simulation)
process_events!
process_events!(::Simulation)
quarantinelogger(::Simulation)
quarantines
remove_empty_settings!(::Simulation)
reset!(::Simulation)
region_info(::Simulation)
run!(::Simulation; ::Function, ::Bool)
schedule!
scheduled(scheduler, tick)
settingfile_sim
settingfile_test
setup
setup_r
should_fire
Simulation()
spread_infection!(::Setting, ::Simulation, ::Pathogen)
start_condition
step!
steps
stepmod
stop_criterion(::Simulation)
strategies(::Simulation)
switch_tick
symptom_triggers(::Simulation)
test_sim
test_sim_r
test_state(::String)
testlogger(::Simulation)
tests(::Simulation)
testtypes(::Simulation)
tick(::Simulation)
tick_triggers(::Simulation)
ticks
tickunit(::Simulation)
trigger
try_to_infect!
update_properties
vaccinate!
vaccination_schedule(::Simulation)
vaccination_strategy(::ResultData)
vaccine!(::Simulation, ::Vaccine)
vaccine(::Simulation)
```

# Initialization

## Structs
```@docs
InfectedFraction
```

## Functions
```@docs
ags(PatientZeros)
create_contact_sampling_method(::Dict)
create_distribution(::Real, ::String)
create_parameter_list
create_pathogens(::Dict)
create_transmission_function(::Dict)
fraction(::InfectedFraction)
infections(::Simulation)
initial_infections(::ResultData)
initialize!
limit
load_start_condition(::Dict, ::Pathogen)
load_stop_criterion(::Dict)
```