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
Ward
ICU
Fatal
```

### Functions

```@docs
GEMS.severity_tier
```

## Health Progression

```@docs
HealthProgression
HealthProfile
DefaultHealthProgression
HealthProfileIndex
MildHealthProfile
SevereHealthProfile
CriticalHealthProfile
WardHealthProfile
ICUHealthProfile
FatalHealthProfile
calculate_health_progression!
calculate_health_profile
compute_health!
CareLevel
CareContribution
HealthOutcome
combine_outcome
```

## Progression Assignment

```@docs
AgeBasedProgressionAssignment
```

## Tramission Function

```@docs
AgeDependentTransmissionRate
ConstantTransmissionRate
max_transmission_probability
max_transmission_probability_in_type
max_transmission_factor
max_transmission_factor_in_type
```

## Immunity

### Profiles

```@docs
FullImmunity
NoImmunity
ExponentialWaning
SigmoidalWaning
WaningImmunity
```

### Vaccines

```@docs
Vaccine
VaccineProtection
peak(::Vaccine)
severity_peak(::Vaccine)
buildup_duration(::Vaccine)
```

### Functions

```@docs
calculate_immunity
calculate_severity_immunity
susceptibility_factor
susceptibility_bound
calculate_waning_immunity
calculate_waning_severity_immunity
waning_level
severity_waning_level
natural_peak
severity_natural_peak
previous_dose_interval
```



## Functions
```@docs
next_infectiousness_change
next_tick_after
```