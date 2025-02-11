# Pathogens

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

## Structs
```@docs
Pathogen
```

## Functions
```@docs
critical_death_rate(::Pathogen)
disease_progression_strat(::Pathogen)
hospitalization_rate(::Pathogen)
icu_rate(::Pathogen)
id(::Pathogen)
infection_rate(::Pathogen)
infectious_offset(::Pathogen)
length_of_stay(::Pathogen)
mild_death_rate(::Pathogen)
name(::Pathogen)
onset_of_severeness(::Pathogen)
onset_of_symptoms(::Pathogen)
severe_death_rate(::Pathogen)
time_to_hospitalization(::Pathogen)
time_to_icu(::Pathogen)
transmission_function!(::Pathogen, ::TransmissionFunction)
transmission_function(::Pathogen)
validate_pathogens
ventilation_rate(::Pathogen)
```