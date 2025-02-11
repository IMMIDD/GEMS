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
get_infections_between(::InfectionLogger, ::Int32, ::Int16, ::Int16)
id(::Vaccine)
infectionsDF(::PostProcessor)
name(::Vaccine)
transmission_probability
```