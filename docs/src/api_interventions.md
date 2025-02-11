# Interventions

## Overview Structs
```@index
Pages   = ["api_interventions.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_interventions.md"]
Order   = [:function]
```

## Structs
```@docs
AbstractWaning
CancelSelfIsolation
ChangeContactMethod
CloseSetting
CustomIMeasure
CustomSMeasure
DailyDoseStrategy
DiscreteWaning
EventQueue
FindMembers
FindSetting
FindSettingMembers
Handover
IMeasureEvent
IStrategy
ITickTrigger
IsOpen
MeasureEntry
OpenSetting
PoolTest
SMeasureEvent
SStrategy
STickTrigger
SelfIsolation
SymptomTrigger
Test
TestAll
TestType
TraceInfectiousContacts
VaccinationScheduler
VaccinationStrategy
Vaccine
```

## Constructors
```@docs
IStrategy(::String, ::Simulation; ::Function)
SStrategy(::String, ::Simulation; ::Function)
```

## Functions
```@docs
add_measure!
apply_pool_test
apply_test
condition
delay(::MeasureEntry)
duration
follow_up
home_quarantine!(::Individual)
measure(::MeasureEntry)
measure_logic
measures(::Strategy)
name(::PoolTest)
name(::Strategy)
name(::TestAll)
name(::TestType)
name(::Test)
negative_followup
nonself(::FindSettingMembers)
offset(::MeasureEntry)
positive_followup
process_event(::IMeasureEvent, ::Simulation)
process_event(::SMeasureEvent, ::Simulation)
process_measure
reportable(::Test)
reportable(::TestAll)
sample_fraction(::FindMembers)
sample_size(::FindMembers)
sampling_method(::ChangeContactMethod)
selectionfilter(::FindMembers)
sensitivity(::TestType)
specificity(::TestType)
strategies
strategy
success_rate(::TraceInfectiousContacts)
time_to_effectiveness(waning)
trigger_strategy(::IStrategy, ::Individual, ::Simulation)
trigger_strategy(::SStrategy, ::Setting, ::Simulation)
trigger_strategy
type
waning(::Vaccine)
```