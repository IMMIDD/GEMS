# DEFINE RESULTDATA AND FUNCTIONALITY
export AbstractResultData
export ResultData

export ResultDataFunction, ResultDataStyle

export meta_data, execution_date, execution_date_formatted, GEMS_version, config_file, config_file_val, population_file, population_params, final_tick
export sim_data, number_of_individuals, initial_infections, total_infections, attack_rate, setting_data
export setting_sizes, globalsetting_flag, pathogens, vaccine, vaccination_strategy, total_quarantines, total_tests
export tick_unit, start_condition, stop_criterion, strategies, kernel, julia_version
export system_data, word_size, threads, cpu_data, total_mem_size, free_mem_size, model_size
export git_repo, git_branch, git_commit
export dataframes, population_size, setting_age_contacts, infections, vaccinations, deaths, effectiveR,aggregated_setting_age_contacts
export compartment_periods, aggregated_compartment_periods, cumulative_disease_progressions, tick_cases, tick_deaths, tick_vaccinations
export cumulative_cases, compartment_fill, cumulative_deaths, cumulative_vaccinations, age_incidence
export tests, tick_pooltests, detected_tick_cases,rolling_observed_SI, time_to_detection, detection_rate, cumulative_quarantines, tick_hosptitalizations
export customlogger, household_attack_rates
export population_pyramid, timer_output, timer_output!, infections_hash, data_hash, id, hashes
export exportJLD, exportJSON
export import_resultdata,determine_difference, remove_fields!, merge_rd!, resultdata_functions
export clean_rd!

export allempty, someempty

export info

###
### PRIVATE FUNCTIONS
###

"""
    cpudata(resultData)

Wrapper for the `cpuinfo()` function from the `CpuId` package to catch exceptions caused by incompatible platforms (e.g. ARM Macs)
"""
function cpudata()
    
    processorInfo = "Processor information could not be read on this machine."
    try 
        processorInfo = cpuinfo()
    catch e
    end

    return(processorInfo)
end

"""
    process_funcs(func_dicts::Dict)

Takes a nested dictionary of functions (which must be created by
ResultData initializers) and runs the functions, replacing them 
with their result value in a new output dictionary. This way,
the generation of ResultData can be parallelized.
"""
function process_funcs(func_dicts::Dict)

    if PARALLEL_POST_PROCESSING
        # print warning if memory might not suffice
        if Sys.free_memory() / Sys.total_memory() < 0.5
            @warn "You are running the Post Processor in parallel-mode with less than 50% available system memory. If you encounter severe performance issues, please disable the PARALLEL_POST_PROCESSING flag in constants.jl"
        end 
    end

    data = Dict{String, Any}()

    for (key, dct) in func_dicts
        data[key] = Dict()

        #if parallel post processing is enabled
        if PARALLEL_POST_PROCESSING

            l = ReentrantLock()
            Threads.@threads for field_name in collect(keys(dct))
                val = dct[field_name]()
                lock(l) do
                    data[key][field_name] = val
                end
            end

        # non-parallel post processing
        else
            for field_name in collect(keys(dct))
                print("\r$(subinfo("$key/$field_name"))")
                data[key][field_name] = dct[field_name]()
            end
        end
    end

    print("\r$(subinfo("Done"))")

    return(data)
end


"""
    ResultDataStyle

Abstract type, whose implementations define the structure of a `ResutltData` object.
"""
abstract type ResultDataStyle end




"""
    get_style(style::String)

Find a `ResultDataStyle` data type based on its name.

# Returns

- `DataType`: Result Data Style Data Type that matches the input string.
"""
function get_style(style::String)
    # Determine the style to be used
    id = findfirst(x -> occursin(style, x), string.(concrete_subtypes(ResultDataStyle)))
    if isnothing(id)
        style = concrete_subtypes(ResultDataStyle)[1]
    else
        style = concrete_subtypes(ResultDataStyle)[id]
    end
    return style
end


###
### INCLUDE RESULT DATA STYLES
###

# The src/model_analysis/rd_styles folder contains a dedicated file
# for each ResultDataStyle.
# If you want to set up a new style, simply add a file to the folder and 
# make sure to define the respective struct there and export it (using the export statement).

# include all Julia files from the "rd_styles"-folder
dir = basefolder() * "/src/model_analysis/rd_styles"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)


###
### ABSTRACT RESULT DATA OBJECT
###

abstract type AbstractResultData end


###
### RESULT DATA OBJECT
###

"""
    ResultData <: AbstractResultData

A struct that stores all processed data of a single simulation run.
It holds four internal dictionaries with meta-, simulation-, system- and setting-related data
as well as multiple DataFrames that are the PostProcessor outcomes.
Note that some information (i.e., execution date or GEMS version) is only read
out upon generation of the ResultData object. Thus, there can be inconsistencies
if the ResultData object is not generated right after simulation execution.
However, as the main()-functions trigger post-processing automatically after the 
simulation terminated, deviations are minimal.
"""
mutable struct ResultData <: AbstractResultData

    data::Dict

    @doc """

        ResultData(postProcessor::PostProcessor; style::String="")

    Create a `ResultData` object using a `PostProcessor` and a key, that describes the level of detail 
    for the fields to be calculated. Post Processing requires a simulation to be done.
    """
    function ResultData(postProcessor::PostProcessor; style::String="")
        printinfo("Processing simulation data")
        
        # Create the style struct
        style = get_style(style)(postProcessor)
        # Use the data to create the ResultData struct
        rd = new(style.data)

        # add unique ID
        if !haskey(rd.data, "meta_data")
            rd.data["meta_data"] = Dict()
        end
        
        rd.data["meta_data"]["id"] = uuid4() |> string

        return(rd)
    end

    @doc """

        ResultData(postProcessors::Vector{PostProcessor}; style::String="", print_infos::Bool = false)

    Create a vector `ResultData` objects using a vector of associated `PostProcessor` objects and a key, that describes the level of detail 
    for the fields to be calculated. Post Processing requires a simulation to be done.
    It supresses the usual info outputs that are being made during the `ResultData`
    generation. If you want to enable them, pass `print_infos = true`.
    """
    function ResultData(postProcessors::Vector{PostProcessor}; style::String="", print_infos::Bool = false)
        
        prev_print_state = GEMS.PRINT_INFOS
        cnt = 0 # counter for printing

        rds = Vector{ResultData}()
        for pp in postProcessors
            printinfo("Processing Simulation $(cnt = cnt + 1)/$(postProcessors |> length) in Batch")
            GEMS.PRINT_INFOS = print_infos
            push!(rds, ResultData(pp, style = style))
            GEMS.PRINT_INFOS = prev_print_state
        end

        return rds
    end

    @doc """

        ResultData(sim::Simulation; style::String = "")

    Create a `ResultData` object using a `Simulation` and the name of a `ResultDataStyle`, that describes the level of detail 
    for the fields to be calculated. This constructor instantiates a default `PostProcessor` for 
    the passed simulation object. If you want to manually configure the `PostProcessor`,
    you need to instantiate it first and pass the `PostProcessor` to the `ResultData` constructor instead.
    Post Processing requires a simulation to be done.
    """
    ResultData(sim::Simulation; style::String = "") = ResultData(PostProcessor(sim), style = style)

    @doc """

        ResultData(sim::Vector{Simulation}; style::String = "", print_infos::Bool = false)

    Create a vector `ResultData` objects using a vector of `Simulation` objects and the name of a `ResultDataStyle`, that describes the level of detail 
    for the fields to be calculated. If you want to manually configure the `PostProcessor`,
    you need to instantiate it first and pass the `PostProcessor` to the `ResultData` constructor instead.
    Post Processing requires a simulation to be done.
    It supresses the usual info outputs that are being made during the `ResultData`
    generation. If you want to enable them, pass `print_infos = true`.
    """
    ResultData(sim::Vector{Simulation}; style::String = "", print_infos::Bool = false) = ResultData(PostProcessor(sim), style = style, print_infos = print_infos)

    @doc """

        ResultData(batch::Batch; style::String = "", print_infos::Bool = false)

    Create a vector `ResultData` objects using a `Batch` object and the name of a `ResultDataStyle`, that describes the level of detail 
    for the fields to be calculated. If you want to manually configure the `PostProcessor`s,
    you need to instantiate them first and pass the `PostProcessor`s to the `ResultData` constructor instead.
    Post Processing requires a simulation to be done.
    It supresses the usual info outputs that are being made during the `ResultData`
    generation. If you want to enable them, pass `print_infos = true`.
    """
    ResultData(batch::Batch; style::String = "", print_infos::Bool = false) = ResultData(simulations(batch), style = style, print_infos = print_infos)
end

###
### Meta Data
###

"""
    meta_data(rd::ResultData)

Returns the `meta_data` dictionary of the `ResultData`.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function meta_data(rd::ResultData)
    return(get(rd.data, "meta_data", Dict()))
end

"""
    execution_date(rd::ResultData)

Returns the timestamp of result data generation.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function execution_date(rd::ResultData)
    return(get(rd |> meta_data, "execution_date", Dict()))
end

"""
    execution_date_formatted(rd::ResultData)

Returns the (formatted for report) timestamp of result data generation.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function execution_date_formatted(rd::ResultData)

    date = get(rd |> meta_data, "execution_date", Dict())

    if date |> isempty
        return(Dict())
    end

    input_format = dateformat"yyyy-mm-ddTHH:MM:SS"
    output_format = dateformat"U dd, yyyy - HH:MM"
    
    parsed_date = Dates.DateTime(date, input_format)
    formatted_date = Dates.format(parsed_date, output_format)

    return(formatted_date)
end

"""
    GEMS_version(rd::ResultData)

Returns the GEMS version this ResultData object was generated with.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function GEMS_version(rd::ResultData)
    return(get(rd |> meta_data, "GEMS_version", Dict()))
end

"""
    config_file(rd::ResultData)

Returns the path to the config file
"""
function config_file(rd::ResultData)
    return(get(rd |> meta_data, "config_file", Dict()))
end

"""
    config_file_val(rd::ResultData)

Returns the parsed config file.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function config_file_val(rd::ResultData)
    return(get(rd |> meta_data, "config_file_val", Dict()))
end

"""
    population_file(rd::ResultData)

Returns the path to the population file
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function population_file(rd::ResultData)
    return(get(rd |> meta_data, "population_file", Dict()))
end

"""
    population_params(rd::ResultData)

Returns parameters that were used to generate the population.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function population_params(rd::ResultData)
    return(get(rd |> meta_data, "population_params", Dict()))
end

"""
    timer_output(rd::ResultData)

Returns the `TimerOutput` object used to supply debug report with execution time information
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function timer_output(rd::ResultData)
    return(get(rd |> meta_data, "timer_output", Dict()))
end

"""
    timer_output!(rd::ResultData, timer_output::TimerOutput)

Sets the `TimerOutput` object for a `ResultData` object
"""
function timer_output!(rd::ResultData, timer_output::TimerOutput)
    rd.data["meta_data"]["timer_output"] = timer_output
end


###
### Simultion Data
###

"""
    sim_data(rd::ResultData)

Returns the sim_data of result data.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function sim_data(rd::ResultData)
    return(get(rd.data, "sim_data", Dict()))
end

"""
    final_tick(rd::ResultData)

Returns the tick counter at the end of the simulation run.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function final_tick(rd::ResultData)
    return(get(rd |> sim_data, "final_tick", Dict()))
end

"""
    label(rd::ResultData)

Returns the lable of the simulation run.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function label(rd::ResultData)
    return(get(rd |> sim_data, "label", Dict()))
end

"""
    number_of_individuals(rd::ResultData)

Returns the total number of individuals in the population model.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function number_of_individuals(rd::ResultData)
    return(get(rd |> sim_data, "number_of_individuals", Dict()))
end

"""
    initial_infections(rd::ResultData)

Returns the number of individuals who are marked as infected during initialization.
This happens before the actual simulation run.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function initial_infections(rd::ResultData)
    return(get(rd |> sim_data, "initial_infections", Dict()))
end

"""
    total_infections(rd::ResultData)

Returns the row count of the PostProcessors' `infections`-DataFrame.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function total_infections(rd::ResultData)
    return(get(rd |> sim_data, "total_infections", Dict()))
end

"""
    attack_rate(rd::ResultData)

Returns the simulation's attack rate.
It's total infections divided by population size.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function attack_rate(rd::ResultData)
    return(get(rd |> sim_data, "attack_rate", Dict()))
end

"""
    setting_data(rd::ResultData)

Returns a DataFrame containing information on all setting types.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function setting_data(rd::ResultData)
    return(get(rd |> sim_data, "setting_data", Dict()))
end

"""
    setting_sizes(rd::ResultData)

Returns a Dictionary containing information on all setting sizes.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function setting_sizes(rd::ResultData)
    return(get(rd |> sim_data, "setting_sizes", Dict()))
end

"""
    region_info(rd::ResultData)

Returns a Dataframe with population size and area per municiaplity
(if model is geolocalized).
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function region_info(rd::ResultData)
    return(get(rd |> sim_data, "region_info", Dict()))
end

"""
    pathogens(rd::ResultData)

Returns an array of pathogen parameters.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function pathogens(rd::ResultData)
    return(get(rd |> sim_data, "pathogens", Dict()))
end

"""
    tick_unit(rd::ResultData)

Returns the unit of time that one tick corresponds to.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tick_unit(rd::ResultData)
    return(get(rd |> sim_data, "tick_unit", Dict()))
end

"""
    start_condition(rd::ResultData)

Returns the `StartCondition` object the simulation was initialized with.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function start_condition(rd::ResultData)
    return(get(rd |> sim_data, "start_condition", Dict()))
end

"""
    stop_criterion(rd::ResultData)

Returns the `StopCriterion` object of the simulation.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function stop_criterion(rd::ResultData)
    return(get(rd |> sim_data, "stop_criterion", Dict()))
end

"""
    strategies(rd::ResultData)

Returns the strategies included in the simulation.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function strategies(rd::ResultData)
    return(get(rd |> sim_data, "strategies", Dict()))
end

"""
    symptom_triggers(rd::ResultData)

Returns the symptom triggers included in the simulation.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function symptom_triggers(rd::ResultData)
    return(get(rd |> sim_data, "symptom_triggers", Dict()))
end

"""
    testtypes(rd::ResultData)

Returns the test types included in the simulation.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function testtypes(rd::ResultData)
    return(get(rd |> sim_data, "testtypes", Dict()))
end

"""
    total_quarantines(rd::ResultData)

Returns the total quarantined agent over the course of the simulation.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function total_quarantines(rd::ResultData)
    return(get(rd |> sim_data, "total_quarantines", Dict()))
end

"""
    total_tests(rd::ResultData)

Returns a dictionary with the the total number of tests per TestType.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function total_tests(rd::ResultData)
    return(get(rd |> sim_data, "total_tests", Dict()))
end

"""
    detection_rate(rd::ResultData)

Returns the fraction of detected infections.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function detection_rate(rd::ResultData)
    return(get(rd |> sim_data, "detection_rate", Dict()))
end

###
### System Data
###

"""
    system_data(rd::ResultData)

Returns the system_data of result data.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function system_data(rd::ResultData)
    return(get(rd.data, "system_data", Dict()))
end

"""
    kernel(rd::ResultData)

Returns the system kernel information
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function kernel(rd::ResultData)
    return(get(rd |> system_data, "kernel", Dict()))
end

"""
    julia_version(rd::ResultData)

Returns the Julia version that was used to generate this result data object.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function julia_version(rd::ResultData)
    return(get(rd |> system_data, "julia_version", Dict()))
end

"""
    word_size(rd::ResultData)

Returns the system word size.
"""
function word_size(rd::ResultData)
    return(get(rd |> system_data, "word_size", "Not available!"))
end

"""
    threads(rd::ResultData)

Returns the number of threads this Julia instance was started with.
"""
function threads(rd::ResultData)
    return(get(rd |> system_data, "threads", "Not available!"))
end

"""
    cpu_data(rd::ResultData)

Returns the processor information (not available for ARM Macs)
"""
function cpu_data(rd::ResultData)
    return(get(rd |> system_data, "cpu_data", "Not available!"))
end

"""
    total_mem_size(rd::ResultData)

Returns the total system memory
"""
function total_mem_size(rd::ResultData)
    return(get(rd |> system_data, "total_mem_size",  "Not available!"))
end

"""
    free_mem_size(rd::ResultData)

Returns the available system memory
"""
function free_mem_size(rd::ResultData)
    return(get(rd |> system_data, "free_mem_size", "Not available!"))
end

"""
    git_repo(rd::ResultData)

Returns the current git repository.
"""
function git_repo(rd::ResultData)
    return(get(rd |> system_data, "git_repo", "Not available!"))
end

"""
    git_branch(rd::ResultData)

Returns the current git branch.
"""
function git_branch(rd::ResultData)
    return(get(rd |> system_data, "git_branch", "Not available!"))
end

"""
    git_commit(rd::ResultData)

Returns the current git commit.
"""
function git_commit(rd::ResultData)
    return(get(rd |> system_data, "git_commit", "Not available!"))
end

"""
    model_size(rd::ResultData)

Returns the size of the simulation model in memory.
"""
function model_size(rd::ResultData)
    return(get(rd |> system_data, "model_size",  "Not available!"))
end

"""
    population_size(rd::ResultData)

Returns the size of the population model in memory.
"""
function population_size(rd::ResultData)
    return(get(rd |> system_data, "population_size",  "Not available!"))
end

###
### Contact Data
###

"""
    setting_age_contacts(rd::ResultData)

Returns the setting_age_contacts dictionary from the ResultData object.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function setting_age_contacts(rd::ResultData)
    return(get(rd.data, "setting_age_contacts", Dict()))
end

"""
    setting_age_contacts(rd::ResultData, settingtype::DataType)

Returns an age X age contact matrix for the specified `settingtype` (e.g. Households) based on sampled data.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function setting_age_contacts(rd::ResultData, settingtype::DataType)
    return(get(rd |> setting_age_contacts, string(settingtype), Dict()))
end

"""
    aggregated_setting_age_contacts(rd::ResultData)

Returns an age group X age group contact matrix for the specified `settingtype` (e.g. Households) based on sampled data
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function aggregated_setting_age_contacts(rd::ResultData)
    return get(rd.data, "aggregated_setting_age_contacts", Dict())
end

"""
    aggregated_setting_age_contacts(rd::ResultData, settingtype::DataType)

Returns an age group X age group contact matrix for the specified `settingtype` (e.g. Households) based on sampled data
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function aggregated_setting_age_contacts(rd::ResultData, settingtype::DataType)
    return(get(rd |> aggregated_setting_age_contacts, string(settingtype), Dict()))
end

###
### Data Frames
###


"""
    dataframes(rd::ResultData)

Returns the dataframes of result data.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function dataframes(rd::ResultData)
    return(get(rd.data, "dataframes", Dict()))
end

"""
    infections(rd::ResultData)

Returns the infection DataFrame joined with individuals' attributes.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function infections(rd::ResultData)
    return(get(rd |> dataframes, "infections", Dict()))
end

"""
    vaccinations(rd::ResultData)

Returns the vaccinations DataFrame joined with individuals' attributes.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function vaccinations(rd::ResultData)
    return(get(rd |> dataframes, "vaccinations", Dict()))
end

"""
    deaths(rd::ResultData)

Returns the deaths DataFrame joined with individuals' attributes.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function deaths(rd::ResultData)
    return(get(rd |> dataframes, "deaths", Dict()))
end

"""
    effectiveR(rd::ResultData)

Returns the Effective R value over time DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function effectiveR(rd::ResultData)
    return(get(rd |> dataframes, "effectiveR", Dict()))
end

"""
    compartment_periods(rd::ResultData)

Returns the DataFrame with duration of exposed and infectious states for all infections.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function compartment_periods(rd::ResultData)
    return(get(rd |> dataframes, "compartment_periods", Dict()))
end

"""
    aggregated_compartment_periods(rd::ResultData)

Returns the DataFrame with disease state durations (normalized).
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function aggregated_compartment_periods(rd::ResultData)
    return(get(rd |> dataframes, "aggregated_compartment_periods", Dict()))
end

"""
    cumulative_disease_progressions(rd::ResultData)

Returns the DataFrame with cumultive number of individuals in certain disease states per tick.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function cumulative_disease_progressions(rd::ResultData)
    return(get(rd |> dataframes, "cumulative_disease_progressions", Dict()))
end

"""
    tick_cases(rd::ResultData)

Returns the infections per tick DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tick_cases(rd::ResultData)
    return(get(rd |> dataframes, "tick_cases", Dict()))
end

"""
    tick_deaths(rd::ResultData)

Returns the deaths per tick DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tick_deaths(rd::ResultData)
    return(get(rd |> dataframes, "tick_deaths", Dict()))
end

"""
    tick_vaccinations(rd::ResultData)

Returns the vaccinations per tick DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tick_vaccinations(rd::ResultData)
    return(get(rd |> dataframes, "tick_vaccinations", Dict()))
end

"""
    tick_tests(rd::ResultData)

Returns the tests per tick DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tick_tests(rd::ResultData)
    return(get(rd |> dataframes, "tick_tests", Dict()))
end

"""
    tick_pooltests(rd::ResultData)

Returns the pool tests per tick DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tick_pooltests(rd::ResultData)
    return(get(rd |> dataframes, "tick_pooltests", Dict()))
end

"""
    detected_tick_cases(rd::ResultData)

Returns the detected cases per tick DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function detected_tick_cases(rd::ResultData)
    return(get(rd |> dataframes, "detected_tick_cases", Dict()))
end

"""
    rolling_observed_SI(rd::ResultData)

Returns the rolling observed serial interval DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function rolling_observed_SI(rd::ResultData)
    return(get(rd |> dataframes, "rolling_observed_SI", Dict()))
end

"""
    observed_R(rd::ResultData)

Returns the observed reproduction number estimation DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function observed_R(rd::ResultData)
    return(get(rd |> dataframes, "observed_R", Dict()))
end


"""
    time_to_detection(rd::ResultData)

Returns time to detection DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function time_to_detection(rd::ResultData)
    return(get(rd |> dataframes, "time_to_detection", Dict()))
end

"""
    tick_cases_per_setting(rd::ResultData)

Returns the tests per tick DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tick_cases_per_setting(rd::ResultData)
    return(get(rd |> dataframes, "tick_cases_per_setting", Dict()))
end

"""
    tick_serial_intervals(rd::ResultData)

Returns the serial intervals per tick DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tick_serial_intervals(rd::ResultData)
    return(get(rd |> dataframes, "tick_serial_intervals", Dict()))
end


"""
    tick_generation_times(rd::ResultData)

Returns the generation times per tick DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tick_generation_times(rd::ResultData)
    return(get(rd |> dataframes, "tick_generation_times", Dict()))
end

"""
    cumulative_cases(rd::ResultData)

Returns the cumulative infections over time.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function cumulative_cases(rd::ResultData)
    return(get(rd |> dataframes, "cumulative_cases", Dict()))
end

"""
    compartment_fill(rd::ResultData)

Returns the compartment_fill infections over time.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function compartment_fill(rd::ResultData)
    return(get(rd |> dataframes, "compartment_fill", Dict()))
end

"""
    cumulative_deaths(rd::ResultData)

Returns the cumulative deaths over time.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function cumulative_deaths(rd::ResultData)
    return(get(rd |> dataframes, "cumulative_deaths", Dict()))
end

"""
    cumulative_vaccinations(rd::ResultData)

Returns the cumulative vaccinations over time.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function cumulative_vaccinations(rd::ResultData)
    return(get(rd |> dataframes, "cumulative_vaccinations", Dict()))
end

"""
    tick_hosptitalizations(rd::ResultData)

Returns the tests per tick DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tick_hosptitalizations(rd::ResultData)
    return(get(rd |> dataframes, "tick_hosptitalizations", Dict()))
end

"""
    age_incidence(rd::ResultData)

Returns a DataFrame with incidence over time stratified by age groups.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function age_incidence(rd::ResultData)
    return(get(rd |> dataframes, "age_incidence", Dict()))
end

"""
    population_pyramid(rd::ResultData)

Returns the DataFrame required to plot population pyramid (age, sex, count)
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function population_pyramid(rd::ResultData)
    return(get(rd |> dataframes, "population_pyramid", Dict()))
end


"""
    tests(rd::ResultData)

Returns the tests DataFrame .
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function tests(rd::ResultData)
    return(get(rd |> dataframes, "tests", Dict()))
end


"""
    cumulative_quarantines(rd::ResultData)

Returns the DataFrame with number of isolated individuals per tick
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function cumulative_quarantines(rd::ResultData)
    return(get(rd |> dataframes, "cumulative_quarantines", Dict()))
end


"""
    customlogger(rd::ResultData)

Returns the DataFrame of the `Simulation` object's internal custom logger.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function customlogger(rd::ResultData)
    return(get(rd |> dataframes, "customlogger", Dict()))
end


"""
    household_attack_rates(rd::ResultData)

Returns household_attack_rates DataFrame.
Look up the `PostProcessor` docs to find the column definitions.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function household_attack_rates(rd::ResultData)
    return(get(rd |> dataframes, "household_attack_rates", Dict()))
end

household_attack_rates

###
### Hashes
###


"""
    hashes(rd::ResultData)

Returns the dataframes of result data.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function hashes(rd::ResultData)
    return(get(rd.data, "hashes", Dict()))
end

"""
    infections_hash(rd::ResultData)

Returns a `SHA1` hash value for the `infections` DataFrame
based on the `tick`, `id_a`, and `id_b` column.
Returns an empty dictionary if the data is not available in the input `ResultData` object.
"""
function infections_hash(rd::ResultData)
    return(
        rd |> infections |>
            x -> DataFrames.select(x, :tick, :id_a, :id_b) |>
            x -> sort!(x) |>
            ContentHashes.hash
    )
end

"""
    data_hash(rd::ResultData)

Returns a `SHA1` hash value for the `ResultData` object.
"""
function data_hash(rd::ResultData)
    return(rd |> ContentHashes.hash)
end

"""
    id(rd::ResultData)

Returns the unique identifer of the `ResultData` object.
"""
function id(rd::ResultData)
    return(rd.data["meta_data"]["id"])
end

###
### VECTOR FUNCTIONS
###

"""
    allempty(f::Function, rds::Vector{ResultData})

Returns `true` if the provided function returns an empty dictionary
for all `ResultData` objects in the provided vector.
"""
function allempty(f::Function, rds::Vector{ResultData})
    for rd in rds
        if !(rd |> f |> isempty)
            return false
        end
    end
    return true
end

"""
    someempty(f::Function, rds::Vector{ResultData})

Returns `true` if the provided function returns an empty 
dictionary for at least one of the `ResultData` objects.
"""
function someempty(f::Function, rds::Vector{ResultData})
    for rd in rds
        if rd |> f |> isempty
            return true
        end
    end
    return false
end

###
### EXPORT FUNCTIONS
###

"""
    exportJLD(rd::ResultData, directory::AbstractString)

Exports the `ResultData` object as a JLD2 file, storing it in the specified `directory`.
"""
function exportJLD(rd::ResultData, directory::AbstractString)
    mkpath(directory)
    jldsave(directory * "/resultdata.jld2"; rd)
end

"""
    exportJSON(rd::ResultData, directory::AbstractString)

Exports the `ResultData` object as a JSON file, storing it in the specified `directory`.
All DataFrames are excluded from the JSON export.
Additionally removes:
- CPU data
- Strategies
- Symptom triggers
This feature is only available in the JLD2-export.
In that case, please use `exportJLD(resultData, directory)` 
"""
function exportJSON(rd::ResultData, directory::AbstractString)
    out = deepcopy(rd.data)
    
    clean_result!(out)

    # Manually remove cpu data, strategies and symptom_triggers
    delete!(get(out, "system_data", Dict()), "cpu_data")
    delete!(get(out, "sim_data", Dict()), "strategies")
    delete!(get(out, "sim_data", Dict()), "symptom_triggers")

    mkpath(directory)
    open(directory * "/runinfo.json", "w") do file
        write(file, JSON.json(out))
    end
end

"""
    obtain_fields(rd::ResultData, config::Dict)

Obtains the additional fields defined in the config dictionary from the provided
ResultData object. For this a simulation is created from the in rd contained config 
and population file and the PostProcessor and then BatchData object is created.
"""
function obtain_fields(rd::ResultData, style::String)

    # Check if essential data fields are present
    if !(rd |> infections != Dict() && rd |> vaccinations != Dict() && rd |> deaths != Dict() && rd |> cumulative_quarantines != Dict()) 
        error("Reconstruction failed. Essential dataframes missing!")
    elseif !(rd |> config_file != Dict() && rd |> population_file != Dict())
        error("Reconstruction failed. Config file and/or population file path not provided!")
    end

    # Extract the last tick
    if isa(rd |> final_tick, Integer)
        finalTick = rd |> final_tick
    elseif rd |> tick_cases != Dict()
        finalTick =  rd |> tick_cases |> nrow
    elseif rd |> age_incidence != Dict()
        finalTick =  rd |> tick_cases |> nrow
    elseif rd |> effectiveR != Dict()
        finalTick =  rd |> tick_cases |> nrow
    else
        error("Reconstruction failed. Essential final tick missing! ResultData must inlcude final_tick, tick_cases, age_incidence or effectiveR.")
    end

    # create simulation 
    sim = create_simulation(rd |> config_file, rd |> population_file)
    sim.tick = finalTick
    # Create PostProcessor
    postProcessor = PostProcessor(sim, sim |> population |> dataframe, rd |> infections, rd |> vaccinations, rd |> deaths, rd |> tests, rd |> cumulative_quarantines)
    rd = ResultData(postProcessor, style)
    return rd
end


"""
    import_resultdata(filepath::String)

Import the `ResultData` object from a jld2 file. Returns the `ResultData` object.
"""
function import_resultdata(filepath::String)
    if !isfile(filepath) || split(filepath, ".")[end] != "jld2"
        error("The provided path does not point to a jld2 file!")
    end
    # Load the file and check if it is actually a ResultData object 
    rd = get(load(filepath), "rd", Dict())
    if !isa(rd, ResultData)
        error("The provided file is not a valid ResultData object!")
    end
    return rd
end

"""
    import_resultdata(filepath::String, config::Dict=Dict())

Import the `ResultData` object from a jld2 file. Also accepts a config dictionary
that includes the fields that should be obtained from the file. If there are fields
in the config file that are not yet present in the `ResultData` object the creation of
these fields is being attempted. If there are fields present in the `ResultData` object
that are not in the config file, these fields are ommited. Providing an empty config
dictionary will lead to the generation of all fields. 
"""
function import_resultdata(filepath::String, style::String)
    # Load the file 
    rd = import_resultdata(filepath)
    # Try to create the new style from the imported one
    rd = obtain_fields(rd, style) 
    return rd
end



###
### PRINTING
###


"""
    info(rd::ResultData)

Prints info about available fields in the `ResultData` object.
"""
function info(rd::ResultData)
    println("ResultData Entries")
    for (category, data) in rd.data
        println("\u2514 $category")
        for (label, value) in data
            println("  \u2514 $label")
        end
    end
end

function Base.show(io::IO, rd::ResultData)
    
    lines = [
        () -> "ResultData Object"
        () -> "\u2514 Dataframes inside: $(rd.data["dataframes"] |> length)"
        () -> "\u2514 Config file: $(rd |> config_file |> basename)"
        () -> "  \u2514 Pathogens: $(map(x -> name(x), rd |> pathogens))"
        () -> "\u2514 Population file: $(rd |> population_file |> basename)"
        () -> "  \u2514 Individuals: $(rd |> number_of_individuals)"
        () -> "  \u2514 Settings: $((rd |> setting_data).setting_type)"
        () -> "\u2514 Simulation:"
        () -> "  \u2514 Total infections: $(rd |> total_infections)"
        () -> "  \u2514 Attack rate: $(rd |> attack_rate)"
        () -> "  \u2514 Total quarantine days: $(rd |> total_quarantines)"
        () -> "  \u2514 Total tests: $(NamedTuple{Tuple(Symbol(k) for k in keys(rd |> total_tests))}(values(rd |> total_tests)))"
        () -> "  \u2514 Test detection rate: $(rd |> detection_rate)"
    ]

    for l in lines
        try println(io, l()) catch end
    end
        
end