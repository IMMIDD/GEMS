# Infections and Progressions

## Overview Structs
```@index
Pages   = ["api_infections.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_infections.md"]
Order   = [:function]
```


## Structs
```@docs
DiseaseProgression
```



## Functions
```@docs
can_infect
death(::DiseaseProgression)
exposure(::DiseaseProgression)
hospital_admission(::DiseaseProgression)
hospital_discharge(::DiseaseProgression)
icu_admission(::DiseaseProgression)
icu_discharge(::DiseaseProgression)
infect!
infectiousness_onset(::DiseaseProgression)
is_asymptomatic(::DiseaseProgression, ::Int16)
is_dead(::DiseaseProgression, ::Int16)
is_hospitalized(::DiseaseProgression, ::Int16)
is_icu(::DiseaseProgression, ::Int16)
is_infected(::DiseaseProgression, ::Int16)
is_infectious(::DiseaseProgression, ::Int16)
is_mild(::DiseaseProgression, ::Int16)
is_presymptomatic(::DiseaseProgression, ::Int16)
is_recovered(::DiseaseProgression, ::Int16)
is_severe(::DiseaseProgression, ::Int16)
is_symptomatic(::DiseaseProgression, ::Int16)
is_ventilated(::DiseaseProgression, ::Int16)
recovery(::DiseaseProgression)
severeness_onset(::DiseaseProgression)
severeness_offset(::DiseaseProgression)
spread_infection!(::Setting, ::Simulation, ::Pathogen)
symptom_onset(::DiseaseProgression)
try_to_infect!
update_individual!(::Individual, ::Int16, ::Simulation)
ventilation_admission(::DiseaseProgression)
ventilation_discharge(::DiseaseProgression)
```