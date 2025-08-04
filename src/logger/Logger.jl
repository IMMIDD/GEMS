# DEFINE LOGGER STRUCTURE AND FUNCTIONALITY
export Logger, TickLogger, EventLogger, InfectionLogger, VaccinationLogger, DeathLogger, TestLogger, PoolTestLogger, SeroprevalenceLogger
export QuarantineLogger, CustomLogger
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
- `id_a::Vector{Int32}`: Identifiers of the agents that are infecting
- `id_b::Vector{Int32}`: Identifiers of the agents to be infected
- `infectious_tick::Vector{Int16}`: Ticks of infected to become infectious
- `symptoms_tick::Vector{Int16}`: Tick at which infectee develops symptoms (-1 if not at all)
- `severeness_tick::Vector{Int16}`: Tick at which infectee develops severe symptoms (-1 if not at all)
- `hospital_tick::Vector{Int16}`: Tick at which infectee is admitted to the hospital (-1 if not at all)
- `icu_tick::Vector{Int16}`: Tick at which infectee is admitted to the icu (-1 if not at all)
- `ventilation_tick::Vector{Int16}`: Tick at which infectee needs ventilation (-1 if not at all)
- `removed_tick::Vector{Int16}`: Ticks of agents to be recovered
- `death_tick::Vector{Int16}`: Ticks of death (if caused by this infection)
- `symptom_category::Vector{Int8}`: Symptom Category of the disease progression 
    of the infection
- `tick::Vector{Int16}`: Ticks of infections
- `setting_id::Vector{Int32}`: Identifiers of settings where the infections happened
- `setting_type::Vector{Char}`: Types of settings where the infections happened
- `lat::Float32`: Latitude of infection event location
- `lon::Float32`: Longitude of infection event location
- `ags::Vector{Int32}`: AGS of the settings where the infections happened
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
    infectious_tick::Vector{Int16} = Vector{Int16}(undef, 0)
    symptoms_tick::Vector{Int16} = Vector{Int16}(undef, 0)
    severeness_tick::Vector{Int16} = Vector{Int16}(undef, 0)
    hospital_tick::Vector{Int16} = Vector{Int16}(undef, 0)
    icu_tick::Vector{Int16} = Vector{Int16}(undef, 0)
    ventilation_tick::Vector{Int16} = Vector{Int16}(undef, 0)
    removed_tick::Vector{Int16} = Vector{Int16}(undef, 0)
    death_tick::Vector{Int16} = Vector{Int16}(undef, 0)
    symptom_category::Vector{Int8} = Vector{Int8}(undef, 0)

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
    log!(logger::InfectionLogger, a::Int32, b::Int32, tick::Int16, infectious_tick::Int16,
    symptoms_tick::Int16, severeness_tick::Int16, hospital_tick::Int16, icu_tick::Int16,
    ventilation_tick::Int16, removed_tick::Int16, death_tick::Int16, symptom_category::Int8,
    setting_id::Int32, setting_type::Char, lat::Float32, lon::Float32, ags::Int32,
    source_infection_id::Int32)

Logs an infection event into the specified `InfectionLogger`.
Returns a new infection_id for the newly added infection.

    
# Parameters

- `logger::InfectionLogger`: Logger instance
- `a::Int32`: ID of infecting individual
- `b::Int32`: ID of infected individual
- `tick::Int16`: Current simultion tick
- `infectious_tick::Int16`: Tick of individual becoming infectious 
- `symptoms_tick::Int16`: Tick of individual becoming symptomatic
- `severeness_tick::Int16`: Tick of individual becoming a severe case
- `hospital_tick::Int16`: Tick of individual being hospitalized
- `icu_tick::Int16`:  Tick of individual being admitted to ICU
- `ventilation_tick::Int16`: Tick of individual being admitted to ventilation
- `removed_tick::Int16`: Tick of individual recovering/dying
- `death_tick::Int16`: Tick of individual death (if died)
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
function log!(
        logger::InfectionLogger,
        a::Int32,
        b::Int32,
        tick::Int16,
        infectious_tick::Int16,
        symptoms_tick::Int16,
        severeness_tick::Int16,
        hospital_tick::Int16,
        icu_tick::Int16,
        ventilation_tick::Int16,
        removed_tick::Int16,
        death_tick::Int16,
        symptom_category::Int8,
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
        push!(logger.tick, tick)
        push!(logger.infectious_tick, infectious_tick)
        push!(logger.severeness_tick, severeness_tick)
        push!(logger.hospital_tick, hospital_tick)
        push!(logger.icu_tick, icu_tick)
        push!(logger.ventilation_tick, ventilation_tick)
        push!(logger.symptoms_tick, symptoms_tick)
        push!(logger.removed_tick, removed_tick)
        push!(logger.death_tick, death_tick)
        push!(logger.symptom_category, symptom_category)
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

| Name                  | Type    | Description                                                 |
| :-------------------- | :------ | :---------------------------------------------------------- |
| `infection_id`        | `Int32` | Identifier of this infection event                          |
| `tick`                | `Int16` | Tick of the infection event                                 |
| `id_a`                | `Int32` | Infecter id                                                 |
| `id_b`                | `Int32` | Infectee id                                                 |
| `infectious_tick`     | `Int16` | Tick at which infectee becomes infectious                   |
| `symptoms_tick`       | `Int16` | Tick at which infectee develops symptoms (-1 if not at all) |
| `removed_tick`        | `Int16` | Tick at which infectee becomes removed (recovers)           |
| `death_tick`          | `Int16` | Tick at which infectee dies                                 |
| `symptom_category`    | `Int8`  | Last state of disease progression before recovery           |
| `setting_id`          | `Int32` | Id of setting in which infection happens                    |
| `setting_type`        | `Char`  | setting type of the infection setting                       |
| `ags`                 | `Int32` | AGS of the infection setting                                |
| `source_infection_id` | `Int32` | Id of the infecter's infection event                        |
"""
function dataframe(logger::InfectionLogger)
    return DataFrame(
        infection_id = logger.infection_id,
        tick = logger.tick,
        id_a = logger.id_a,
        id_b = logger.id_b,
        infectious_tick = logger.infectious_tick,
        removed_tick = logger.removed_tick,
        death_tick = logger.death_tick,
        symptoms_tick = logger.symptoms_tick,
        severeness_tick= logger.severeness_tick,
        hospital_tick= logger.hospital_tick,
        icu_tick= logger.icu_tick,
        ventilation_tick= logger.ventilation_tick,
        symptom_category = logger.symptom_category,
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
        file["infectious_tick"] = logger.infectious_tick
        file["symptoms_tick"] = logger.symptoms_tick
        file["removed_tick"] = logger.removed_tick
        file["symptom_category"] = logger.symptom_category
        file["setting_id"] = logger.setting_id
        file["setting_type"] = logger.setting_type
        file["lat"] = logger.lat
        file["lon"] = logger.lon
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
hasfuncs(cl::CustomLogger) = !(length(cl.funcs) == 1 && first(cl.funcs) == :tick)


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
