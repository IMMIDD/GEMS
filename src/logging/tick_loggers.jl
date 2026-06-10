###
### QuarantineLogger
###
@with_kw mutable struct QuarantineLogger <: TickLogger
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)
    tick::Vector{Int16} = Vector{Int16}()
    quarantined::Vector{Int64} = Vector{Int64}()
    students::Vector{Int64} = Vector{Int64}()
    workers::Vector{Int64} = Vector{Int64}()
end

function log!(
    quarantinelogger::QuarantineLogger,
    tick::Int16,
    quarantined::Int64,
    students::Int64,
    workers::Int64
)
    push!(quarantinelogger.tick, tick)
    push!(quarantinelogger.quarantined, quarantined)
    push!(quarantinelogger.students, students)
    push!(quarantinelogger.workers, workers)

    Threads.atomic_xchg!(quarantinelogger.last_modified_tick, tick)
end

function dataframe(quarantinelogger::QuarantineLogger)::DataFrame
    return DataFrame(
        tick = quarantinelogger.tick,
        quarantined = quarantinelogger.quarantined,
        students = quarantinelogger.students,
        workers = quarantinelogger.workers
    )
end

Base.length(logger::QuarantineLogger) = length(logger.tick)


###
### StateLogger
###
@with_kw mutable struct StateLogger <: TickLogger
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)
    tick::Vector{Int16} = Vector{Int16}()
    exposed::Vector{Int64} = Vector{Int64}()
    infectious::Vector{Int64} = Vector{Int64}()
    dead::Vector{Int64} = Vector{Int64}()
    detected::Vector{Int64} = Vector{Int64}()
    quarantined::Vector{Int64} = Vector{Int64}()
    quarantined_students::Vector{Int64} = Vector{Int64}()
    isolated_students::Vector{Int64} = Vector{Int64}()
    unable_to_attend_students::Vector{Int64} = Vector{Int64}()
    quarantined_workers::Vector{Int64} = Vector{Int64}()
    isolated_workers::Vector{Int64} = Vector{Int64}()
    unable_to_attend_workers::Vector{Int64} = Vector{Int64}()
end

function log!(
    statelogger::StateLogger;
    tick::Int16,
    exposed::Int64,
    infectious::Int64,
    dead::Int64,
    detected::Int64,
    quarantined::Int64,
    quarantined_students::Int64,
    isolated_students::Int64,
    unable_to_attend_students::Int64,
    quarantined_workers::Int64,
    isolated_workers::Int64,
    unable_to_attend_workers::Int64
)
    push!(statelogger.tick, tick)
    push!(statelogger.exposed, exposed)
    push!(statelogger.infectious, infectious)
    push!(statelogger.dead, dead)
    push!(statelogger.detected, detected)
    push!(statelogger.quarantined, quarantined)
    push!(statelogger.quarantined_students, quarantined_students)
    push!(statelogger.isolated_students, isolated_students)
    push!(statelogger.unable_to_attend_students, unable_to_attend_students)
    push!(statelogger.quarantined_workers, quarantined_workers)
    push!(statelogger.isolated_workers, isolated_workers)
    push!(statelogger.unable_to_attend_workers, unable_to_attend_workers)

    Threads.atomic_xchg!(statelogger.last_modified_tick, tick)
end

function dataframe(statelogger::StateLogger)::DataFrame
    return DataFrame(
        tick = statelogger.tick,
        exposed = statelogger.exposed,
        infectious = statelogger.infectious,
        dead = statelogger.dead,
        detected = statelogger.detected,
        quarantined = statelogger.quarantined,
        quarantined_students = statelogger.quarantined_students,
        isolated_students = statelogger.isolated_students,
        unable_to_attend_students = statelogger.unable_to_attend_students,
        quarantined_workers = statelogger.quarantined_workers,
        isolated_workers = statelogger.isolated_workers,
        unable_to_attend_workers = statelogger.unable_to_attend_workers
    )
end

Base.length(logger::StateLogger) = length(logger.tick)


###
### CustomLogger
###
mutable struct CustomLogger <: TickLogger
    funcs::Dict{Symbol, Function}
    data::DataFrame

    function CustomLogger(;kwargs...)
        funcs = Dict{Symbol, Function}(:tick => tick)
        for (key, val) in kwargs
            key == :tick ? throw(ArgumentError("'tick' is a protected name and cannot be a custom column for the Logger")) : nothing
            !(typeof(val) <: Function) ? throw(ArgumentError("The arguments passed to the CustomLogger must be a one-argument (Sim-object) function.")) : nothing
            first(methods(val)).nargs != 2 ? throw(ArgumentError("The arumgment functions must have exactly one argument (the Sim-object)")) : nothing

            funcs[key] = val
        end
        data = DataFrame([(Symbol(k) => Any[]) for (k, v) in funcs])
        return(new(funcs, data))
    end
end

hasfuncs(cl::CustomLogger) = !(length(cl.funcs) == 1 && first(values(cl.funcs)) == tick)
dataframe(cl::CustomLogger) = cl.data
duplicate(cl::CustomLogger) = invoke(CustomLogger, Tuple{}; (cl.funcs |> Base.copy |> f -> delete!(f, :tick) |> NamedTuple)...)
Base.length(logger::CustomLogger) = nrow(logger.data)
