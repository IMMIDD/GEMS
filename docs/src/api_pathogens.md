# Pathogens & Immunity

## Overview Structs
```@index
Pages   = ["api_pathogens.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_pathogens.md"]
Order   = [:function]
```

## Pathogen Struct
```@docs
Pathogen
```

## Progression Categories

### Structs

```@docs
Asymptomatic
Mild
Severe
Critical
```

### Functions

```@docs

```

## Health Progression

Host-level care and mortality (hospital, ICU, ventilation, death) are decided independently of the
disease progression, by a `HealthProgression` that folds the demand of all of a host's active
infections into one timeline.

```@docs
HealthProgression
HealthProfile
DefaultHealthProgression
SevereHealthProfile
CriticalHealthProfile
calculate_health_progression
calculate_health_profile
compute_health!
CareTimeline
HealthOutcome
```

## Progression Assignment

```@docs
AgeBasedProgressionAssignment
```

## Tramission Function

```@docs
AgeDependentTransmissionRate
ConstantTransmissionRate
```



## Functions
```@docs

```