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
TraceSourceContacts
```

### Functions

```@docs
apply_pool_test
apply_test
contact_filter(::TraceInfectiousContacts)
contact_filter(::TraceSourceContacts)
duration(::SelfIsolation)
follow_up
i_measuretypes
lookback(::TraceSourceContacts)
max_contacts(::TraceInfectiousContacts)
max_contacts(::TraceSourceContacts)
measure_logic
name(::PoolTest)
name(::TestAll)
name(::TestType)
name(::Test)
name(::SeroprevalenceTestType)
negative_followup
nonself(::FindSettingMembers)
positive_followup
process_measure
reportable(::Test)
reportable(::TestAll)
resample_contacts(::TraceInfectiousContacts)
resample_contacts(::TraceSourceContacts)
s_measuretypes
sample_fraction(::FindMembers)
sample_size(::FindMembers)
sampling_method(::ChangeContactMethod)
selectionfilter(::FindMembers)
sensitivity(::TestType)
settingtypes(::TraceInfectiousContacts)
settingtypes(::TraceSourceContacts)
specificity(::TestType)
success_rate(::TraceInfectiousContacts)
success_rate(::TraceSourceContacts)
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
focal_objects(::Handover)
```