###
### VaccinationLogger
###
@with_kw mutable struct VaccinationLogger <: EventLogger
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)
    id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    pathogen_id::Vector{Vector{Int8}} = [Vector{Int8}() for _ in 1:Threads.maxthreadid()]
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        vacclogger::VaccinationLogger,
        id::Int32,
        pathogen_id::Int8,
        tick::Int16,
    )
    tid = Threads.threadid()
    push!(vacclogger.id[tid], id)
    push!(vacclogger.pathogen_id[tid], pathogen_id)
    push!(vacclogger.tick[tid], tick)
    Threads.atomic_xchg!(vacclogger.last_modified_tick, tick)
end

function save(vacclogger::VaccinationLogger, path::AbstractString)
    CSV.write(path, dataframe(vacclogger))
end

function save_JLD2(vacclogger::VaccinationLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["tick"] = vcat(vacclogger.tick...)
        file["id"] = vcat(vacclogger.id...)
        file["pathogen_id"] = vcat(vacclogger.pathogen_id...)
    end
end

function dataframe(vacclogger::VaccinationLogger)
    return DataFrame(
        tick = vcat(vacclogger.tick...),
        id = vcat(vacclogger.id...),
        pathogen_id = vcat(vacclogger.pathogen_id...)
    )
end

Base.length(logger::VaccinationLogger) = sum(length, logger.tick)


###
### DeathLogger
###
@with_kw mutable struct DeathLogger <: EventLogger
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)
    id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    pathogen_id::Vector{Vector{Int8}} = [Vector{Int8}() for _ in 1:Threads.maxthreadid()]
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        deathlogger::DeathLogger,
        id::Int32,
        pathogen_id::Int8,
        tick::Int16,
    )
    tid = Threads.threadid()
    push!(deathlogger.id[tid], id)
    push!(deathlogger.pathogen_id[tid], pathogen_id)
    push!(deathlogger.tick[tid], tick)
    Threads.atomic_xchg!(deathlogger.last_modified_tick, tick)
end

function save(deathlogger::DeathLogger, path::AbstractString)
    CSV.write(path, dataframe(deathlogger))
end

function save_JLD2(deathlogger::DeathLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["tick"] = vcat(deathlogger.tick...)
        file["id"] = vcat(deathlogger.id...)
        file["pathogen_id"] = vcat(deathlogger.pathogen_id...)
    end
end

function dataframe(deathlogger::DeathLogger)::DataFrame
    return DataFrame(
        tick = vcat(deathlogger.tick...),
        id = vcat(deathlogger.id...),
        pathogen_id = vcat(deathlogger.pathogen_id...)
    )
end

Base.length(logger::DeathLogger) = sum(length, logger.tick)


###
### TestLogger
###
@with_kw mutable struct TestLogger <: EventLogger
    test_counter::Threads.Atomic{Int32} = Threads.Atomic{Int32}(0)
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)

    test_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    test_result::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infected::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infection_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    pathogen_id::Vector{Vector{Int8}} = [Vector{Int8}() for _ in 1:Threads.maxthreadid()]
    test_type::Vector{Vector{String}} = [Vector{String}() for _ in 1:Threads.maxthreadid()]
    reportable::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        testlogger::TestLogger,
        id::Int32,
        tick::Int16,
        test_result::Bool,
        infected::Bool,
        infection_id::Int32,
        pathogen_id::Int8,
        test_type::String,
        reportable::Bool
    )
    tid = Threads.threadid()
    new_test_id = Threads.atomic_add!(testlogger.test_counter, Int32(1)) + Int32(1)

    push!(testlogger.test_id[tid], new_test_id)
    push!(testlogger.id[tid], id)
    push!(testlogger.tick[tid], tick)
    push!(testlogger.test_result[tid], test_result)
    push!(testlogger.infected[tid], infected)
    push!(testlogger.infection_id[tid], infection_id)
    push!(testlogger.pathogen_id[tid], pathogen_id)
    push!(testlogger.test_type[tid], test_type)
    push!(testlogger.reportable[tid], reportable)

    Threads.atomic_xchg!(testlogger.last_modified_tick, tick)
end

function save(testlogger::TestLogger, path::AbstractString)
    CSV.write(path, dataframe(testlogger))
end

function save_JLD2(testlogger::TestLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["test_id"] = vcat(testlogger.test_id...)
        file["tick"] = vcat(testlogger.tick...)
        file["id"] = vcat(testlogger.id...)
        file["test_result"] = vcat(testlogger.test_result...)
        file["infected"] = vcat(testlogger.infected...)
        file["infection_id"] = vcat(testlogger.infection_id...)
        file["pathogen_id"] = vcat(testlogger.pathogen_id...)
        file["test_type"] = vcat(testlogger.test_type...)
        file["reportable"] = vcat(testlogger.reportable...)
    end
end

function dataframe(testlogger::TestLogger)::DataFrame
    return DataFrame(
        test_id = vcat(testlogger.test_id...),
        tick = vcat(testlogger.tick...),
        id = vcat(testlogger.id...),
        test_result = vcat(testlogger.test_result...),
        infected = vcat(testlogger.infected...),
        infection_id = vcat(testlogger.infection_id...),
        pathogen_id = vcat(testlogger.pathogen_id...),
        test_type = vcat(testlogger.test_type...),
        reportable = vcat(testlogger.reportable...)
    )
end

Base.length(logger::TestLogger) = sum(length, logger.tick)


###
### PoolTestLogger
###
@with_kw mutable struct PoolTestLogger <: EventLogger
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)
    setting_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    setting_type::Vector{Vector{Char}} = [Vector{Char}() for _ in 1:Threads.maxthreadid()]
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    test_result::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    no_of_individuals::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    no_of_infected::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    pathogen_id::Vector{Vector{Int8}} = [Vector{Int8}() for _ in 1:Threads.maxthreadid()]
    test_type::Vector{Vector{String}} = [Vector{String}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        poollogger::PoolTestLogger,
        setting_id::Int32,
        setting_type::Char,
        tick::Int16,
        test_result::Bool,
        no_of_individuals::Int16,
        no_of_infected::Int16,
        pathogen_id::Int8,
        test_type::String
    )
    tid = Threads.threadid()
    push!(poollogger.setting_id[tid], setting_id)
    push!(poollogger.setting_type[tid], setting_type)
    push!(poollogger.tick[tid], tick)
    push!(poollogger.test_result[tid], test_result)
    push!(poollogger.no_of_individuals[tid], no_of_individuals)
    push!(poollogger.no_of_infected[tid], no_of_infected)
    push!(poollogger.pathogen_id[tid], pathogen_id)
    push!(poollogger.test_type[tid], test_type)

    Threads.atomic_xchg!(poollogger.last_modified_tick, tick)
end

function save(poollogger::PoolTestLogger, path::AbstractString)
    CSV.write(path, dataframe(poollogger))
end

function save_JLD2(poollogger::PoolTestLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["setting_id"] = vcat(poollogger.setting_id...)
        file["setting_type"] = vcat(poollogger.setting_type...)
        file["tick"] = vcat(poollogger.tick...)
        file["test_result"] = vcat(poollogger.test_result...)
        file["no_of_individuals"] = vcat(poollogger.no_of_individuals...)
        file["no_of_infected"] = vcat(poollogger.no_of_infected...)
        file["pathogen_id"] = vcat(poollogger.pathogen_id...)
        file["test_type"] = vcat(poollogger.test_type...)
    end
end

function dataframe(poollogger::PoolTestLogger)::DataFrame
    return DataFrame(
        tick = vcat(poollogger.tick...),
        setting_id = vcat(poollogger.setting_id...),
        setting_type = vcat(poollogger.setting_type...),
        test_result = vcat(poollogger.test_result...),
        no_of_individuals = vcat(poollogger.no_of_individuals...),
        no_of_infected = vcat(poollogger.no_of_infected...),
        pathogen_id = vcat(poollogger.pathogen_id...),
        test_type = vcat(poollogger.test_type...)
    )
end

Base.length(logger::PoolTestLogger) = sum(length, logger.tick)


###
### SeroprevalenceLogger
###
@with_kw mutable struct SeroprevalenceLogger <: EventLogger
    test_counter::Threads.Atomic{Int32} = Threads.Atomic{Int32}(0)
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)

    test_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    test_result::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infected::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    was_infected::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infection_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    pathogen_id::Vector{Vector{Int8}} = [Vector{Int8}() for _ in 1:Threads.maxthreadid()]
    test_type::Vector{Vector{String}} = [Vector{String}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        logger::SeroprevalenceLogger,
        id::Int32,
        tick::Int16,
        test_result::Bool,
        infected::Bool,
        was_infected::Bool,
        infection_id::Int32,
        pathogen_id::Int8,
        test_type::String
    )
    tid = Threads.threadid()
    new_test_id = Threads.atomic_add!(logger.test_counter, Int32(1)) + Int32(1)

    push!(logger.test_id[tid], new_test_id)
    push!(logger.id[tid], id)
    push!(logger.tick[tid], tick)
    push!(logger.test_result[tid], test_result)
    push!(logger.infected[tid], infected)
    push!(logger.was_infected[tid], was_infected)
    push!(logger.infection_id[tid], infection_id)
    push!(logger.pathogen_id[tid], pathogen_id)
    push!(logger.test_type[tid], test_type)

    Threads.atomic_xchg!(logger.last_modified_tick, tick)
end

function save(logger::SeroprevalenceLogger, path::AbstractString)
    CSV.write(path, dataframe(logger))
end

function save_JLD2(logger::SeroprevalenceLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["test_id"] = vcat(logger.test_id...)
        file["tick"] = vcat(logger.tick...)
        file["id"] = vcat(logger.id...)
        file["test_result"] = vcat(logger.test_result...)
        file["infected"] = vcat(logger.infected...)
        file["was_infected"] = vcat(logger.was_infected...)
        file["infection_id"] = vcat(logger.infection_id...)
        file["pathogen_id"] = vcat(logger.pathogen_id...)
        file["test_type"] = vcat(logger.test_type...)
    end
end

function dataframe(logger::SeroprevalenceLogger)::DataFrame
    return DataFrame(
        test_id = vcat(logger.test_id...),
        tick = vcat(logger.tick...),
        id = vcat(logger.id...),
        test_result = vcat(logger.test_result...),
        infected = vcat(logger.infected...),
        was_infected = vcat(logger.was_infected...),
        infection_id = vcat(logger.infection_id...),
        pathogen_id = vcat(logger.pathogen_id...),
        test_type = vcat(logger.test_type...)
    )
end

Base.length(logger::SeroprevalenceLogger) = sum(length, logger.tick)
