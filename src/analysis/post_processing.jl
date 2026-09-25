#=
DEFINES POSTPROCESSOR AND FUNCTIONALITY
These functions handle the aggregation of interesting data from a simulation run
and combine them into specific output variables
=#
export PostProcessor, SerialOnly
export simulation, infectionsDF, sim_infectionsDF, populationDF
export deathsDF, testsDF, pooltestsDF, serotestsDF, compartmentsDF, healthDF, customDF

"""
    PostProcessor

A type to provide data processing features supplying reports, plots, or other data analyses.

# Internal Fields

- `simulation::Simulation`: Simulation object
- `infectionsDF::DataFrame`: Infections (joined with popuation to get information on infeter and infectee)
- `populationDF::DataFrame`: Population dataframe with one row per individual
- `vaccinationsDF::DataFrame`: Output of the vaccination logger 
- `deathsDF::DataFrame`: Output of the death logger
- `testsDF::DataFrame`: Output of the test logger
- `pooltestsDF::DataFrame`: Output of the pool test logger
- `serotestsDF::DataFrame`: Output of the seroprevalence test logger
- `quarantinesDF::DataFrame`: Output of th quarantine logger
- `healthDF::DataFrame`: Output of the health logger
- `customDF::DataFrame`: Output of the custom logger
- `cache::Dict{String, Any}`: Internal cache to store and retrieve intermediate results

"""
mutable struct PostProcessor

    simulation::Simulation
    infectionsDF::DataFrame
    populationDF::DataFrame
    deathsDF::DataFrame
    testsDF::DataFrame
    pooltestsDF::DataFrame
    serotestsDF::DataFrame
    quarantinesDF::DataFrame
    compartmentsDF::DataFrame
    healthDF::DataFrame
    customDF::DataFrame

    # dataframe cache to speed up calculations
    cache::Dict{String, Any}

@doc """

        PostProcessor(simulation::Simulation; share_logger_data::Bool = true)

    Create a `PostProcessor` object for an associated `Simulation`. Post Processing requires a simulation to be done.

    With `share_logger_data` (the default), the columns the `PostProcessor`'s dataframes take from the
    simulation's loggers are the loggers' own storage rather than copies, which saves their memory;
    changing such a column in place changes the logger. Pass `false` to work on copies.
    """
    function PostProcessor(simulation::Simulation; share_logger_data::Bool = true)

        # a run can end on settings opened or closed; repack their pools here, before result steps
        # that may run concurrently read them
        repack_dirty_pools!(settingscontainer(simulation))

        # convert population model to dataframe
        pop = dataframe(population(simulation))

        # import tests
        tests = dataframe(testlogger(simulation); share = share_logger_data)

        # import seroprevalence tests
        serotests = dataframe(seroprevalencelogger(simulation); share = share_logger_data)

        # the steps below only add or replace columns, so they leave shared logger columns intact
        infections = dataframe(infectionlogger(simulation); share = share_logger_data)

        # the logger stores the progression index; resolve it here, where pathogens are known
        infections[!, :progression_id] = progression_names(pathogens(simulation),
            infections.pathogen_id, infections.progression_id)
        DataFrames.rename!(infections, :progression_id => :progression_category)

        # calculate generation time and serial interval against each infection's source infection
        source_rows = _matching_rows(infections.source_infection_id, infections.infection_id)
        tick_source = _gather(infections.tick, source_rows)
        symptom_onset_source = _gather(infections.symptom_onset, source_rows)
        infections.generation_time = infections.tick .- tick_source
        infections.serial_interval = ((t, s) -> (t >= 0 && !ismissing(s) && s >= 0) ? t - s : missing).(
            infections.symptom_onset, symptom_onset_source)

        # add tests
        leftjoin!(infections, detection_ticks(tests), on = :infection_id)

        # add population data of the infecter (_a) and the infectee (_b)
        for (id_col, suffix) in ((:id_a, "_a"), (:id_b, "_b"))
            rows = _matching_rows(infections[!, id_col], pop.id)
            for name in names(pop, Not(:id))
                infections[!, name * suffix] = _gather(pop[!, name], rows)
            end
        end

        sim_households = households(simulation)

        # each household's AGS once, so the rows read one compact vector rather than every household object
        household_ags = ags.(sim_households)
        infections.household_ags_a = _ags_of_households(infections.household_a, household_ags)
        infections.household_ags_b = _ags_of_households(infections.household_b, household_ags)

        deaths = dataframe(deathlogger(simulation); share = share_logger_data)

        # a host death ends every co-active infection: clear `:recovery` and record `:removed`
        death_rows = _matching_rows(infections.id_b, deaths.id)
        infections.recovery, removed = _recovery_and_removal(infections.recovery, deaths.tick, death_rows)
        insertcols!(infections, columnindex(infections, :recovery) + 1, :removed => removed)

        # join deaths with additional info from population DF
        leftjoin!(deaths, pop, on = :id)

        # region of each death, for regional rates that don't go via the infection rows
        transform!(deaths,
            :household => ByRow(h -> ismissing(h) ? missing : ags(sim_households[h]::Household)) => :household_ags)

        # join tests with population data
        leftjoin!(tests, pop, on = :id)
        
        pooltests = dataframe(pooltestlogger(simulation); share = share_logger_data)

        # add "Other" column to quarantines DF indicating all non-student and non-worker quarantines
        quarantines = dataframe(quarantinelogger(simulation); share = share_logger_data)
        transform!(quarantines, [:quarantined, :students, :workers] => ByRow((q, s, w) -> q - s - w) => :other)

        compartments = dataframe(statelogger(simulation); share = share_logger_data)
        rename!(compartments,
            :exposed => :exposed_cnt,
            :infectious => :infectious_cnt,
            :detected => :detected_cnt,
            :dead => :dead_cnt)

        health = dataframe(healthlogger(simulation); share = share_logger_data)

        # the custom logger keeps its data as a DataFrame already
        custom = dataframe(customlogger(simulation))
        share_logger_data || (custom = copy(custom))

        new(simulation, infections, pop, deaths, tests, pooltests, serotests, quarantines, compartments, health, custom,
            Dict{String, Any}())
    end


    @doc """

        PostProcessor(simulations::Vector{Simulation}; share_logger_data::Bool = true)

    Create a vector of `PostProcessor` objects for a vector of associated `Simulation` objects.
    Post Processing requires all simulations to be done.
    """
    function PostProcessor(simulations::Vector{<:Simulation}; share_logger_data::Bool = true)
        return map(s -> PostProcessor(s; share_logger_data), simulations)
    end

end

###
### CONCURRENCY
###

"""
    SerialOnly(f)

Marks a result data entry that must not run concurrently with others, e.g. because it draws from the
simulation's RNGs. `process_funcs` runs these sequentially.
"""
struct SerialOnly{F}
    f::F
end

(s::SerialOnly)() = s.f()



# A sampling step's own RNG: seeded per step, so its draws depend on neither order nor thread
_post_processing_rng(sim::Simulation, step::String) = Xoshiro(hash((seed(sim), step)))

###
### CACHING
###

"""
    store_cache(postProcessor::PostProcessor, name::String, data::Any)

Adds a data object to the internal PostProcessor cache if `POST_PROCESSOR_CACHING` flag
is set (in constants.jl). Can be retrieved via the specified name. 
"""
function store_cache(postProcessor::PostProcessor, name::String, data::Any)
    if POST_PROCESSOR_CACHING
        postProcessor.cache[name] = data
    end
end

"""
    in_cache(postProcessor::PostProcessor, name::String)::Bool

Returns `true` if the PostProcessor's internal cache has a data object
stored with the specified name.
"""
function in_cache(postProcessor::PostProcessor, name::String)::Bool
    return(haskey(postProcessor.cache, name))
end

"""
    load_cache(postProcessor::PostProcessor, name::String)

Returns a data object stored in the PostProcessor's internal 
cache with the specified name.
"""
function load_cache(postProcessor::PostProcessor, name::String)
    return(postProcessor.cache[name])
end


###
### HELPER FUNCTIONS
###

# The row of `ids` holding each key, 0 where none does: a left join's matching, by array index.
# `ids` must be unique integers; ids that are close together keep the index small.
function _matching_rows(keys::AbstractVector, ids::AbstractVector)
    lo, hi = isempty(ids) ? (1, 0) : Int.(extrema(ids))
    row_of = zeros(Int32, hi - lo + 1)
    for (r, id) in enumerate(ids)
        row_of[id - lo + 1] = r
    end
    rows = zeros(Int32, length(keys))
    for (k, key) in enumerate(keys)
        (ismissing(key) || key < lo || key > hi) && continue
        rows[k] = row_of[key - lo + 1]
    end
    return rows
end

"""
    OrderedCounter{K}()

Counts values per key, keeping the keys in the order they first appear - the order `groupby` gives its
groups. Lets a post processing step count in one pass where `groupby` would index every row.
"""
struct OrderedCounter{K}
    index::Dict{K, Int}
    keys::Vector{K}
    counts::Vector{Int}
end

OrderedCounter{K}() where {K} = OrderedCounter{K}(Dict{K, Int}(), K[], Int[])

# Adds `n` to `key`'s count and returns its slot, i.e. the number of the group it belongs to.
function count!(counter::OrderedCounter{K}, key::K, n::Int = 1) where {K}
    slot = get!(counter.index, key) do
        push!(counter.keys, key)
        push!(counter.counts, 0)
        length(counter.keys)
    end
    counter.counts[slot] += n
    return slot
end

# Rows per pathogen, for the pathogens of `pathogen_ids` (sorted by id, as `groupby` returns them).
function _rows_per_pathogen(pids::AbstractVector, pathogen_ids::Vector)
    counts = zeros(Int, length(pathogen_ids))
    for p in pids
        i = findfirst(==(p), pathogen_ids)
        i === nothing || (counts[i] += 1)
    end
    return counts
end

# the pathogens of a simulation, sorted by id
_sorted_pathogen_ids(pp::PostProcessor) = sort(collect(map(id, pathogens(simulation(pp)))))

# The AGS of each row's household, `missing` without one; typed like the `ByRow` it replaces, so a column
# without `missing` values is a plain `Vector{AGS}`.
function _ags_of_households(households::AbstractVector, household_ags::Vector{AGS})
    n = length(households)
    out = (n == 0 || any(ismissing, households)) ? Vector{Union{Missing, AGS}}(undef, n) : Vector{AGS}(undef, n)
    _fill_ags!(out, households, household_ags)
    return out
end

function _fill_ags!(out::Vector, households::AbstractVector, household_ags::Vector{AGS})
    Threads.@threads for k in eachindex(households)
        h = households[k]
        out[k] = ismissing(h) ? missing : household_ags[h]
    end
    return out
end

# `recovery` cleared to -1 where the host died before it, and the tick each infection ended
function _recovery_and_removal(recovery::AbstractVector, death_ticks::AbstractVector, death_rows::Vector{Int32})
    new_recovery = similar(recovery)
    removed = similar(recovery)
    Threads.@threads for k in eachindex(recovery)
        r, row = recovery[k], death_rows[k]
        if row != 0 && death_ticks[row] < r
            new_recovery[k], removed[k] = Int16(-1), death_ticks[row]
        else
            new_recovery[k], removed[k] = r, r
        end
    end
    return new_recovery, removed
end

# `col` at each of `rows`, `missing` for row 0: the column a left join adds
function _gather(col::AbstractVector{T}, rows::Vector{Int32}) where {T}
    out = Vector{Union{Missing, T}}(undef, length(rows))
    Threads.@threads for k in eachindex(rows)
        r = rows[k]
        out[k] = r == 0 ? missing : col[r]
    end
    return out
end

"""
    detection_ticks(testDF::DataFrame)

takes the `Dataframe` which comes out of the `TestLogger`, filters
it for the reportable true positive tests and returns a dataframe 
indicating when a certain `infection_id` was first detected by a 
reportable test.

# Columns
| Name                  | Type     | Description                                          |
| :-------------------- | :------- | :--------------------------------------------------- |
| `infection_id`        | `Int32`  | ID of current infection                              |
| `test_type`           | `String` | Name of test type that first detected this infection |
| `first_detected_tick` | `Int16`  | Tick when the infection (_id) was first detected     |
"""
function detection_ticks(testDF::DataFrame)
    return testDF |>
        x -> subset(x, :test_result => ByRow(identity), :infected => ByRow(identity), :reportable => ByRow(identity), view=true) |>
        x -> DataFrames.select(x, :infection_id, :tick, :test_type) |>
        x -> rename!(x, :tick => :first_detected_tick) |>
        x -> (isempty(x) ? x : groupby(x, :infection_id)) |>
        x -> isempty(x) ? x : combine(x,
            [:first_detected_tick, :test_type] => ((tick, type) -> type[argmin(tick)]) => :test_type,
            :first_detected_tick => minimum => :first_detected_tick)
end

### GETTER ###

"""
    simulation(postProcessor::PostProcessor)

Returns the associated `Simulation` object.
"""
function simulation(postProcessor::PostProcessor)
    return postProcessor.simulation
end

"""
    infectionsDF(postProcessor::PostProcessor)

Returns the internal flat infections `DataFrame`.
Lookup the docstring of `infections(postProcessor::PostProcessor)` for column definitions.
"""
function infectionsDF(postProcessor::PostProcessor)
    return postProcessor.infectionsDF
end

"""
    infections(postProcessor::PostProcessor)

Returns the internal flat infections `DataFrame`.

# Columns

| Name                   | Type      | Description                                                                          |
| :--------------------- | :-------- | :----------------------------------------------------------------------------------- |
| `infection_id`         | `Int32`   | Unique identifier of an infection                                                    |
| `tick`                 | `Int16`   | Tick of the infection event                                                          |
| `id_a`                 | `Int32`   | Infecter id                                                                          |
| `id_b`                 | `Int32`   | Infectee id                                                                          |
| `pathogen_id`          | `Int8`    | Pathogen of this infection                                                           |
| `progression_category` | `Symbol`  | Disease progression category (e.g. `:Asymptomatic`, `:Mild`, `:Severe`, `:Critical`) |
| `infectiousness_onset` | `Int16`   | Tick at which infectee becomes infectious                                            |
| `symptom_onset`        | `Int16`   | Tick at which infectee develops symptoms                                             |
| `severeness_onset`     | `Int16`   | Tick at which infectee's symptoms become severe                                      |
| `critical_onset`       | `Int16`   | Tick at which infectee's symptoms become critical                                    |
| `critical_offset`      | `Int16`   | Tick at which infectee's symptoms stop being critical                                |
| `severeness_offset`    | `Int16`   | Tick at which infectee's symptoms stop being severe                                  |
| `recovery`             | `Int16`   | Tick of recovery, or `-1` if a host death cut the infection short                    |
| `removed`              | `Int16`   | Tick at which the infection ended (recovery, or the host death that cut it short)    |
| `setting_id`           | `Int32`   | Id of setting in which infection happens                                             |
| `setting_type`         | `Char`    | Setting type of the infection setting                                                |
| `lat`                  | `Float32` | Latitude of infection location                                                       |
| `lon`                  | `Float32` | Longitude of infection location                                                      |
| `ags`                  | `Int32`   | German Community Identification Number of infection                                  |
| `source_infection_id`  | `Int32`   | ID of the infection even that caused this infection (chain)                          |
| `generation_time`      | `Int16`   | Time between preceeding infection and this exposure                                  |
| `serial_interval`      | `Int16`   | Time between onset of symptoms of this and preceeding infection                      |
| `test_type`            | `String`  | Type of test which detected this infection                                           |
| `first_detected_tick`  | `Int16`   | Tick of (reportable) test that first detected this infection                         |
| `sex_a`                | `Int8`    | Infecter sex                                                                         |
| `age_a`                | `Int8`    | Infecter age                                                                         |
| `education_a`          | `Int8`    | Infecter education level                                                             |
| `occupation_a`         | `Int16`   | Infecter occupation group                                                            |
| `household_a`          | `Int32`   | Infecter associated household                                                        |
| `office_a`             | `Int32`   | Infecter associated office                                                           |
| `schoolclass_a`        | `Int32`   | Infecter associated schoolclass                                                      |
| `sex_b`                | `Int8`    | Infectee sex                                                                         |
| `age_b`                | `Int8`    | Infectee age                                                                         |
| `education_b`          | `Int8`    | Infectee education level                                                             |
| `occupation_b`         | `Int16`   | Infectee occupation group                                                            |
| `household_b`          | `Int32`   | Infectee associated household                                                        |
| `office_b`             | `Int32`   | Infectee associated office                                                           |
| `schoolclass_b`        | `Int32`   | Infectee associated schoolclass                                                      |
| `household_ags_a`      | `AGS`     | Infecter household German Community Identification Number                            |
| `household_ags_b`      | `AGS`     | Infectee household German Community Identification Number                            |
"""
function infections(postProcessor::PostProcessor)
    return postProcessor.infectionsDF
end

"""
    populationDF(postProcessor)

Returns the internal flat population `DataFrame`.

# Columns

| Name          | Type    | Description                       |
| :------------ | :------ | :-------------------------------- |
| `id`          | `Int32` | Individual id                     |
| `sex`         | `Int8`  | Individual sex                    |
| `age`         | `Int8`  | Individual age                    |
| `education`   | `Int8`  | Individual education level        |
| `occupation`  | `Int16` | Individual occupation group       |
| `household`   | `Int32` | Individual associated household   |
| `office`      | `Int32` | Individual associated office      |
| `schoolclass` | `Int32` | Individual associated schoolclass |
"""
function populationDF(postProcessor::PostProcessor)
    return postProcessor.populationDF
end

"""
    deathsDF(postProcessor::PostProcessor)

Returns the internal flat deaths `DataFrame`.

# Columns

| Name            | Type    | Description                                            |
| :-------------- | :------ | :----------------------------------------------------- |
| `tick`          | `Int16` | Tick of the death event                                |
| `id`            | `Int32` | Individual's id                                        |
| `pathogen_id`   | `Int8`  | Pathogen credited for the death                        |
| `sex`           | `Int8`  | Individual's sex                                       |
| `age`           | `Int8`  | Individual's age                                       |
| `education`     | `Int8`  | Individual's education level                           |
| `occupation`    | `Int16` | Individual's occupation group                          |
| `household`     | `Int32` | Individual's associated household                      |
| `office`        | `Int32` | Individual's associated office                         |
| `schoolclass`   | `Int32` | Individual's associated schoolclass                    |
| `household_ags` | `AGS`   | Individual's household community identification number |
"""
function deathsDF(postProcessor::PostProcessor)
    return postProcessor.deathsDF
end


"""
    testsDF(postProcessor::PostProcessor)

Returns the internal flat tests `DataFrame`.
It was joined with the population dataframe to also
obtain personal characteristics about the testees.

# Columns

| Name           | Type     | Description                                        |
| :------------- | :------- | :------------------------------------------------- |
| `test_id`      | `Int32`  | Unique test id within the logger                   |
| `tick`         | `Int16`  | Tick of the test event                             |
| `id`           | `Int32`  | Individual's id                                    |
| `test_result`  | `Bool`   | Test result                                        |
| `infected`     | `Bool`   | Individual's current infection state               |
| `infection_id` | `Int32`  | Individual's infection id                          |
| `pathogen_id`  | `Int8`   | Pathogen the test detects                          |
| `test_type`    | `String` | Test name                                          |
| `reportable`   | `Bool`   | If true, a positive test result will be "reported" |
| `sex`          | `Int8`   | Individual's sex                                   |
| `age`          | `Int8`   | Individual's age                                   |
| `education`    | `Int8`   | Individual's education level                       |
| `occupation`   | `Int16`  | Individual's occupation group                      |
| `household`    | `Int32`  | Individual's associated household                  |
| `office`       | `Int32`  | Individual's associated office                     |
| `schoolclass`  | `Int32`  | Individual's associated schoolclass                |

"""
function testsDF(postProcessor::PostProcessor)
    return postProcessor.testsDF
end


"""
    pooltestsDF(postProcessor::PostProcessor)

Returns the internal flat pool tests `DataFrame`.

# Columns

| Name                | Type     | Description                             |
| :------------------ | :------- | :-------------------------------------- |
| `tick`              | `Int16`  | Tick of the test event                  |
| `setting_id`        | `Int32`  | Setting id of the tested pool           |
| `setting_type`      | `Char`   | Setting type                            |
| `test_result`       | `Bool`   | Test result (pos./neg.)                 |
| `no_of_individuals` | `Int16`  | Number of tested individuals            |
| `no_of_infected`    | `Int16`  | Number of actually infected individuals |
| `pathogen_id`       | `Int8`   | Pathogen the test detects               |
| `test_type`         | `String` | Name of test type                       |

"""
function pooltestsDF(postProcessor::PostProcessor)
    return postProcessor.pooltestsDF
end

"""
    serotestsDF(postProcessor::PostProcessor)

Returns the internal flat seroprevalence tests `DataFrame`.

This dataframe contains one row per seroprevalence test performed during the simulation. 
It is based on the data logged by the `SeroprevalenceLogger`.

# Returns
- `DataFrame`: Flattened seroprevalence test results.

# Columns

| Name           | Type     | Description                                                    |
| :------------- | :------- | :------------------------------------------------------------- |
| `test_id`      | `Int32`  | Unique test ID within the logger                               |
| `tick`         | `Int16`  | Tick at which the test was performed                           |
| `id`           | `Int32`  | ID of the individual tested                                    |
| `test_result`  | `Bool`   | Result of the test (`true` = positive, `false` = negative)     |
| `infected`     | `Bool`   | Whether the individual was infected at the time of the test    |
| `was_infected` | `Bool`   | Whether the individual was ever infected (IgG assumed present) |
| `infection_id` | `Int32`  | ID of infection event (or -1 if never infected)                |
| `pathogen_id`  | `Int8`   | Pathogen the test detects                                      |
| `test_type`    | `String` | Type of test performed (e.g. ELISA)                            |
"""
function serotestsDF(postProcessor::PostProcessor)
    return postProcessor.serotestsDF
end

"""
    cumulative_quarantines(postProcessor::PostProcessor)

Returns a `DataFrame` containing cumulative information about days spent in isolation. 

# Columns

| Name          | Type    | Description                                                             |
| :------------ | :------ | :---------------------------------------------------------------------- |
| `tick`        | `Int16` | Simulation tick (time)                                                  |
| `quarantined` | `Int64` | Total number of individuals in isolation during that tick               |
| `students`    | `Int64` | Total number of students in isolation during that tick                  |
| `workers`     | `Int64` | Total number of workers in isolation during that tick                   |
| `other`       | `Int64` | Total number of non-students and -workers in isolation during that tick |
"""
function cumulative_quarantines(postProcessor::PostProcessor)
    return(postProcessor.quarantinesDF)
end


"""
    compartmentsDF(postProcessor::PostProcessor)

Returns the internal flat compartments `DataFrame`.
# Columns
| Name                        | Type    | Description                                                                    |
| :-------------------------- | :------ | :----------------------------------------------------------------------------- |
| `tick`                      | `Int16` | Simulation tick (time)                                                         |
| `exposed_cnt`               | `Int64` | Total number of individuals in the exposed state                               |
| `infectious_cnt`            | `Int64` | Total number of individuals in the infectious state                            |
| `dead_cnt`                  | `Int64` | Total number of individuals in the deceased state                              |
| `detected_cnt`              | `Int64` | Total number of detected individuals                                           |
| `quarantined`               | `Int64` | Total number of individuals in quarantine                                      |
| `quarantined_students`      | `Int64` | Students in quarantine                                                         |
| `isolated_students`         | `Int64` | Students in quarantine who are infected                                        |
| `unable_to_attend_students` | `Int64` | Students unable to attend (closed class, severe, hospitalized, or quarantined) |
| `quarantined_workers`       | `Int64` | Workers in quarantine                                                          |
| `isolated_workers`          | `Int64` | Workers in quarantine who are infected                                         |
| `unable_to_attend_workers`  | `Int64` | Workers unable to attend (closed office, severe, hospitalized, or quarantined) |
"""
function compartmentsDF(postProcessor::PostProcessor)
    return(postProcessor.compartmentsDF)
end

"""
    healthDF(postProcessor::PostProcessor)

Returns a `DataFrame` of the host care events (hospital, ICU and ventilation admissions and discharges).

# Columns

| Name    | Type     | Description                                              |
| :------ | :------- | :------------------------------------------------------- |
| `tick`  | `Int16`  | Tick of the event                                        |
| `id`    | `Int32`  | Individual id                                            |
| `event` | `Symbol` | Event, e.g. `:hospital_admission` or `:icu_discharge`    |
"""
function healthDF(postProcessor::PostProcessor)
    return postProcessor.healthDF
end

"""
    customDF(postProcessor::PostProcessor)

Returns the `DataFrame` of the simulation's custom logger, one row per tick and one column per
logged function.
"""
function customDF(postProcessor::PostProcessor)
    return postProcessor.customDF
end

### DATA ANALYSIS ###

"""
    sim_infectionsDF(postProcessor::PostProcessor)

Returns a `DataFrame` containing all infections that happened during the simulation run.
As it is a direct filter on the `PostProcessor`s internal `infectionsDF`, the column structure
is identical to the output of `infectionsDF(postProcessor)`
"""
function sim_infectionsDF(postProcessor::PostProcessor)
    # load from cache if cached
    if in_cache(postProcessor, "sim_infectionsDF")
        return(load_cache(postProcessor, "sim_infectionsDF"))
    end

    # return only values that have an infecter-id (i.e. runtime-infections)
    sim_infs = infectionsDF(postProcessor) |>
        df -> subset(df, :id_a => ByRow(>(0)), view=true)
    
    # store in internal cache
    store_cache(postProcessor, "sim_infectionsDF", sim_infs)

    return sim_infs
end

###
### INCLUDE POST PROCESSOR FUNCTIONS
###

# The src/analysis/post_processor folder contains a dedicated file
# for each post processor function.
# If you want to set up a new function, simply add a file to the folder and 
# make sure to define the respective function there and export it (using the export statement).

# include all Julia files from the "plots"-folder
dir = _basefolder() * "/src/analysis/post_processing"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)

###
### PRINTING
###

function Base.show(io::IO, pp::PostProcessor)
    println(io, "Post Processor")
    println(io, "\u2514 Infections dataframe: $(nrow(pp.infectionsDF)) rows, $(ncol(pp.infectionsDF)) columns")
    println(io, "\u2514 Population dataframe: $(nrow(pp.populationDF)) rows, $(ncol(pp.populationDF)) columns")
    println(io, "\u2514 Deaths dataframe: $(nrow(pp.deathsDF)) rows, $(ncol(pp.deathsDF)) columns")
    println(io, "\u2514 Tests dataframe: $(nrow(pp.testsDF)) rows, $(ncol(pp.testsDF)) columns")
    println(io, "\u2514 Pooltests dataframe: $(nrow(pp.pooltestsDF)) rows, $(ncol(pp.pooltestsDF)) columns")
    println(io, "\u2514 Serotests dataframe: $(nrow(pp.serotestsDF)) rows, $(ncol(pp.serotestsDF)) columns")
    println(io, "\u2514 Quarantines dataframe: $(nrow(pp.quarantinesDF)) rows, $(ncol(pp.quarantinesDF)) columns")
    println(io, "\u2514 Cached: $(pp.cache |> isempty ? "[]" : pp.cache |> keys |> collect)")
end
