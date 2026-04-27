# DEFINE LOGGER STRUCTURE AND FUNCTIONALITY
export Logger, TickLogger, EventLogger, InfectionLogger, VaccinationLogger, DeathLogger, TestLogger, PoolTestLogger, SeroprevalenceLogger
export QuarantineLogger, StateLogger, CustomLogger
export tick, log!, save, save_JLD2, dataframe
export get_infections_between
export duplicate

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

###
### InfectionLogger
###
"""
    InfectionLogger <: EventLogger 

A logging structure specifically for infections. An infection event is given by all
entries of the field-vectors at a given index. Data is thread-local to prevent lock contention.
"""
@with_kw mutable struct InfectionLogger <: EventLogger 
    # Atomic counter for generating unique infection IDs safely across threads
    infection_counter::Threads.Atomic{Int32} = Threads.Atomic{Int32}(0)
    # Atomic tick for the last modification
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)

    # Infection ID
    infection_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]

    # Infecting data
    id_a::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]

    # Infected data
    id_b::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    progression_category::Vector{Vector{Symbol}} = [Vector{Symbol}() for _ in 1:Threads.maxthreadid()]
    infectiousness_onset::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    symptom_onset::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    severeness_onset::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    hospital_admission::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    hospital_discharge::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    icu_admission::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    icu_discharge::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    ventilation_admission::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    ventilation_discharge::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    severeness_offset::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    recovery::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    death::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    
    # External data
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    setting_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    setting_type::Vector{Vector{Char}} = [Vector{Char}() for _ in 1:Threads.maxthreadid()]
    lat::Vector{Vector{Float32}} = [Vector{Float32}() for _ in 1:Threads.maxthreadid()]
    lon::Vector{Vector{Float32}} = [Vector{Float32}() for _ in 1:Threads.maxthreadid()]
    ags::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    source_infection_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        logger::InfectionLogger,
        a::Int32,
        b::Int32,
        progression_category::Symbol,
        tick::Int16,
        infectiousness_onset::Int16,
        symptom_onset::Int16,
        severeness_onset::Int16,
        hospital_admission::Int16,
        hospital_discharge::Int16,
        icu_admission::Int16,
        icu_discharge::Int16,
        ventilation_admission::Int16,
        ventilation_discharge::Int16,
        severeness_offset::Int16,
        recovery::Int16,
        death::Int16,
        setting_id::Int32,
        setting_type::Char,
        lat::Float32,
        lon::Float32,
        ags::Int32,
        source_infection_id::Int32
    )

    tid = Threads.threadid()
    
    # Safely generate a unique ID without a lock
    new_infection_id = Threads.atomic_add!(logger.infection_counter, Int32(1)) + Int32(1)

    # push data directly to the thread-local arrays
    push!(logger.infection_id[tid], new_infection_id)
    push!(logger.id_a[tid], a)
    push!(logger.id_b[tid], b)
    push!(logger.progression_category[tid], progression_category)
    push!(logger.tick[tid], tick)
    push!(logger.infectiousness_onset[tid], infectiousness_onset)
    push!(logger.symptom_onset[tid], symptom_onset)
    push!(logger.severeness_onset[tid], severeness_onset)
    push!(logger.hospital_admission[tid], hospital_admission)
    push!(logger.hospital_discharge[tid], hospital_discharge)
    push!(logger.icu_admission[tid], icu_admission)
    push!(logger.icu_discharge[tid], icu_discharge)
    push!(logger.ventilation_admission[tid], ventilation_admission)
    push!(logger.ventilation_discharge[tid], ventilation_discharge)
    push!(logger.severeness_offset[tid], severeness_offset)
    push!(logger.recovery[tid], recovery)
    push!(logger.death[tid], death)
    push!(logger.setting_id[tid], setting_id)
    push!(logger.setting_type[tid], setting_type)
    push!(logger.lat[tid], lat)
    push!(logger.lon[tid], lon)
    push!(logger.ags[tid], ags)
    push!(logger.source_infection_id[tid], source_infection_id)

    Threads.atomic_xchg!(logger.last_modified_tick, tick)

    return(new_infection_id)
end

function log!(;
        logger::InfectionLogger,
        a::Int32,
        b::Int32,
        progression_category::Symbol,
        tick::Int16,
        infectiousness_onset::Int16,
        symptom_onset::Int16,
        severeness_onset::Int16,
        hospital_admission::Int16,
        hospital_discharge::Int16,
        icu_admission::Int16,
        icu_discharge::Int16,
        ventilation_admission::Int16,
        ventilation_discharge::Int16,
        severeness_offset::Int16,
        recovery::Int16,
        death::Int16,
        setting_id::Int32,
        setting_type::Char,
        lat::Float32,
        lon::Float32,
        ags::Int32,
        source_infection_id::Int32
    )

    return log!(
        logger, a, b, progression_category, tick, 
        infectiousness_onset, symptom_onset, severeness_onset, 
        hospital_admission, hospital_discharge, icu_admission, icu_discharge, 
        ventilation_admission, ventilation_discharge, severeness_offset, 
        recovery, death, setting_id, setting_type, lat, lon, ags, source_infection_id
    )    
end

"""
    ticks(logger::InfectionLogger)
"""
function ticks(logger::InfectionLogger)
    return vcat(logger.tick...)
end

function get_infections_between(logger::InfectionLogger, infecter::Int32, start_tick::Int16, end_tick::Int16)
    result = Vector{Int32}()
    
    for tid in 1:Threads.maxthreadid()
        start_idx = searchsortedfirst(logger.tick[tid], start_tick)
        end_idx = searchsortedlast(logger.tick[tid], end_tick)
        
        @inbounds for i in start_idx:end_idx
            if logger.id_a[tid][i] == infecter
                push!(result, logger.id_b[tid][i])
            end
        end
    end
    
    return result
end

function save(logger::InfectionLogger, path::AbstractString)
    CSV.write(path, dataframe(logger))
end

function dataframe(logger::InfectionLogger)
    return DataFrame(
        infection_id = vcat(logger.infection_id...),
        tick = vcat(logger.tick...),
        id_a = vcat(logger.id_a...),
        id_b = vcat(logger.id_b...),
        progression_category = vcat(logger.progression_category...),
        infectiousness_onset = vcat(logger.infectiousness_onset...),
        symptom_onset = vcat(logger.symptom_onset...),
        severeness_onset = vcat(logger.severeness_onset...),
        hospital_admission = vcat(logger.hospital_admission...),
        hospital_discharge = vcat(logger.hospital_discharge...),
        icu_admission = vcat(logger.icu_admission...),
        icu_discharge = vcat(logger.icu_discharge...),
        ventilation_admission = vcat(logger.ventilation_admission...),
        ventilation_discharge = vcat(logger.ventilation_discharge...),
        severeness_offset = vcat(logger.severeness_offset...),
        recovery = vcat(logger.recovery...),
        death = vcat(logger.death...),
        setting_id = vcat(logger.setting_id...),
        setting_type = vcat(logger.setting_type...),
        lat = vcat(logger.lat...),
        lon = vcat(logger.lon...),
        ags = vcat(logger.ags...),
        source_infection_id = vcat(logger.source_infection_id...)
    )
end

function save_JLD2(logger::InfectionLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["infection_id"] = vcat(logger.infection_id...)
        file["tick"] = vcat(logger.tick...)
        file["id_a"] = vcat(logger.id_a...)
        file["id_b"] = vcat(logger.id_b...)
        file["progression_category"] = vcat(logger.progression_category...)
        file["infectiousness_onset"] = vcat(logger.infectiousness_onset...)
        file["symptom_onset"] = vcat(logger.symptom_onset...)
        file["severeness_onset"] = vcat(logger.severeness_onset...)
        file["hospital_admission"] = vcat(logger.hospital_admission...)
        file["hospital_discharge"] = vcat(logger.hospital_discharge...)
        file["icu_admission"] = vcat(logger.icu_admission...)
        file["icu_discharge"] = vcat(logger.icu_discharge...)
        file["ventilation_admission"] = vcat(logger.ventilation_admission...)
        file["ventilation_discharge"] = vcat(logger.ventilation_discharge...)
        file["severeness_offset"] = vcat(logger.severeness_offset...)
        file["recovery"] = vcat(logger.recovery...)
        file["death"] = vcat(logger.death...)
        file["setting_id"] = vcat(logger.setting_id...)
        file["setting_type"] = vcat(logger.setting_type...)
        file["lat"] = vcat(logger.lat...)
        file["lon"] = vcat(logger.lon...)
        file["ags"] = vcat(logger.ags...)
        file["source_infection_id"] = vcat(logger.source_infection_id...)
    end
end

Base.length(logger::InfectionLogger) = sum(length, logger.tick)


###
### VaccinationLogger
###
@with_kw mutable struct VaccinationLogger <: EventLogger 
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)
    id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        vacclogger::VaccinationLogger,
        id::Int32,
        tick::Int16,
    )
    tid = Threads.threadid()
    push!(vacclogger.id[tid], id)
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
    end
end

function dataframe(vacclogger::VaccinationLogger)
    return DataFrame(
        tick = vcat(vacclogger.tick...),
        id = vcat(vacclogger.id...)
    )
end

Base.length(logger::VaccinationLogger) = sum(length, logger.tick)


###
### DeathLogger
###
@with_kw mutable struct DeathLogger <: EventLogger 
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)
    id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        deathlogger::DeathLogger,
        id::Int32,
        tick::Int16,
    )
    tid = Threads.threadid()
    push!(deathlogger.id[tid], id)
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
    end
end

function dataframe(deathlogger::DeathLogger)::DataFrame
    return DataFrame(
        tick = vcat(deathlogger.tick...),
        id = vcat(deathlogger.id...)
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
    test_tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    test_result::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infected::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infection_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    test_type::Vector{Vector{String}} = [Vector{String}() for _ in 1:Threads.maxthreadid()]
    reportable::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        testlogger::TestLogger,
        id::Int32,
        test_tick::Int16,
        test_result::Bool,
        infected::Bool,
        infection_id::Int32,
        test_type::String,
        reportable::Bool
    )
    tid = Threads.threadid()
    new_test_id = Threads.atomic_add!(testlogger.test_counter, Int32(1)) + Int32(1)

    push!(testlogger.test_id[tid], new_test_id)
    push!(testlogger.id[tid], id)
    push!(testlogger.test_tick[tid], test_tick)
    push!(testlogger.test_result[tid], test_result)
    push!(testlogger.infected[tid], infected)
    push!(testlogger.infection_id[tid], infection_id)
    push!(testlogger.test_type[tid], test_type)
    push!(testlogger.reportable[tid], reportable)

    Threads.atomic_xchg!(testlogger.last_modified_tick, test_tick)
end

function save(testlogger::TestLogger, path::AbstractString)
    CSV.write(path, dataframe(testlogger))
end

function save_JLD2(testlogger::TestLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["test_id"] = vcat(testlogger.test_id...)
        file["test_tick"] = vcat(testlogger.test_tick...)
        file["id"] = vcat(testlogger.id...)
        file["test_result"] = vcat(testlogger.test_result...)
        file["infected"] = vcat(testlogger.infected...)
        file["infection_id"] = vcat(testlogger.infection_id...)
        file["test_type"] = vcat(testlogger.test_type...)
        file["reportable"] = vcat(testlogger.reportable...)
    end
end

function dataframe(testlogger::TestLogger)::DataFrame
    return DataFrame(
        test_id = vcat(testlogger.test_id...),    
        test_tick = vcat(testlogger.test_tick...),
        id = vcat(testlogger.id...),
        test_result = vcat(testlogger.test_result...),
        infected = vcat(testlogger.infected...),
        infection_id = vcat(testlogger.infection_id...),
        test_type = vcat(testlogger.test_type...),
        reportable = vcat(testlogger.reportable...)
    )
end

Base.length(logger::TestLogger) = sum(length, logger.test_tick)


###
### PoolTestLogger
###
@with_kw mutable struct PoolTestLogger <: EventLogger 
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)
    setting_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    setting_type::Vector{Vector{Char}} = [Vector{Char}() for _ in 1:Threads.maxthreadid()]
    test_tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    test_result::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    no_of_individuals::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    no_of_infected::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    test_type::Vector{Vector{String}} = [Vector{String}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        poollogger::PoolTestLogger,
        setting_id::Int32,
        setting_type::Char,
        test_tick::Int16,
        test_result::Bool,
        no_of_individuals::Int16,
        no_of_infected::Int16,
        test_type::String
    )
    tid = Threads.threadid()
    push!(poollogger.setting_id[tid], setting_id)
    push!(poollogger.setting_type[tid], setting_type)
    push!(poollogger.test_tick[tid], test_tick)
    push!(poollogger.test_result[tid], test_result)
    push!(poollogger.no_of_individuals[tid], no_of_individuals)
    push!(poollogger.no_of_infected[tid], no_of_infected)
    push!(poollogger.test_type[tid], test_type)

    Threads.atomic_xchg!(poollogger.last_modified_tick, test_tick)
end

function save(poollogger::PoolTestLogger, path::AbstractString)
    CSV.write(path, dataframe(poollogger))
end

function save_JLD2(poollogger::PoolTestLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["setting_id"] = vcat(poollogger.setting_id...)
        file["setting_type"] = vcat(poollogger.setting_type...)
        file["test_tick"] = vcat(poollogger.test_tick...)
        file["test_result"] = vcat(poollogger.test_result...)
        file["no_of_individuals"] = vcat(poollogger.no_of_individuals...)
        file["no_of_infected"] = vcat(poollogger.no_of_infected...)
        file["test_type"] = vcat(poollogger.test_type...)
    end
end

function dataframe(poollogger::PoolTestLogger)::DataFrame
    return DataFrame(
        test_tick = vcat(poollogger.test_tick...),
        setting_id = vcat(poollogger.setting_id...),
        setting_type = vcat(poollogger.setting_type...),
        test_result = vcat(poollogger.test_result...),
        no_of_individuals = vcat(poollogger.no_of_individuals...),
        no_of_infected = vcat(poollogger.no_of_infected...),
        test_type = vcat(poollogger.test_type...)
    )
end

Base.length(logger::PoolTestLogger) = sum(length, logger.test_tick)


###
### SeroprevalenceLogger
###
@with_kw mutable struct SeroprevalenceLogger <: EventLogger
    test_counter::Threads.Atomic{Int32} = Threads.Atomic{Int32}(0)
    last_modified_tick::Threads.Atomic{Int16} = Threads.Atomic{Int16}(DEFAULT_TICK)

    test_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    test_tick::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    test_result::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infected::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    was_infected::Vector{Vector{Bool}} = [Vector{Bool}() for _ in 1:Threads.maxthreadid()]
    infection_id::Vector{Vector{Int32}} = [Vector{Int32}() for _ in 1:Threads.maxthreadid()]
    test_type::Vector{Vector{String}} = [Vector{String}() for _ in 1:Threads.maxthreadid()]
end

function log!(
        logger::SeroprevalenceLogger,
        id::Int32,
        test_tick::Int16,
        test_result::Bool,
        infected::Bool,
        was_infected::Bool,
        infection_id::Int32,
        test_type::String
    )
    tid = Threads.threadid()
    new_test_id = Threads.atomic_add!(logger.test_counter, Int32(1)) + Int32(1)

    push!(logger.test_id[tid], new_test_id)
    push!(logger.id[tid], id)
    push!(logger.test_tick[tid], test_tick)
    push!(logger.test_result[tid], test_result)
    push!(logger.infected[tid], infected)
    push!(logger.was_infected[tid], was_infected)
    push!(logger.infection_id[tid], infection_id)
    push!(logger.test_type[tid], test_type)

    Threads.atomic_xchg!(logger.last_modified_tick, test_tick)
end

function save(logger::SeroprevalenceLogger, path::AbstractString)
    CSV.write(path, dataframe(logger))
end

function save_JLD2(logger::SeroprevalenceLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["test_id"] = vcat(logger.test_id...)
        file["test_tick"] = vcat(logger.test_tick...)
        file["id"] = vcat(logger.id...)
        file["test_result"] = vcat(logger.test_result...)
        file["infected"] = vcat(logger.infected...)
        file["was_infected"] = vcat(logger.was_infected...)
        file["infection_id"] = vcat(logger.infection_id...)
        file["test_type"] = vcat(logger.test_type...)
    end
end

function dataframe(logger::SeroprevalenceLogger)::DataFrame
    return DataFrame(
        test_id       = vcat(logger.test_id...),
        test_tick     = vcat(logger.test_tick...),
        id            = vcat(logger.id...),
        test_result   = vcat(logger.test_result...),
        infected      = vcat(logger.infected...),
        was_infected  = vcat(logger.was_infected...),
        infection_id  = vcat(logger.infection_id...),
        test_type     = vcat(logger.test_type...)
    )
end

Base.length(logger::SeroprevalenceLogger) = sum(length, logger.test_tick)


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
### CUSTOM LOGGERS
###
mutable struct CustomLogger <: TickLogger
    funcs::Dict{Symbol, Function}
    data::DataFrame 

    function CustomLogger(;kwargs...)
        funcs = Dict{Symbol, Function}(:tick => tick)
        for (key, val) in kwargs
            key == :tick ? throw("'tick' is a protected name and cannot be a custom column for the Logger") : nothing
            !(typeof(val) <: Function) ? throw("The arguments passed to the CustomLogger must be a one-argument (Sim-object) function.") : nothing
            first(methods(val)).nargs != 2 ? throw("The arumgment functions must have exactly one argument (the Sim-object)") : nothing
            
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
