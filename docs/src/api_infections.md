# Infections and Immunity

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
AgeDependentTransmissionRate
ConstantTransmissionRate
TransmissionFunction
```

## Constructors
```@docs
AgeDependentTransmissionRate(;transmission_rate, ageGroups, ageTransmissions, distribution)
```


## Functions
```@docs
disease_progression!(::Individual, ::Pathogen, ::Int16)
estimate_disease_progression(::DiseaseProgressionStrat, ::Individual)
infect!
transmission_probability
update_individual!(::Individual, ::Int16, ::Simulation)
```