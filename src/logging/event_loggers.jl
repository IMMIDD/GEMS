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
        pathogen_id = vcat(vacclogger.pathogen_id...);
        copycols = false
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
        pathogen_id = vcat(deathlogger.pathogen_id...);
        copycols = false
    )
end

Base.length(logger::DeathLogger) = sum(length, logger.tick)


###
### HealthLogger
###

"""
    HealthLogger <: EventLogger

Records host-level care events (hospital/ICU/ventilation admission and discharge) as they
are realized. Each event is `(id, event, tick)` where `event` is a `Symbol` such as
`:hospital_admission` or `:icu_discharge`. Host death is recorded separately by the
`DeathLogger`. Data is thread-local to prevent lock contention.
"""
@with_kw mutable struct HealthLogger <: EventLogger
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)
    id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    event::Vector{Vector{Symbol}} = [Vector{Symbol}() for _ in 1:Threads.maxthreadid()]
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        healthlogger::HealthLogger,
        id::Int32,
        event::Symbol,
        tick::Int16,
    )
    tid = Threads.threadid()
    push!(healthlogger.id[tid], id)
    push!(healthlogger.event[tid], event)
    push!(healthlogger.tick[tid], tick)
    Threads.atomic_xchg!(healthlogger.last_modified_tick, tick)
end

function save(healthlogger::HealthLogger, path::AbstractString)
    CSV.write(path, dataframe(healthlogger))
end

function save_JLD2(healthlogger::HealthLogger, path::AbstractString)
    jldopen(path, "w") do file
        file["tick"] = vcat(healthlogger.tick...)
        file["id"] = vcat(healthlogger.id...)
        file["event"] = vcat(healthlogger.event...)
    end
end

function dataframe(healthlogger::HealthLogger)::DataFrame
    return DataFrame(
        tick = vcat(healthlogger.tick...),
        id = vcat(healthlogger.id...),
        event = vcat(healthlogger.event...);
        copycols = false
    )
end

Base.length(logger::HealthLogger) = sum(length, logger.tick)


###
### TEST TYPE NAMES
###

# One logger's test type names; a row's code is its name's index in `names`. `names` never resizes
# and `count` grows only after the name is written, so reading needs no lock.
struct _TestTypeNames
    names::Vector{String}
    count::Threads.Atomic{Int}
    lock::ReentrantLock
end

_TestTypeNames() = _TestTypeNames(Vector{String}(undef, typemax(Int8)), Threads.Atomic{Int}(0), ReentrantLock())


###
### TestLogger
###
@with_kw mutable struct TestLogger <: EventLogger
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)

    id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    test_result::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infected::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infection_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    pathogen_id::Vector{Vector{Int8}} = [Vector{Int8}() for _ in 1:Threads.maxthreadid()]
    test_type::Vector{Vector{Int8}} = [Vector{Int8}() for _ in 1:Threads.maxthreadid()]
    test_type_names::_TestTypeNames = _TestTypeNames()
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
    code = _test_type_code!(testlogger.test_type_names, test_type)
    tid = Threads.threadid()

    push!(testlogger.id[tid], id)
    push!(testlogger.tick[tid], tick)
    push!(testlogger.test_result[tid], test_result)
    push!(testlogger.infected[tid], infected)
    push!(testlogger.infection_id[tid], infection_id)
    push!(testlogger.pathogen_id[tid], pathogen_id)
    push!(testlogger.test_type[tid], code)
    push!(testlogger.reportable[tid], reportable)

    # written only on change
    testlogger.last_modified_tick[] == tick || Threads.atomic_xchg!(testlogger.last_modified_tick, tick)
end

function save(testlogger::TestLogger, path::AbstractString)
    CSV.write(path, dataframe(testlogger))
end

function save_JLD2(testlogger::TestLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["test_id"] = collect(1:length(testlogger))
        file["tick"] = vcat(testlogger.tick...)
        file["id"] = vcat(testlogger.id...)
        file["test_result"] = vcat(testlogger.test_result...)
        file["infected"] = vcat(testlogger.infected...)
        file["infection_id"] = vcat(testlogger.infection_id...)
        file["pathogen_id"] = vcat(testlogger.pathogen_id...)
        file["test_type"] = _decode_test_types(testlogger.test_type_names, vcat(testlogger.test_type...))
        file["reportable"] = vcat(testlogger.reportable...)
    end
end

function dataframe(testlogger::TestLogger)::DataFrame
    return DataFrame(
        test_id = collect(1:length(testlogger)),
        tick = vcat(testlogger.tick...),
        id = vcat(testlogger.id...),
        test_result = vcat(testlogger.test_result...),
        infected = vcat(testlogger.infected...),
        infection_id = vcat(testlogger.infection_id...),
        pathogen_id = vcat(testlogger.pathogen_id...),
        test_type = _decode_test_types(testlogger.test_type_names, vcat(testlogger.test_type...)),
        reportable = vcat(testlogger.reportable...);
        copycols = false
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
        file["setting_type_names"] = setting_type_names()
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
        test_type = vcat(poollogger.test_type...);
        copycols = false
    )
end

Base.length(logger::PoolTestLogger) = sum(length, logger.tick)


###
### SeroprevalenceLogger
###
@with_kw mutable struct SeroprevalenceLogger <: EventLogger
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)

    id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    test_result::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infected::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    was_infected::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infection_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    pathogen_id::Vector{Vector{Int8}} = [Vector{Int8}() for _ in 1:Threads.maxthreadid()]
    test_type::Vector{Vector{Int8}} = [Vector{Int8}() for _ in 1:Threads.maxthreadid()]
    test_type_names::_TestTypeNames = _TestTypeNames()
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
    code = _test_type_code!(logger.test_type_names, test_type)
    tid = Threads.threadid()

    push!(logger.id[tid], id)
    push!(logger.tick[tid], tick)
    push!(logger.test_result[tid], test_result)
    push!(logger.infected[tid], infected)
    push!(logger.was_infected[tid], was_infected)
    push!(logger.infection_id[tid], infection_id)
    push!(logger.pathogen_id[tid], pathogen_id)
    push!(logger.test_type[tid], code)

    # written only on change
    logger.last_modified_tick[] == tick || Threads.atomic_xchg!(logger.last_modified_tick, tick)
end

function save(logger::SeroprevalenceLogger, path::AbstractString)
    CSV.write(path, dataframe(logger))
end

function save_JLD2(logger::SeroprevalenceLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["test_id"] = collect(1:length(logger))
        file["tick"] = vcat(logger.tick...)
        file["id"] = vcat(logger.id...)
        file["test_result"] = vcat(logger.test_result...)
        file["infected"] = vcat(logger.infected...)
        file["was_infected"] = vcat(logger.was_infected...)
        file["infection_id"] = vcat(logger.infection_id...)
        file["pathogen_id"] = vcat(logger.pathogen_id...)
        file["test_type"] = _decode_test_types(logger.test_type_names, vcat(logger.test_type...))
    end
end

function dataframe(logger::SeroprevalenceLogger)::DataFrame
    return DataFrame(
        test_id = collect(1:length(logger)),
        tick = vcat(logger.tick...),
        id = vcat(logger.id...),
        test_result = vcat(logger.test_result...),
        infected = vcat(logger.infected...),
        was_infected = vcat(logger.was_infected...),
        infection_id = vcat(logger.infection_id...),
        pathogen_id = vcat(logger.pathogen_id...),
        test_type = _decode_test_types(logger.test_type_names, vcat(logger.test_type...));
        copycols = false
    )
end

Base.length(logger::SeroprevalenceLogger) = sum(length, logger.tick)


###
### TEST LOG HELPERS
###

"""
    _test_type_code!(table::_TestTypeNames, name::String)

Returns the code of a test type name, adding the name to the table if it is new.
"""
function _test_type_code!(table::_TestTypeNames, name::String)
    names = table.names
    @inbounds for i in 1:table.count[]
        names[i] == name && return Int8(i)
    end
    return lock(table.lock) do
        n = table.count[]
        # another thread may have added it since the scan above
        for i in 1:n
            names[i] == name && return Int8(i)
        end
        n < length(names) || throw(ArgumentError("A test logger can hold at most $(length(names)) test type names."))
        names[n + 1] = name
        table.count[] = n + 1
        return Int8(n + 1)
    end
end

"""
    _decode_test_types(table::_TestTypeNames, codes::Vector{Int8})

Returns the test type name of each code.
"""
_decode_test_types(table::_TestTypeNames, codes::Vector{Int8}) = String[table.names[c] for c in codes]
