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
entries of the field-vectors at a given index.

# Fields
- `infection_id::Vector{Int32}`: Identifiers of this infection event
- `id_a::Vector{Int32}`: Identifiers of the agents that are infecting
- `id_b::Vector{Int32}`: Identifiers of the agents to be infected
- `infectiousness_onset::Vector{Int16}`: Tick at which infectee becomes infectious
- `symptom_onset::Vector{Int16}`: Tick at which infectee develops symptoms (-1 if not at all)
- `severeness_onset::Vector{Int16}`: Tick at which infectee develops severe symptoms (-1 if not at all)
- `hospital_admission::Vector{Int16}`: Tick at which infectee is admitted to the hospital (-1 if not at all)
- `hospital_discharge::Vector{Int16}`: Tick at which infectee is discharged from the hospital (-1 if not at all)
- `icu_admission::Vector{Int16}`: Tick at which infectee is admitted to the icu (-1 if not at all)
- `icu_discharge::Vector{Int16}`: Tick at which infectee is discharged from the icu (-1 if not at all)
- `ventilation_admission::Vector{Int16}`: Tick at which infectee is admitted to ventilation (-1 if not at all)
- `ventilation_discharge::Vector{Int16}`: Tick at which infectee is discharged from ventilation (-1 if not at all)
- `severeness_offset::Vector{Int16}`: Tick at which infectee is no longer severe (-1 if not at all)
- `recovery::Vector{Int16}`: Tick at which infectee recovers (-1 if not at all)
- `death::Vector{Int16}`: Tick at which infectee dies (-1 if not at all)
- `tick::Vector{Int16}`: Ticks of infections
- `setting_id::Vector{Int32}`: Identifiers of settings where the infections happened
- `setting_type::Vector{Char}`: Types of settings where the infections happened
- `lat::Float32`: Latitude of infection event location
- `lon::Float32`: Longitude of infection event location
- `ags::Vector{Int32}`: AGS of the settings where the infections happened
- `source_infection_id::Vector{Int32}`: Infection ID of the infecting individual at the time of infection
- `lock::ReentrantLock`: A lock for parallelised code to use to guarantee data race free 
    conditions when working with this logger.
"""
@with_kw mutable struct InfectionLogger <: EventLogger 

    # Based on this post, single vectors appear to be the fastest for logging:
    # https://discourse.julialang.org/t/logging-vs-pushing-to-dataframe/77566

    # Infection ID
    infection_id::Vector{Int32} = Vector{Int32}(undef, 0)

    # Infecting data
    id_a::Vector{Int32} = Vector{Int32}(undef, 0)

    # Infected data
    id_b::Vector{Int32} = Vector{Int32}(undef, 0)
    progression_category::Vector{Symbol} = Vector{Symbol}(undef, 0)
    infectiousness_onset::Vector{Int16} = Vector{Int16}(undef, 0)
    symptom_onset::Vector{Int16} = Vector{Int16}(undef, 0)
    severeness_onset::Vector{Int16} = Vector{Int16}(undef, 0)
    hospital_admission::Vector{Int16} = Vector{Int16}(undef, 0)
    hospital_discharge::Vector{Int16} = Vector{Int16}(undef, 0)
    icu_admission::Vector{Int16} = Vector{Int16}(undef, 0)
    icu_discharge::Vector{Int16} = Vector{Int16}(undef, 0)
    ventilation_admission::Vector{Int16} = Vector{Int16}(undef, 0)
    ventilation_discharge::Vector{Int16} = Vector{Int16}(undef, 0)
    severeness_offset::Vector{Int16} = Vector{Int16}(undef, 0)
    recovery::Vector{Int16} = Vector{Int16}(undef, 0)
    death::Vector{Int16} = Vector{Int16}(undef, 0)
    
    # External data
    tick::Vector{Int16} = Vector{Int16}(undef, 0)
    setting_id::Vector{Int32} = Vector{Int32}(undef, 0)
    setting_type::Vector{Char} = Vector{Char}(undef, 0)
    lat::Vector{Float32} = Vector{Float32}(undef, 0)
    lon::Vector{Float32} = Vector{Float32}(undef, 0)
    ags::Vector{Int32} = Vector{Int32}(undef, 0)
    source_infection_id::Vector{Int32} = Vector{Int32}(undef, 0)

    # Parallelization
    lock::ReentrantLock = ReentrantLock()
end

"""
    log!(;
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

Logs an infection event into the specified `InfectionLogger`.
Returns a new infection_id for the newly added infection.

    
# Parameters

- `logger::InfectionLogger`: Logger instance
- `a::Int32`: ID of infecting individual
- `b::Int32`: ID of infected individual
- `progression_category::Symbol`: Disease progression category of the infected individual
- `tick::Int16`: Current simultion tick
- `infectiousness_onset::Int16`: Tick of individual becoming infectious
- `symptom_onset::Int16`: Tick of individual becoming symptomatic
- `severeness_onset::Int16`: Tick of individual becoming a severe case
- `hospital_admission::Int16`: Tick of individual being hospitalized
- `hospital_discharge::Int16`: Tick of individual being discharged from hospital
- `icu_admission::Int16`:  Tick of individual being admitted to ICU
- `icu_discharge::Int16`: Tick of individual being discharged from ICU
- `ventilation_admission::Int16`: Tick of individual being admitted to ventilation
- `ventilation_discharge::Int16`: Tick of individual being discharged from ventilation
- `severeness_offset::Int16`: Tick of individual no longer being severe
- `recovery::Int16`: Tick of individual recovering
- `death::Int16`: Tick of individual death (if died)
- `symptom_category::Int8`: Symptom category
- `setting_id::Int32`: ID of setting this infection happend in
- `setting_type::Char`: Setting type as char (e.g. "h" for `Household`)
- `lat::Float32`: Latitude of infection location (obatained from the setting)
- `lon::Float32`: Longitude of infection location (obatained from the setting)
- `ags::Int32`: Amtlicher Gemeindeschlüssel (community identification number) of the region this infection happened in
- `source_infection_id::Int32`: Current infection ID of the infecting individual

# Returns

- `Int32`: New infection ID
"""
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

    new_infection_id = DEFAULT_INFECTION_ID

    lock(logger.lock) do
        # generate new infection ID
        new_infection_id = Int32((logger.infection_id |> length) + 1)

        # push data to logger vectors
        push!(logger.infection_id, new_infection_id)
        push!(logger.id_a, a)
        push!(logger.id_b, b)
        push!(logger.progression_category, progression_category)
        push!(logger.tick, tick)
        push!(logger.infectiousness_onset, infectiousness_onset)
        push!(logger.symptom_onset, symptom_onset)
        push!(logger.severeness_onset, severeness_onset)
        push!(logger.hospital_admission, hospital_admission)
        push!(logger.hospital_discharge, hospital_discharge)
        push!(logger.icu_admission, icu_admission)
        push!(logger.icu_discharge, icu_discharge)
        push!(logger.ventilation_admission, ventilation_admission)
        push!(logger.ventilation_discharge, ventilation_discharge)
        push!(logger.severeness_offset, severeness_offset)
        push!(logger.recovery, recovery)
        push!(logger.death, death)
        push!(logger.setting_id, setting_id)
        push!(logger.setting_type, setting_type)
        push!(logger.lat, lat)
        push!(logger.lon, lon)
        push!(logger.ags, ags)
        push!(logger.source_infection_id, source_infection_id)
    end

    # return new infetion id so it can be stored in the individual
    return(new_infection_id)
end


"""
    ticks(logger::InfectionLogger)

Returns a vector of ticks with logging events.
"""
function ticks(logger::InfectionLogger)
    return(logger.tick)
end

"""
    get_infections_between(logger::InfectionLogger, infecter::Int32, start_tick::Int16, end_tick::Int16)

Returns the id of infected individuals who's infection time `t` is `start_tick <= t <= end_tick`)

# Parameters

- `logger::InfectionLogger`: Logger instance
- `infecter::Int32`: ID of infecter individual that is used to filter secondary infections 
- `start_tick::Int16`: Lower bound (time)
- `end_tick::Int16`: Upper bound (time)

# Returns
- `Vector{Int32}`: List of IDs of infected individuals

"""
function get_infections_between(logger::InfectionLogger, infecter::Int32, start_tick::Int16, end_tick::Int16)
    start_idx = searchsortedfirst(logger.tick, start_tick)
    end_idx = searchsortedlast(logger.tick, end_tick)
    
    result = Vector{Int32}(undef, end_idx - start_idx + 1)
    count = 0
    
    @inbounds for i in start_idx:end_idx
        if logger.id_a[i] == infecter
            count += 1
            result[count] = logger.id_b[i]
        end
    end
    
    resize!(result, count)
    return result
end

"""
    save(logger::InfectionLogger, path::AbstractString)

Save the logger to a CSV-file at the specified path.
"""
function save(logger::InfectionLogger, path::AbstractString)
    CSV.write(path, dataframe(logger))
end

"""
    dataframe(logger::InfectionLogger)

Return a DataFrame holding the informations of the logger.

# Returns

- `DataFrame` with the following columns:

| Name                    | Type    | Description                                                               |
| :---------------------- | :------ | :------------------------------------------------------------------------ |
| `infection_id`          | `Int32` | Identifier of this infection event                                        |
| `tick`                  | `Int16` | Tick of the infection event                                               |
| `id_a`                  | `Int32` | Infecter id                                                               |
| `id_b`                  | `Int32` | Infectee id                                                               |
| `progression_category`  | `Symbol`| Disease progression category of the infected individual                   |
| `infectiousness_onset`  | `Int16` | Tick at which infectee becomes infectious                                 |
| `symptom_onset`         | `Int16` | Tick at which infectee develops symptoms (-1 if not at all)               |
| `severeness_onset`      | `Int16` | Tick at which infectee develops severe symptoms (-1 if not at all)        |
| `hospital_admission`    | `Int16` | Tick at which infectee is admitted to the hospital (-1 if not at all)     |
| `hospital_discharge`    | `Int16` | Tick at which infectee is discharged from the hospital (-1 if not at all) |
| `icu_admission`         | `Int16` | Tick at which infectee is admitted to the icu (-1 if not at all)          |
| `icu_discharge`         | `Int16` | Tick at which infectee is discharged from the icu (-1 if not at all)      |
| `ventilation_admission` | `Int16` | Tick at which infectee is admitted to ventilation (-1 if not at all)      |
| `ventilation_discharge` | `Int16` | Tick at which infectee is discharged from ventilation (-1 if not at all)  |
| `severeness_offset`     | `Int16` | Tick at which infectee is no longer severe (-1 if not at all)             |
| `recovery`              | `Int16` | Tick at which infectee recovers (-1 if not at all)                        |
| `death`                 | `Int16` | Tick at which infectee dies (-1 if not at all)                            |
| `setting_id`            | `Int32` | Id of setting in which infection happens                                  |
| `setting_type`          | `Char`  | setting type of the infection setting                                     |
| `ags`                   | `Int32` | AGS of the infection setting                                              |
| `source_infection_id`   | `Int32` | Id of the infecter's infection event                                      |
"""
function dataframe(logger::InfectionLogger)
    return DataFrame(
        infection_id = logger.infection_id,
        tick = logger.tick,
        id_a = logger.id_a,
        id_b = logger.id_b,
        progression_category = logger.progression_category,
        infectiousness_onset = logger.infectiousness_onset,
        symptom_onset = logger.symptom_onset,
        severeness_onset = logger.severeness_onset,
        hospital_admission = logger.hospital_admission,
        hospital_discharge = logger.hospital_discharge,
        icu_admission = logger.icu_admission,
        icu_discharge = logger.icu_discharge,
        ventilation_admission = logger.ventilation_admission,
        ventilation_discharge = logger.ventilation_discharge,
        severeness_offset = logger.severeness_offset,
        recovery = logger.recovery,
        death = logger.death,
        setting_id = logger.setting_id,
        setting_type = logger.setting_type,
        lat = logger.lat,
        lon = logger.lon,
        ags = logger.ags,
        source_infection_id = logger.source_infection_id
    )
end

"""
    save_JLD2(logger::InfectionLogger, path::AbstractString)

Save the logger to a JLD2 file.
"""
function save_JLD2(logger::InfectionLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["infection_id"] = logger.infection_id
        file["tick"] = logger.tick
        file["id_a"] = logger.id_a
        file["id_b"] = logger.id_b
        file["progression_category"] = logger.progression_category
        file["infectiousness_onset"] = logger.infectiousness_onset
        file["symptom_onset"] = logger.symptom_onset
        file["severeness_onset"] = logger.severeness_onset
        file["hospital_admission"] = logger.hospital_admission
        file["hospital_discharge"] = logger.hospital_discharge
        file["icu_admission"] = logger.icu_admission
        file["icu_discharge"] = logger.icu_discharge
        file["ventilation_admission"] = logger.ventilation_admission
        file["ventilation_discharge"] = logger.ventilation_discharge
        file["severeness_offset"] = logger.severeness_offset
        file["recovery"] = logger.recovery
        file["death"] = logger.death
        file["setting_id"] = logger.setting_id
        file["setting_type"] = logger.setting_type
        file["lat"] = logger.lat
        file["lon"] = logger.lon
        file["ags"] = logger.ags
        file["source_infection_id"] = logger.source_infection_id
    end
end

"""
    length(logger::InfectionLogger)

Returns the number of entries in a `InfectionLogger`.
"""
Base.length(logger::InfectionLogger) = length(logger.tick)

###
### VaccinationLogger
###
"""
    VaccinationLogger <: EventLogger 

A logging structure specifically for vaccinations. A vaccination event is given by all
entries of the field-vectors at a given index.

# Fields
- `id::Vector{Int32}`: Identifiers of the agents that are vaccinated
- `tick::Vector{Int16}`: Ticks of infections
- `lock::ReentrantLock`: A lock for parallelised code to use to guarantee data race free 
    conditions when working with this setting.
"""
@with_kw mutable struct VaccinationLogger <: EventLogger 

    # Based on this post, single vectors appear to be the fastest for logging:
    # https://discourse.julialang.org/t/logging-vs-pushing-to-dataframe/77566
    id::Vector{Int32} = Vector{Int32}(undef, 0)

    # External data
    tick::Vector{Int16} = Vector{Int16}(undef, 0)

    # Parallelization
    lock::ReentrantLock = ReentrantLock()
end

"""
    log!(vacclogger::VaccinationLogger, id::Int32, tick::Int16)

Logs a vaccination event into the specified `VaccinationLogger`.

# Parameters

- `vacclogger::VaccinationLogger`: Logger instance
- `id::Int32`: ID of the vaccinated individual
- `tick::Int16`: Time of vaccination
"""
function log!(
        vacclogger::VaccinationLogger,
        id::Int32,
        tick::Int16,
    )
    lock(vacclogger.lock) do
        push!(vacclogger.id, id)
        push!(vacclogger.tick, tick)
    end
end

"""
    save(vacclogger::VaccinationLogger, path::AbstractString)

Save the logger to a CSV-file at the specified path.
"""
function save(vacclogger::VaccinationLogger, path::AbstractString)
    CSV.write(path, dataframe(vacclogger))
end

"""
    save_JLD2(vacclogger::VaccinationLogger, path::AbstractString)

Save the vaccination logger to a JLD2 file.
"""
function save_JLD2(vacclogger::VaccinationLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["tick"] = vacclogger.tick
        file["id"] = vacclogger.id
    end
end

"""
    dataframe(vacclogger::VaccinationLogger)

Return a DataFrame holding the informations of the logger.

# Returns

- `DataFrame` with the following columns:

| Name   | Type    | Description                   |
| :----- | :------ | :---------------------------- |
| `tick` | `Int16` | Tick of the vaccination event |
| `id`   | `Int32` | Individual id                 |
"""
function dataframe(vacclogger::VaccinationLogger)
    return DataFrame(
        tick = vacclogger.tick,
        id = vacclogger.id
    )
end

"""
    length(logger::VaccinationLogger)

Returns the number of entries in a `VaccinationLogger`.
"""
Base.length(logger::VaccinationLogger) = length(logger.tick)

###
### DeathLogger
###
"""
    DeathLogger <: EventLogger 

A logging structure specifically for deaths. A death event is given by all
entrys of the field-vectors at a given index.

# Fields
- `id::Vector{Int32}`: Identifiers of the agents that died
- `tick::Vector{Int16}`: Ticks of death
- `lock::ReentrantLock`: A lock for parallelised code to use to guarantee data race free 
    conditions when working with this setting.
"""
@with_kw mutable struct DeathLogger <: EventLogger 

    # Based on this post, single vectors appear to be the fastest for logging:
    # https://discourse.julialang.org/t/logging-vs-pushing-to-dataframe/77566
    id::Vector{Int32} = Vector{Int32}(undef, 0)

    # External data
    tick::Vector{Int16} = Vector{Int16}(undef, 0)

    # Parallelization
    lock::ReentrantLock = ReentrantLock()
end

"""
    log!(deathlogger::DeathLogger, id::Int32, tick::Int16)

Logs a death event into the specified `DeathLogger`.

# Parameters

- `deathlogger::DeathLogger`: Logger instance
- `id::Int32`: ID of deceased individual
- `tick::Int16`: Time of death

"""
function log!(
        deathlogger::DeathLogger,
        id::Int32,
        tick::Int16,
    )
    lock(deathlogger.lock) do
        push!(deathlogger.id, id)
        push!(deathlogger.tick, tick)
    end
end

"""
    save(deathlogger::DeathLogger, path::AbstractString)

Save the logger to a CSV-file at the specified path.
"""
function save(deathlogger::DeathLogger, path::AbstractString)
    CSV.write(path, dataframe(deathlogger))
end

"""
    save_JLD2(deathlogger::DeathLogger, path::AbstractString)

Save the death logger to a JLD2 file.
"""
function save_JLD2(deathlogger::DeathLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["tick"] = deathlogger.tick
        file["id"] = deathlogger.id
    end
end

"""
    dataframe(deathlogger::DeathLogger)

Return a DataFrame holding the informations of the logger.

# Returns

- `DataFrame` with the following columns:

| Name   | Type    | Description             |
| :----- | :------ | :---------------------- |
| `tick` | `Int16` | Tick of the death event |
| `id`   | `Int32` | Individual id           |
"""
function dataframe(deathlogger::DeathLogger)::DataFrame
    return DataFrame(
        tick = deathlogger.tick,
        id = deathlogger.id
    )
end

"""
    length(logger::DeathLogger)

Returns the number of entries in a `DeathLogger`.
"""
Base.length(logger::DeathLogger) = length(logger.tick)


###
### TestLogger
###
"""
    TestLogger <: EventLogger 

A logging structure specifically for tests. A test event is given by all
entries of the field-vectors at a given index.

# Fields
- `id::Vector{Int32}`: Identifiers of the agents that got testet
- `test_tick::Vector{Int16}`: Ticks of test
- `test_result::Vector{Bool}`: Result of the test
- `infected::Vector{Bool}`: Actual infection state 
- `infection_id::Vector{Int32}`: ID of current infection (if infected)
- `test_type::Vector{String}`: Type of the applied test
- `reportable::Vector{Bool}`: Flag whether this test will be considered for the "detected" cases (i.e. "reported")
- `lock::ReentrantLock`: A lock for parallelised code to use to guarantee data race free 
    conditions when working with this logger.
"""
@with_kw mutable struct TestLogger <: EventLogger 

    # id of test in logger
    test_id::Vector{Int32} = Vector{Int32}(undef, 0)
    
    # Based on this post, single vectors appear to be the fastest for logging:
    # https://discourse.julialang.org/t/logging-vs-pushing-to-dataframe/77566
    id::Vector{Int32} = Vector{Int32}(undef, 0)

    # External data
    test_tick::Vector{Int16} = Vector{Int16}(undef, 0)

    # Testresult
    test_result::Vector{Bool} = Vector{Bool}(undef, 0)
    infected::Vector{Bool} = Vector{Bool}(undef, 0)
    infection_id::Vector{Int32} = Vector{Int32}(undef, 0)

    # Test type
    test_type::Vector{String} = Vector{String}(undef, 0)
    reportable::Vector{Bool} = Vector{Bool}(undef, 0)

    # Parallelization
    lock::ReentrantLock = ReentrantLock()
end

"""
    log!(testlogger::TestLogger, id::Int32, test_tick::Int16, test_result::Bool,
        infected::Bool, infection_id::Int32, test_type::String, reportable::Bool)

Logs a test event into the specified `TestLogger`.

# Parameters

- `testlogger::TestLogger`: Logger instance
- `id::Int32`: ID of individual that is being tested
- `test_tick::Int16`: Time of test
- `test_result::Bool`: Test result
- `infected::Bool`: Actual infection state
- `infection_id::Int32`: ID of infection
- `test_type::String`: Name of the respective `TestType` (e.g., "PCR")
- `reportable::Bool`: Flag whether a positive test result will be reported

"""
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
    lock(testlogger.lock) do
        # generate new infection ID
        new_test_id = Int32((testlogger.test_id |> length) + 1)

        # push data to logger vectors
        push!(testlogger.test_id, new_test_id)
        push!(testlogger.id, id)
        push!(testlogger.test_tick, test_tick)
        push!(testlogger.test_result, test_result)
        push!(testlogger.infected, infected)
        push!(testlogger.infection_id, infection_id)
        push!(testlogger.test_type, test_type)
        push!(testlogger.reportable, reportable)
    end
end

"""
    save(testlogger::TestLogger, path::AbstractString)

Save the logger to a CSV-file at the specified path.
"""
function save(testlogger::TestLogger, path::AbstractString)
    CSV.write(path, dataframe(testlogger))
end

"""
    save_JLD2(testlogger::TestLogger, path::AbstractString)

Save the test logger to a JLD2 file.
"""
function save_JLD2(testlogger::TestLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["test_id"] = testlogger.test_id
        file["test_tick"] = testlogger.test_tick
        file["id"] = testlogger.id
        file["test_result"] = testlogger.test_result
        file["infected"] = testlogger.infected
        file["infection_id"] = testlogger.infection_id
        file["test_type"] = testlogger.test_type
        file["reportable"] = testlogger.reportable
    end
end

"""
    dataframe(testlogger::TestLogger)

Return a DataFrame holding the informations of the logger.

# Returns

- `DataFrame` with the following columns:

| Name           | Type     | Description                                         |
| :------------- | :------- | :-------------------------------------------------- |
| `test_id`      | `Int32`  | ID of test in this logger                           |
| `tick`         | `Int16`  | Tick of the test                                    |
| `id`           | `Int32`  | Individual id                                       |
| `test_result`  | `Bool`   | Test result (pos./neg.)                             |
| `infected`     | `Bool`   | Actual infection state                              |
| `infection_id` | `Int32`  | ID of current infection (if infected)               |
| `test_type`    | `String` | Name of test type                                   |
| `reportable`   | `Bool`   | If true, this test causes the case to be "reported" |
"""
function dataframe(testlogger::TestLogger)::DataFrame
    return DataFrame(
        test_id = testlogger.test_id,    
        test_tick = testlogger.test_tick,
        id = testlogger.id,
        test_result = testlogger.test_result,
        infected = testlogger.infected,
        infection_id = testlogger.infection_id,
        test_type = testlogger.test_type,
        reportable = testlogger.reportable
    )
end

"""
    length(logger::TestLogger)

Returns the number of entries in a `TestLogger`.
"""
Base.length(logger::TestLogger) = length(logger.test_tick)

"""
    PoolTestLogger <: EventLogger 

A logging structure specifically for pool tests.
Pool tests take multiple individuals and evaluate whether
at least one of them is infected. A test event is given by all
entries of the field-vectors at a given index.

# Fields
- `setting_id::Vector{Int32}`: Identifiers of the setting this pooled test happened
- `setting_type{Char}`: Setting type where this pool test was applied
- `test_tick::Vector{Int16}`: Ticks of test
- `test_result::Vector{Boolean}`: Result of the test
- `no_of_individuals::Vector{Int32}`: Number of tested individuals
- `no_of_infected::Vector{Int32}`: Number of actually infected individuals
- `test_type::Vector{String}`: Type of the applied test
- `lock::ReentrantLock`: A lock for parallelised code to use to guarantee data race free 
    conditions when working with this logger.
"""
@with_kw mutable struct PoolTestLogger <: EventLogger 

    # Based on this post, single vectors appear to be the fastest for logging:
    # https://discourse.julialang.org/t/logging-vs-pushing-to-dataframe/77566
    setting_id::Vector{Int32} = Vector{Int32}(undef, 0)
    setting_type::Vector{Char} = Vector{Int32}(undef, 0)

    # External data
    test_tick::Vector{Int16} = Vector{Int16}(undef, 0)

    # Testresult
    test_result::Vector{Bool} = Vector{Bool}(undef, 0)

    no_of_individuals::Vector{Int16} = Vector{Bool}(undef, 0)
    no_of_infected::Vector{Int16} = Vector{Bool}(undef, 0)

    # Test type
    test_type::Vector{String} = Vector{String}(undef, 0)

    # Parallelization
    lock::ReentrantLock = ReentrantLock()
end

"""
    log!poollogger::PoolTestLogger, setting_id::Int32, setting_type::Char, test_tick::Int16,
        test_result::Bool, no_of_individuals::Int16, no_of_infected::Int16, test_type::String)

Logs a test event into the specified `PoolTestLogger`.

# Parameters

- `poollogger::PoolTestLogger`: Logger instance
- `setting_id::Int32`: ID of setting that is being pool-tested
- `setting_type::Char`: Setting type as char (e.g. "h" for `Household`)
- `test_tick::Int16`: Time of test
- `test_result::Bool`: Test result
- `no_of_individuals::Int16`: Number of individuals n the tested set of inividuals
- `no_of_infected::Int16`: Actual number of infected individuals in the tested set of individuals
- `test_type::String`: Name of the respective `TestType` (e.g., "PCR")

"""
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
    lock(poollogger.lock) do
        push!(poollogger.setting_id, setting_id)
        push!(poollogger.setting_type, setting_type)
        push!(poollogger.test_tick, test_tick)
        push!(poollogger.test_result, test_result)
        push!(poollogger.no_of_individuals, no_of_individuals)
        push!(poollogger.no_of_infected, no_of_infected)
        push!(poollogger.test_type, test_type)
    end
end

"""
    save(poollogger::PoolTestLogger, path::AbstractString)

Save the logger to a CSV-file at the specified path.
"""
function save(poollogger::PoolTestLogger, path::AbstractString)
    CSV.write(path, dataframe(poollogger))
end

"""
    save_JLD2(poollogger::PoolTestLogger, path::AbstractString)

Save the pool test logger to a JLD2 file.
"""
function save_JLD2(poollogger::PoolTestLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["setting_id"] = poollogger.setting_id
        file["setting_type"] = poollogger.setting_type
        file["test_tick"] = poollogger.test_tick
        file["test_result"] = poollogger.test_result
        file["no_of_individuals"] = poollogger.no_of_individuals
        file["no_of_infected"] = poollogger.no_of_infected
        file["test_type"] = poollogger.test_type
    end
end


"""
    dataframe(poollogger::PoolTestLogger)

Return a DataFrame holding the informations of the logger.

# Returns

- `DataFrame` with the following columns:

| Name                | Type     | Description                             |
| :------------------ | :------- | ------:-------------------------------- |
| `test_tick`         | `Int16`  | Tick of the test event                  |
| `setting_id`        | `Int32`  | Setting id of the tested pool           |
| `setting_type`      | `Int32`  | Setting type                            |
| `test_result`       | `Bool`   | Test result (pos./neg.)                 |
| `no_of_individuals` | `Int32`  | Number of tested individuals            |
| `no_of_infected`    | `Int32`  | Number of actually infected individuals |
| `test_type      `   | `String` | Name of test type                       |
"""
function dataframe(poollogger::PoolTestLogger)::DataFrame
    return DataFrame(
        test_tick = poollogger.test_tick,
        setting_id = poollogger.setting_id,
        setting_type = poollogger.setting_type,
        test_result = poollogger.test_result,
        no_of_individuals = poollogger.no_of_individuals,
        no_of_infected = poollogger.no_of_infected,
        test_type = poollogger.test_type
    )
end

"""
    length(logger::PoolTestLogger) 

Returns the number of entries in a `PoolTestLogger`.
"""
Base.length(logger::PoolTestLogger) = length(logger.test_tick)

###
### SeroprevalenceLogger
###


@with_kw mutable struct SeroprevalenceLogger <: EventLogger

    test_id::Vector{Int32} = Vector{Int32}(undef, 0)
    id::Vector{Int32} = Vector{Int32}(undef, 0)
    test_tick::Vector{Int16} = Vector{Int16}(undef, 0)
    test_result::Vector{Bool} = Vector{Bool}(undef, 0)
    infected::Vector{Bool} = Vector{Bool}(undef, 0)
    was_infected::Vector{Bool} = Vector{Bool}(undef, 0)
    infection_id::Vector{Int32} = Vector{Int32}(undef, 0)
    test_type::Vector{String} = Vector{String}(undef, 0)
    
    lock::ReentrantLock = ReentrantLock()
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
    lock(logger.lock) do
        new_test_id = Int32(length(logger.test_id) + 1)

        push!(logger.test_id, new_test_id)
        push!(logger.id, id)
        push!(logger.test_tick, test_tick)
        push!(logger.test_result, test_result)
        push!(logger.infected, infected)
        push!(logger.was_infected, was_infected)
        push!(logger.infection_id, infection_id)
        push!(logger.test_type, test_type)
    end
end

"""
    save(logger::SeroprevalenceLogger, path::AbstractString)

Save the seroprevalence logger to a CSV file.
"""
function save(logger::SeroprevalenceLogger, path::AbstractString)
    CSV.write(path, dataframe(logger))
end

"""
    save_JLD2(logger::SeroprevalenceLogger, path::AbstractString)

Save the seroprevalence logger to a JLD2 file.
"""
function save_JLD2(logger::SeroprevalenceLogger, path::AbstractString)
    jldopen(path,"w") do file
        file["test_id"] = logger.test_id
        file["test_tick"] = logger.test_tick
        file["id"] = logger.id
        file["test_result"] = logger.test_result
        file["infected"] = logger.infected
        file["was_infected"] = logger.was_infected
        file["infection_id"] = logger.infection_id
        file["test_type"] = logger.test_type
    end
end

"""
    dataframe(logger::SeroprevalenceLogger) -> DataFrame

Return a `DataFrame` containing all seroprevalence test records logged by the `SeroprevalenceLogger`.

# Returns

A `DataFrame` with the following columns:

| Name           | Type     | Description                                                    |
| :------------- | :------- | :------------------------------------------------------------- |
| `test_id`      | `Int32`  | Unique test ID within the logger                               |
| `test_tick`    | `Int16`  | Tick at which the test was performed                           |
| `id`           | `Int32`  | ID of the individual tested                                    |
| `test_result`  | `Bool`   | Result of the test (`true` = positive, `false` = negative)     |
| `infected`     | `Bool`   | Whether the individual was infected at the time of the test    |
| `was_infected` | `Bool`   | Whether the individual was ever infected (IgG assumed present) |
| `infection_id` | `Int32`  | ID of infection event (or -1 if never infected)                |
| `test_type`    | `String` | Type of test performed (e.g. ELISA)                            |
"""
function dataframe(logger::SeroprevalenceLogger)::DataFrame
    return DataFrame(
        test_id       = logger.test_id,
        test_tick     = logger.test_tick,
        id            = logger.id,
        test_result   = logger.test_result,
        infected      = logger.infected,
        was_infected  = logger.was_infected,
        infection_id  = logger.infection_id,
        test_type     = logger.test_type
    )
end


"""
    length(logger::SeroprevalenceLogger)

Returns the number of entries in a `SeroprevalenceLogger`.
"""
Base.length(logger::SeroprevalenceLogger) = length(logger.test_tick)


###
### QuarantineLogger
###

"""
    QuarantineLogger <: TickLogger 

A logging structure to track the number of quarantined individuals
stratified by occupation status (worker, school, all).

# Fields
- `tick::Vector{Int16}`: Simulation tick
- `quarantined::Vector{Int64}`: Overall number of quarantined individuals at the given tick
- `students::Vector{Int64}`: Number of quarantined students at the given tick
- `workers::Vector{Int64}`: Number of quarantined workers at the given tick
- `lock::ReentrantLock`: A lock for parallelised code to use to guarantee data race free 
    conditions when working with this logger.
"""
@with_kw mutable struct QuarantineLogger <: TickLogger 

    # Infecting data
    tick::Vector{Int16} = Vector{Int16}(undef, 0)
    quarantined::Vector{Int64} = Vector{Int64}(undef, 0)
    students::Vector{Int64} = Vector{Int64}(undef, 0)
    workers::Vector{Int64} = Vector{Int64}(undef, 0)

    # Parallelization
    lock::ReentrantLock = ReentrantLock()
end

"""
    log!(quarantinelogger::QuarantineLogger, tick::Int16,
        quarantined::Int64, students::Int64, workers::Int64)

Logs a the number of quarantined individuals stratified by occupation in a `QuarantineLogger`.

# Parameters

- `quarantinelogger::QuarantineLogger`: Logger instance
- `tick::Int16`: Current tick
- `quarantined::Int64`: Overall number of quarantined individuals
- `students::Int64`: Number of quarantined students
- `workers::Int64`: Number of quarantined workers

"""
function log!(
    quarantinelogger::QuarantineLogger,
    tick::Int16,
    quarantined::Int64,
    students::Int64,
    workers::Int64
)
    lock(quarantinelogger.lock) do
        push!(quarantinelogger.tick, tick)
        push!(quarantinelogger.quarantined, quarantined)
        push!(quarantinelogger.students, students)
        push!(quarantinelogger.workers, workers)
    end
end

"""
    dataframe(quarantinelogger::QuarantineLogger)

Return a DataFrame holding the informations of the logger.

# Returns

- `DataFrame` with the following columns:

| Name           | Type     | Description                             |
| :------------- | :------- | :-------------------------------------- |
| `tick`         | `Int16`  | Simulation tick                         |
| `quarantined`  | `Int64`  | Total quarantined individuals           |
| `students`     | `Int64`  | Quarantined students                    |
| `workers`      | `Int64`  | Quarantined workers                     |
"""
function dataframe(quarantinelogger::QuarantineLogger)::DataFrame
    return DataFrame(
        tick = quarantinelogger.tick,
        quarantined = quarantinelogger.quarantined,
        students = quarantinelogger.students,
        workers = quarantinelogger.workers
    )
end

"""
    length(logger::QuarantineLogger)  

Returns the number of entries in a `QuarantineLogger`.
"""
Base.length(logger::QuarantineLogger) = length(logger.tick)


###
### StateLogger
###

"""
    StateLogger <: TickLogger

A logging structure to track the overall number of individuals in different epidemiological states.
Exposed, infectious, dead, and detected (reported) cases are logged.

# Fields
- `tick::Vector{Int16}`: Simulation tick
- `exposed::Vector{Int64}`: Number of exposed individuals at the given tick
- `infectious::Vector{Int64}`: Number of infectious individuals at the given tick
- `dead::Vector{Int64}`: Number of dead individuals at the given tick
- `detected::Vector{Int64}`: Number of detected (reported) cases at the given tick
- `lock::ReentrantLock`: A lock for parallelised code to use to guarantee data integrity
    when working with this logger.
"""
@with_kw mutable struct StateLogger <: TickLogger

    # Health state data
    tick::Vector{Int16} = Vector{Int16}(undef, 0)
    exposed::Vector{Int64} = Vector{Int64}(undef, 0)
    infectious::Vector{Int64} = Vector{Int64}(undef, 0)
    dead::Vector{Int64} = Vector{Int64}(undef, 0)
    detected::Vector{Int64} = Vector{Int64}(undef, 0)

    # Parallelization
    lock::ReentrantLock = ReentrantLock()
end

"""
    log!(statelogger::StateLogger, tick::Int16,
        exposed::Int64, infectious::Int64, dead::Int64, detected::Int64)

Logs the number of individuals in different epidemiological states in a `StateLogger`.

# Parameters
- `statelogger::StateLogger`: Logger instance
- `tick::Int16`: Current tick
- `exposed::Int64`: Number of exposed individuals
- `infectious::Int64`: Number of infectious individuals
- `dead::Int64`: Number of dead individuals
- `detected::Int64`: Number of detected (reported) cases
"""
function log!(
    statelogger::StateLogger,
    tick::Int16,
    exposed::Int64,
    infectious::Int64,
    dead::Int64,
    detected::Int64
)
    lock(statelogger.lock) do
        push!(statelogger.tick, tick)
        push!(statelogger.exposed, exposed)
        push!(statelogger.infectious, infectious)
        push!(statelogger.dead, dead)
        push!(statelogger.detected, detected)
    end
end

"""
    dataframe(statelogger::StateLogger)

Return a DataFrame holding the informations of the logger.

# Returns

- `DataFrame` with the following columns:

| Name        | Type     | Description                     |
| :---------- | :------- | :------------------------------ |
| `tick`      | `Int16`  | Simulation tick                 |
| `exposed`   | `Int64`  | Number of exposed individuals   |
| `infectious`| `Int64`  | Number of infectious individuals|
| `dead`      | `Int64`  | Number of dead individuals      |
| `detected`  | `Int64`  | Number of detected cases        |
"""
function dataframe(statelogger::StateLogger)::DataFrame
    return DataFrame(
        tick = statelogger.tick,
        exposed = statelogger.exposed,
        infectious = statelogger.infectious,
        dead = statelogger.dead,
        detected = statelogger.detected
    )
end

"""
    length(logger::StateLogger)

Returns the number of entries in a `StateLogger`.
"""
Base.length(logger::StateLogger) = length(logger.tick)


###
### CUSTOM LOGGERS
###

"""
    CustomLogger <: TickLogger

Struct to specify custom logging mechanisms.
The constructor takes an arbitrary number of keyworded
arguments that are each a function with exactly one argument (the Sim-object)

# Example
This instance of the `CustomLogger` would extract the number of 
infected inividuals, each time the `log!`-function is called.

```julia
cl = CustomLogger(infected = sim -> count(infected, sim |> population))
log!(cl, sim)
```

# Result

```julia
    1×2 DataFrame
     Row │ infected  tick 
         │ Any       Any  
    ─────┼────────────────
       1 │ 106       0
```

# Note
The function that fires the loggers `fire_custom_loggers(sim::Simulation)`
is defined in the simulation methods script as the simulation object needs
to be "known" for "all access".
"""
mutable struct CustomLogger <: TickLogger

    funcs::Dict{Symbol, Function}
    data::DataFrame # dataframe storing everything

    function CustomLogger(;kwargs...)

        # generate internal functions dictionary
        funcs = Dict{Symbol, Function}(:tick => tick) # initial entry is tick
        for (key, val) in kwargs
            key == :tick ? throw("'tick' is a protected name and cannot be a custom column for the Logger") : nothing
            # abort if the argument is now a function
            !(typeof(val) <: Function) ? throw("The arguments passed to the CustomLogger must be a one-argument (Sim-object) function.") : nothing
            # abort if functions don't have exactly one argument
            first(methods(val)).nargs != 2 ? throw("The arumgment functions must have exactly one argument (the Sim-object)") : nothing
            
            funcs[key] = val
        end

        # generate internal dataframe
        data = DataFrame([(Symbol(k) => Any[]) for (k, v) in funcs])

        return(new(funcs, data))
    end
end

"""
    hasfuncs(cl::CustomLogger)
    
Returns true if the logger was intialized with at least one custom function.
"""
hasfuncs(cl::CustomLogger) = !(length(cl.funcs) == 1 && first(values(cl.funcs)) == tick)


"""
    dataframe(cl::CustomLogger)

Returns the internal dataframe of the `CustomLogger`.
"""
dataframe(cl::CustomLogger) = cl.data


"""
    duplicate(cl::CustomLogger)
    
Creates a new `CustomLogger` instance with the same parameters of the argument `CustomLogger`.
"""
duplicate(cl::CustomLogger) = invoke(CustomLogger, Tuple{}; (cl.funcs |> Base.copy |> f -> delete!(f, :tick) |> NamedTuple)...)

"""
    length(logger::CustomLogger)  

Returns the number of entries in a `CustomLogger`.
"""
Base.length(logger::CustomLogger) = nrow(logger.data)
