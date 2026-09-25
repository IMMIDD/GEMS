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

# A logger column, one vector per thread, as a single vector: a copy, or with `share` the
# logger's own storage, merged into its first vector (see `_compact!`)
_logger_column(cols::AbstractVector, share::Bool) = share ? _compact!(cols) : vcat(cols...)

"""
    _compact!(vs::AbstractVector{Vector{T}})

Moves the entries of all `vs`, in `vcat` order, into `vs[1]` and returns it; the others end up
empty and give their memory back. Appending afterwards works as before.
"""
function _compact!(vs::AbstractVector{Vector{T}}) where {T}
    first = vs[1]
    sizehint!(first, sum(length, vs; init = 0))
    for k in 2:length(vs)
        append!(first, vs[k])
        empty!(vs[k])
        sizehint!(vs[k], 0)
    end
    return first
end

include("chunked_vector.jl")
include("infecter_index.jl")
include("infection_logger.jl")
include("event_loggers.jl")
include("tick_loggers.jl")
