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

    # Individual id range of the logged population
    minid::Int32 = Int32(1)
    maxid::Int32 = Int32(0)

    # Inverted infecter -> infectee index, built lazily on the first get_infections_between
    # call. Stays `nothing` in runs that never trace infectious contacts.
    infecter_index::Union{Nothing, InfecterIndex} = nothing
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
    push!(logger.pathogen_id[tid], pathogen_id)
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

    # keep the infecter index up to date once it exists (see get_infections_between)
    idx = logger.infecter_index
    idx === nothing || register!(idx, a, b, tick)

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
        logger, a, b, pathogen_id, progression_category, tick,
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


"""
    _build_infecter_index!(logger::InfectionLogger)

Creates the logger's `InfecterIndex`, backfilled from everything logged so far and sized
from the population's declared id range.
"""
function _build_infecter_index!(logger::InfectionLogger)
    idx = InfecterIndex(logger.id_a, logger.id_b, logger.tick;
        minid = logger.minid, maxid = logger.maxid)
    logger.infecter_index = idx
    return idx
end

"""
    get_infections_between(logger::InfectionLogger, infecter::Int32, start_tick::Int16, end_tick::Int16)

Returns the ids of all individuals `infecter` infected in `[start_tick, end_tick]`, in
chronological order.

The first call builds an `InfecterIndex` over the infections logged so far, which `log!`
then maintains incrementally. Runs that never call this carry no index and pay nothing.
Not thread-safe: call it from a serial phase, as `process_events!` does.
"""
function get_infections_between(logger::InfectionLogger, infecter::Int32, start_tick::Int16, end_tick::Int16)
    idx = logger.infecter_index
    idx === nothing && (idx = _build_infecter_index!(logger))

    _merge_staged!(idx)
    return _walk_infections_between(idx, infecter, start_tick, end_tick)
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
        file["pathogen_id"] = vcat(logger.pathogen_id...)
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
