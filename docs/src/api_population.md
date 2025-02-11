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

## Structs
```@docs
Population
```

## Functions
```@docs
add!(::Population, ::Individual)
dataframe(::Population)
each!
get_individual_by_id(::Population, ::Int32)
group_by_age(::DataFrame)
is_pop_file
maxage(::Population)
num_of_infected(::Population)
obtain_remote_files(::String; ::Bool)
obtain_remote_files(::String)
params(::Population)
populationDF(::PostProcessor)
populationDF(::Simulation)
population_size(::ResultData)
populationfile(::BatchPopulationPyramid)
populationfile(::BatchSettingAgeContacts)
populationfile(::Population)
remove!(::Population, ::Individual)
save(::Population, ::AbstractString)
```