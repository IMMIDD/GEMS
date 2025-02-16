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
DiseaseProgressionStrat
```

## Functions
```@docs
critical_death_rate(::Pathogen)
DiseaseProgressionStrat()
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
sample_critical_death_rate(::Pathogen, ::Individual)
sample_hospitalization_rate(::Pathogen, ::Individual)
sample_icu_rate(::Pathogen, ::Individual)
sample_infectious_offset(::Pathogen, ::Individual)
sample_length_of_stay(::Pathogen, ::Individual)
sample_mild_death_rate(::Pathogen, ::Individual)
sample_onset_of_severeness(::Pathogen, ::Individual)
sample_onset_of_symptoms(::Pathogen, ::Individual)
sample_self_quarantine_rate(::Pathogen, ::Individual)
sample_severe_death_rate(::Pathogen, ::Individual)
sample_time_to_hospitalization(::Pathogen, ::Individual)
sample_time_to_icu(::Pathogen, ::Individual)
sample_time_to_recovery(::Pathogen, ::Individual)
sample_ventilation_rate(::Pathogen, ::Individual)
severe_death_rate(::Pathogen)
time_to_hospitalization(::Pathogen)
time_to_icu(::Pathogen)
transmission_function!(::Pathogen, ::TransmissionFunction)
transmission_function(::Pathogen)
ventilation_rate(::Pathogen)
```