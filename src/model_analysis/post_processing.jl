#=
DEFINES POSTPROCESSOR AND FUNCTIONALITY
These functions handle the aggregation of interesting data from a simulation run
and combine them into specific output variables
=#
export PostProcessor
export simulation, infectionsDF, sim_infectionsDF, populationDF, deathsDF, testsDF, pooltestsDF, serotestsDF

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

    # dataframe cache to speed up calculations
    cache::Dict{String, Any}

    @doc """

        PostProcessor(simulation::Simulation)

    Create a `PostProcessor` object for an associated `Simulation`.
    Post Processing requires a simulation to be done.
    """
    function PostProcessor(simulation::Simulation)
       
        # convert population model to dataframe
        pop = dataframe(population(simulation))
        
        # import tests
        tests = dataframe(testlogger(simulation))
        
        # import seroprevalence tests
        serotests = dataframe(seroprevalencelogger(simulation))

        # join all infections with additional info from population DF
        infections = simulation |> infectionlogger |> dataframe

        infections = infections |>
            # calculate generation time and serial interval (self join)
            x -> leftjoin(x, 
                DataFrames.select(infections, [:infection_id, :tick, :symptom_onset]),
                on = [:source_infection_id => :infection_id],
                renamecols = "" => "_source") |>
            x -> transform(x,
                [:tick, :tick_source] => ByRow(-) => :generation_time,
                [:symptom_onset, :symptom_onset_source] => ByRow((t, s) -> (t >= 0 && !ismissing(s) && s >= 0) ? t - s : missing) => :serial_interval,
                copycols = false) |>
            x -> DataFrames.select(x, Not([:tick_source, :symptom_onset_source]))

        infections = infections |>
            # add tests
            x -> leftjoin(x, detection_ticks(tests), on = :infection_id) |>

            # add poulation data
            x -> leftjoin(x, pop, on = [:id_a => :id], renamecols = "" => "_a") |>
            x -> leftjoin(x, pop, on = [:id_b => :id], renamecols = "" => "_b")

        # lookup home-AGS for each infected individual
        infections.household_ags_b = map(
                h_id -> simulation |> settings |>
                setting_type -> setting_type[Household][h_id] |> ags |> id
            ,infections.household_b)

        # join deaths with additional info from population DF
        deaths = dataframe(deathlogger(simulation)) |>
            x -> leftjoin(x, pop, on = [:id => :id])


        # join tests with population data
        tests = tests |>
        x -> leftjoin(x, pop, on = [:id => :id])
        
        pooltests = dataframe(pooltestlogger(simulation))

        # add "Other" column to quarantines DF indicating all non-student and non-worker quarantines
        quarantines = dataframe(quarantinelogger(simulation)) |>
            x -> transform(x, [:quarantined, :students, :workers] => ByRow((q, s, w) -> q - s -w) => :other)

        compartments = dataframe(statelogger(simulation)) |>
            df -> rename!(df,
                :exposed => :exposed_cnt,
                :infectious => :infectious_cnt,
                :detected => :detected_cnt,
                :dead => :dead_cnt)

        new(simulation, infections, pop, deaths, tests, pooltests, serotests, quarantines, compartments, Dict{String, Any}())
    end


    @doc """

        PostProcessor(simulation::Simulation, population::DataFrame, infections::DataFrame, vaccinations::DataFrame, deaths::DataFrame, tests::DataFrame, quarantines::DataFrame)

    Manual reconstruction of a `PostProcessor` if all internal dataframes are known.
    This is not considered for _public_ use and only speeds up internal processes.
    """
    function PostProcessor(simulation::Simulation, population::DataFrame, infections::DataFrame, vaccinations::DataFrame, deaths::DataFrame, tests::DataFrame, quarantines::DataFrame)

        new(simulation, infections, population, vaccinations, deaths, tests, quarantines)
    end

    @doc """

        PostProcessor(simulations::Vector{Simulation})

    Create a vector of `PostProcessor` objects for a vector of associated `Simulation` objects.
    Post Processing requires all simulations to be done.
    """
    function PostProcessor(simulations::Vector{Simulation})
        return map(PostProcessor, simulations)
    end

    @doc """

        PostProcessor(batch::Batch)

    Create a vector of `PostProcessor` objects for all `Simulation`s in a `Batch`.
    Post Processing requires all simulations to be done.
    """
    PostProcessor(batch::Batch) = PostProcessor(batch.simulations)
end

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
        x -> x[x.test_result .& x.infected .& x.reportable, :] |> # filter reportable true positives
        x -> rename!(x, :test_tick => :first_detected_tick) |>
        x -> (isempty(x) ? x : groupby(x, :infection_id)) |> # is empty check prevents function from crashing if no infection was reported
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

| Name                       | Type      | Description                                                     |
| :------------------------- | :-------- | :-------------------------------------------------------------- |
| `infection_id`             | `Int32`   | Unique identifier of an infection                               |
| `tick`                     | `Int16`   | Tick of the infection event                                     |
| `id_a`                     | `Int32`   | Infecter id                                                     |
| `id_b`                     | `Int32`   | Infectee id                                                     |
| `infectious_tick`          | `Int16`   | Tick at which infectee becomes infectious                       |
| `removed_tick`             | `Int16`   | Tick at which infectee becomes removed (recovers)               |
| `symptoms_tick`            | `Int16`   | Tick at which infectee develops symptoms                        |
| `severeness_tick`          | `Int16`   | Tick at which infectee's symptoms become severe                 |
| `hospital_tick`            | `Int16`   | Tick at which infectee is hospitalized                          |
| `icu_tick`                 | `Int16`   | Tick at which infectee is admitted to ICU                       |
| `ventilation_tick`         | `Int16`   | Tick at which infectee requires ventilation                     |
| `symptom_category`         | `Int8`    | Disease progression category (asymp., mild, severe, critical)   |
| `setting_id`               | `Int32`   | Id of setting in which infection happens                        |
| `setting_type`             | `Char`    | Setting type of the infection setting                           |
| `lat`                      | `Float32` | Latitude of infection location                                  |
| `lon`                      | `Float32` | Longitude of infection location                                 |
| `ags`                      | `Int32`   | German Community Identification Number of infection             |
| `source_infection_id`      | `Int32`   | ID of the infection even that caused this infection (chain)     |
| `generation_time`          | `Int16`   | Time between preceeding infection and this exposure             |
| `serial_interval`          | `Int16`   | Time between onset of symptoms of this and preceeding infection |
| `test_type`                | `String`  | Type of test which detected this infection                      |
| `first_detected_tick`      | `Int16`   | Tick of (reportable) test that first detected this infection    |
| `sex_a`                    | `Int8`    | Infecter sex                                                    |
| `age_a`                    | `Int8`    | Infecter age                                                    |
| `number_of_vaccinations_a` | `Int8`    | Infecter number of previous vaccinations                        |
| `vaccination_tick_a`       | `Int16`   | Infecter last time of vaccination                               |
| `education_a`              | `Int8`    | Infecter education level                                        |
| `occupation_a`             | `Int16`   | Infecter occupation group                                       |
| `household_a`              | `Int32`   | Infecter associated household                                   |
| `office_a`                 | `Int32`   | Infecter associated office                                      |
| `schoolclass_a`            | `Int32`   | Infecter associated school                                      |
| `sex_b`                    | `Int8`    | Infectee sex                                                    |
| `age_b`                    | `Int8`    | Infectee age                                                    |
| `number_of_vaccinations_a` | `Int8`    | Infecter number of previous vaccinations                        |
| `vaccination_tick_a`       | `Int16`   | Infecter last time of vaccination                               |
| `education_b`              | `Int8`    | Infectee education level                                        |
| `occupation_b`             | `Int16`   | Infectee occupation group                                       |
| `household_b`              | `Int32`   | Infectee associated household                                   |
| `office_b`                 | `Int32`   | Infectee associated office                                      |
| `schoolclass_b`            | `Int32`   | Infectee associated schoolclass                                 |
| `household_ags_b`          | `Int32`   | Infectee household German Community Identification Number       |
"""
function infections(postProcessor::PostProcessor)
    return postProcessor.infectionsDF
end

"""
    populationDF(postProcessor)

Returns the internal flat population `DataFrame`.

# Columns

| Name         | Type    | Description                     |
| :----------- | :------ | :------------------------------ |
| `id`         | `Int32` | Individual id                   |
| `sex`        | `Int8`  | Individual sex                  |
| `age`        | `Int8`  | Individual age                  |
| `education`  | `Int8`  | Individual education level      |
| `occupation` | `Int16` | Individual occupation group     |
| `household`  | `Int32` | Individual associated household |
| `office`     | `Int32` | Individual associated office    |
| `school`     | `Int32` | Individual associated school    |
"""
function populationDF(postProcessor::PostProcessor)
    return postProcessor.populationDF
end

"""
    deathsDF(postProcessor::PostProcessor)

Returns the internal flat deaths `DataFrame`.

# Columns

| Name              | Type    | Description                                       |
| :---------------- | :------ | :------------------------------------------------ |
| `tick`            | `Int16` | Tick of the death event                           |
| `id`              | `Int32` | Individual's id                                   |
| `sex`             | `Int8`  | Individual's sex                                  |
| `age`             | `Int8`  | Individual's age                                  |
| `education`       | `Int8`  | Individual's education level                      |
| `occupation`      | `Int16` | Individual's occupation group                     |
| `household`       | `Int32` | Individual's associated household                 |
| `office`          | `Int32` | Individual's associated office                    |
| `school`          | `Int32` | Individual's associated school                    |
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

| Name                     | Type     | Description                                        |
| :----------------------- | :------- | :------------------------------------------------- |
| `test_tick`              | `Int16`  | Tick of the test event                             |
| `id`                     | `Int32`  | Individual's id                                    |
| `test_result`            | `Bool`   | Test result                                        |
| `infected`               | `Bool`   | Individual's current infection state               |
| `infection_id`           | `Int32`  | Individual's infection id                          |
| `test_type`              | `String` | Test name                                          |
| `reportable`             | `Bool`   | If true, a positive test result will be "reported" |
| `sex`                    | `Int8`   | Individual's sex                                   |
| `age`                    | `Int8`   | Individual's age                                   |
| `number_of_vaccinations` | `Int8`   | Individual's number of vaccinations                |
| `vaccination_tick`       | `Int16`  | Tick when the individual was last vaccinated       |
| `education`              | `Int8`   | Individual's education level                       |
| `occupation`             | `Int16`  | Individual's occupation group                      |
| `household`              | `Int32`  | Individual's associated household                  |
| `office`                 | `Int32`  | Individual's associated office                     |
| `school`                 | `Int32`  | Individual's associated school                     |

"""
function testsDF(postProcessor::PostProcessor)
    return postProcessor.testsDF
end


"""
    pooltestsDF(postProcessor::PostProcessor)

Returns the internal flat pool tests `DataFrame`.

# Columns

| Name                | Type     | Description                                    |
| :------------------ | :------- | :--------------------------------------------- |
| `test_tick`         | `Int16`  | Tick of the test event                         |
| `setting_id`        | `Int32`  | Setting id of the tested pool                  |
| `setting_type`      | `Int32`  | Setting type                                   |
| `test_result`       | `Bool`   | Test result (pos./neg.)                        |
| `no_of_individuals` | `Int32`  | Number of tested individuals                   |
| `no_of_infected`    | `Int32`  | Number of actually infected individuals        |
| `test_type`         | `String` | Name of test type                              |

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
| `test_tick`    | `Int16`  | Tick at which the test was performed                           |
| `id`           | `Int32`  | ID of the individual tested                                    |
| `test_result`  | `Bool`   | Result of the test (`true` = positive, `false` = negative)     |
| `infected`     | `Bool`   | Whether the individual was infected at the time of the test    |
| `was_infected` | `Bool`   | Whether the individual was ever infected (IgG assumed present) |
| `infection_id` | `Int32`  | ID of infection event (or -1 if never infected)                |
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
| :-------------| :------ | :---------------------------------------------------------------------- |
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
| Name               | Type    | Description                                         |
| :----------------- | :------ | :-------------------------------------------------- |
| `tick`             | `Int16` | Simulation tick (time)                              |
| `exposed_cnt`      | `Int64` | Total number of individuals in the exposed state    |
| `infectious_cnt`   | `Int64` | Total number of individuals in the infectious state |
| `detected_cnt`     | `Int64` | Total number of detected infectious individuals     |
| `deaths_cnt`       | `Int64` | Total number of individuals in the deceased state   |
"""
function compartmentsDF(postProcessor::PostProcessor)
    return(postProcessor.compartmentsDF)
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
        x -> filter(y -> y[:id_a] > 0, x)
    
    # store in internal cache
    store_cache(postProcessor, "sim_infectionsDF", sim_infs)

    return sim_infs
end

###
### INCLUDE POST PROCESSOR FUNCTIONS
###

# The src/model_analysis/post_processor folder contains a dedicated file
# for each post processor function.
# If you want to set up a new function, simply add a file to the folder and 
# make sure to define the respective function there and export it (using the export statement).

# include all Julia files from the "plots"-folder
dir = basefolder() * "/src/model_analysis/post_processing"

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