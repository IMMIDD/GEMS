# DEFINE LOGGER STRUCTURE AND FUNCTIONALITY
export Logger, TickLogger, EventLogger, InfectionLogger, VaccinationLogger, DeathLogger, TestLogger, PoolTestLogger, SeroprevalenceLogger
export QuarantineLogger, StateLogger, CustomLogger
export tick, log!, save, save_JLD2, dataframe
export get_infections_between

"""
Supertype for all Loggers
"""
abstract type Logger end

"""
Supertype for all Loggers, which are logging per tick
"""
abstract type TickLogger <: Logger end

"""
Supertype for all Loggers, which are logging certain events
"""
abstract type EventLogger <: Logger end

include("infection_logger.jl")
include("event_loggers.jl")
include("tick_loggers.jl")
