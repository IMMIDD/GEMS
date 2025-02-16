# Settings

## Overview Structs
```@index
Pages   = ["api_settings.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_settings.md"]
Order   = [:function]
```

## Structs
```@docs
ContainerSetting
Department
GlobalSetting
Household
IndividualSetting
Municipality
Office
School
SchoolClass
SchoolComplex
SchoolYear
Setting
SettingsContainer
Workplace
WorkplaceSite
```

## Functions
```@docs
activate!
add!(::SettingsContainer, ::Setting)
add_type!
add_types!
ags(::ContainerSetting, ::Simulation)
ags(::IndividualSetting, ::Simulation)
ags(::IndividualSetting)
avg_individuals
close!
contact_sampling_method!
contact_sampling_method
contained(::Setting)
contained_type(::Setting)
contains_type(::ContainerSetting)
deactivate!(::Setting)
delete_dangling_ids!(::SettingsContainer)
geolocation
get_contained!
get_containers!
get_open_contained!
household(::Individual, ::Simulation)
id(::Setting)
individuals!
individuals(::IndividualSetting)
individuals(::IndividualSetting, simulation::Simulation)
individuals(::ContainerSetting, ::Vector{Individual}, ::Simulation)
isopen(::Setting)
isactive(::Setting)
lat(::Geolocated)
load_setting_attributes!(::SettingsContainer, ::Dict)
lon(::Geolocated)
max_individuals(::Vector{Setting}, ::Simulation)
min_individuals(::Vector{Setting}, ::Simulation)
min_max_avg_individuals(::Vector{Setting}, ::Simulation)
new_setting_ids!(::SettingsContainer, ::Dict)
open!
present_individuals
schoolclass(::Individual, ::Simulation)
sample_individuals
setting(::SettingsContainer, ::DataType, ::Int32)
setting_sizes
settingchar(::Setting)
settings
settings_from_jld2!(::String, ::SettingsContainer, ::Dict)
settings_from_population(::Population, ::Bool)
settingstring(::Char)
settingtype
settingtypes
```