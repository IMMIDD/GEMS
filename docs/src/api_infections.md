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
AgeDependentTransmissionRate
```


## Functions
```@docs
infect!
spread_infection!(::Setting, ::Simulation, ::Pathogen)
transmission_probability
try_to_infect!
update_individual!(::Individual, ::Int16, ::Simulation)
```