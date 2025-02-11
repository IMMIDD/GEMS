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
CustomLogger
DeathLogger
EventLogger
InfectionLogger
Logger
PoolTestLogger
QuarantineLogger
TestLogger
TickLogger
VaccinationLogger
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
hasfuncs(::CustomLogger)
infectionlogger(::Simulation)
log!
log_quarantines(::Simulation)
logger
lognow
save(::DeathLogger, ::AbstractString)
save(::InfectionLogger, ::AbstractString)
save(::PoolTestLogger, ::AbstractString)
save(::TestLogger, ::AbstractString)
save(::VaccinationLogger, ::AbstractString)
save_JLD2
```