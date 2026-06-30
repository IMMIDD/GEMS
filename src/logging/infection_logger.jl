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
    pathogen_id::Vector{Vector{Int8}} = [Vector{Int8}() for _ in 1:Threads.maxthreadid()]
    progression_category::Vector{Vector{Symbol}} = [Vector{Symbol}() for _ in 1:Threads.maxthreadid()]
    infectiousness_onset::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    symptom_onset::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    severeness_onset::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    critical_onset::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    critical_offset::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    severeness_offset::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]
    recovery::Vector{Vector{Int16}} = [Vector{Int16}() for _ in 1:Threads.maxthreadid()]

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
        pathogen_id::Int8,
        progression_category::Symbol,
        tick::Int16,
        infectiousness_onset::Int16,
        symptom_onset::Int16,
        severeness_onset::Int16,
        critical_onset::Int16,
        critical_offset::Int16,
        severeness_offset::Int16,
        recovery::Int16,
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
    push!(logger.pathogen_id[tid], pathogen_id)
    push!(logger.progression_category[tid], progression_category)
    push!(logger.tick[tid], tick)
    push!(logger.infectiousness_onset[tid], infectiousness_onset)
    push!(logger.symptom_onset[tid], symptom_onset)
    push!(logger.severeness_onset[tid], severeness_onset)
    push!(logger.critical_onset[tid], critical_onset)
    push!(logger.critical_offset[tid], critical_offset)
    push!(logger.severeness_offset[tid], severeness_offset)
    push!(logger.recovery[tid], recovery)
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
        pathogen_id::Int8,
        progression_category::Symbol,
        tick::Int16,
        infectiousness_onset::Int16,
        symptom_onset::Int16,
        severeness_onset::Int16,
        critical_onset::Int16,
        critical_offset::Int16,
        severeness_offset::Int16,
        recovery::Int16,
        setting_id::Int32,
        setting_type::Char,
        lat::Float32,
        lon::Float32,
        ags::Int32,
        source_infection_id::Int32
    )

    return log!(
        logger, a, b, pathogen_id, progression_category, tick,
        infectiousness_onset, symptom_onset, severeness_onset,
        critical_onset, critical_offset, severeness_offset,
        recovery, setting_id, setting_type, lat, lon, ags, source_infection_id
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
        pathogen_id = vcat(logger.pathogen_id...),
        progression_category = vcat(logger.progression_category...),
        infectiousness_onset = vcat(logger.infectiousness_onset...),
        symptom_onset = vcat(logger.symptom_onset...),
        severeness_onset = vcat(logger.severeness_onset...),
        critical_onset = vcat(logger.critical_onset...),
        critical_offset = vcat(logger.critical_offset...),
        severeness_offset = vcat(logger.severeness_offset...),
        recovery = vcat(logger.recovery...),
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
        file["pathogen_id"] = vcat(logger.pathogen_id...)
        file["progression_category"] = vcat(logger.progression_category...)
        file["infectiousness_onset"] = vcat(logger.infectiousness_onset...)
        file["symptom_onset"] = vcat(logger.symptom_onset...)
        file["severeness_onset"] = vcat(logger.severeness_onset...)
        file["critical_onset"] = vcat(logger.critical_onset...)
        file["critical_offset"] = vcat(logger.critical_offset...)
        file["severeness_offset"] = vcat(logger.severeness_offset...)
        file["recovery"] = vcat(logger.recovery...)
        file["setting_id"] = vcat(logger.setting_id...)
        file["setting_type"] = vcat(logger.setting_type...)
        file["lat"] = vcat(logger.lat...)
        file["lon"] = vcat(logger.lon...)
        file["ags"] = vcat(logger.ags...)
        file["source_infection_id"] = vcat(logger.source_infection_id...)
    end
end

Base.length(logger::InfectionLogger) = sum(length, logger.tick)
