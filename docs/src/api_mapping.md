# Mapping

## Overview Structs
```@index
Pages   = ["api_mapping.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_mapping.md"]
Order   = [:function]
```

## Structs
```@docs
AgeMap
AttackRateMap
CaseFatalityMap
Geolocated
InfectionMap
HouseholdSizeMap
MapPlot
PopDensityMap
SinglesMap
```

## Functions
```@docs
agsmap
gemsmap
generate_map
lat(::Geolocated)
lon(::Geolocated)
prepare_map_df!
region_range(::DataFrame)
```