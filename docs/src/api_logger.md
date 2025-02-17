# Logger

## Overview Structs
```@index
Pages   = ["api_logger.md"]
Order   = [:type]
```
## Overview Functions
```@index
Pages   = ["api_logger.md"]
Order   = [:function]
```

## Structs
```@docs
Logger
CustomLogger
DeathLogger
EventLogger
InfectionLogger
PoolTestLogger
QuarantineLogger
TestLogger
TickLogger
```

## Functions
```@docs
dataframe(::CustomLogger)
dataframe(::DeathLogger)
dataframe(::InfectionLogger)
dataframe(::PoolTestLogger)
dataframe(::QuarantineLogger)
dataframe(::TestLogger)
dataframe(::VaccinationLogger)
duplicate(::CustomLogger)
get_infections_between(::InfectionLogger, ::Int32, ::Int16, ::Int16)
infectionlogger(::Simulation)
length
log!
lognow
save(::DeathLogger, ::AbstractString)
save(::InfectionLogger, ::AbstractString)
save(::PoolTestLogger, ::AbstractString)
save(::TestLogger, ::AbstractString)
save_JLD2
ticks(::InfectionLogger)
```