# Population

## Overview Structs
```@index
Pages   = ["api_population.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_population.md"]
Order   = [:function]
```

## Constructors
```@docs
Population
Population(::Vector{Individual})
Population(::DataFrame)
Population(::String)
Population(;::Int64, ::Int6, ::Int64, ::Int64, ::Bool)
```

## Functions
```@docs
add!(::Population, ::Individual)
count(::Any, ::Population)
dataframe(::Population)
each!
first(::Population)
get_individual_by_id(::Population, ::Int32)
individuals(::Population)
issubset(::Vector{Individual}, ::Vector{Individual})
maxage(::Population)
num_of_infected(::Population)
params(::Population)
populationfile(::Population)
remove!(::Population, ::Individual)
save(::Population, ::AbstractString)
size(::Population)
```