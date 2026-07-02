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
exposure(::DiseaseProgression)
infect!
infectiousness_onset(::DiseaseProgression)
is_asymptomatic(::DiseaseProgression, ::Int16)
is_critical(::DiseaseProgression, ::Int16)
is_infected(::DiseaseProgression, ::Int16)
is_infectious(::DiseaseProgression, ::Int16)
is_mild(::DiseaseProgression, ::Int16)
is_presymptomatic(::DiseaseProgression, ::Int16)
is_recovered(::DiseaseProgression, ::Int16)
is_severe(::DiseaseProgression, ::Int16)
is_symptomatic(::DiseaseProgression, ::Int16)
critical_onset(::DiseaseProgression)
critical_offset(::DiseaseProgression)
recovery(::DiseaseProgression)
severeness_onset(::DiseaseProgression)
severeness_offset(::DiseaseProgression)
spread_infection!(::Setting, ::Simulation, ::Pathogen)
symptom_onset(::DiseaseProgression)
try_to_infect!
update_individual!(::Individual, ::Int16, ::Simulation)
```