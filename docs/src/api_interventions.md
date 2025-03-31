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

## Triggers

### Structs

```@docs
HospitalizationTrigger
ITickTrigger
STickTrigger
SymptomTrigger
```

### Functions

```@docs
strategy
switch_tick
```


## Strategies

### Constructors

```@docs
IStrategy(::String, ::Simulation; ::Function)
SStrategy(::String, ::Simulation; ::Function)
MeasureEntry
```


### Functions

```@docs
add_measure!
condition
delay(::MeasureEntry)
measure(::MeasureEntry)
measures(::Strategy)
name(::Strategy)
offset(::MeasureEntry)
```


## Measures

### Constructors

```@docs
CancelSelfIsolation
ChangeContactMethod
CloseSetting
CustomIMeasure
CustomSMeasure
FindMembers
FindSetting
FindSettingMembers
IsOpen
OpenSetting
PoolTest
SelfIsolation
Test
TestAll
TestType
TraceInfectiousContacts
```

### Functions

```@docs
apply_pool_test
apply_test
duration(::SelfIsolation)
follow_up
i_measuretypes
measure_logic
name(::PoolTest)
name(::TestAll)
name(::TestType)
name(::Test)
negative_followup
nonself(::FindSettingMembers)
positive_followup
process_measure
reportable(::Test)
reportable(::TestAll)
s_measuretypes
sample_fraction(::FindMembers)
sample_size(::FindMembers)
sampling_method(::ChangeContactMethod)
selectionfilter(::FindMembers)
sensitivity(::TestType)
specificity(::TestType)
success_rate(::TraceInfectiousContacts)
type
```


## Event Handling

### Constructors

```@docs
EventQueue
Handover
IMeasureEvent
SMeasureEvent
```

### Functions

```@docs
dequeue!(::EventQueue)
enqueue!(::EventQueue, ::Event, ::Int16)
```