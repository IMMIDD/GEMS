# DATA PROCESSING FOR BATCHRUNS
export BatchProcessor

export rundata, run_ids, config_files, population_files
export tick_unit, start_conditions, stop_criteria, start_dates, final_ticks, number_of_individuals, pathogens, pathogens_by_name
export runtime, allocations
export total_infections, total_tests, attack_rate, settingdata, parameterset, strategies
export setting_age_contacts
export tick_cases, effectiveR

"""
    BatchProcessor

A type to provide data processing features supplying reports, plots, or other data analyses.
"""
mutable struct BatchProcessor

     rundata::Vector{ResultData}

     @doc """
        BatchProcessor(rundata::Vector{ResultData})

    Creates a `BatchProcessor` object for a vector of `ResultData` objects.
    """
     function BatchProcessor(rundata::Vector{ResultData})
        return new(rundata)
     end

     @doc """
        BatchProcessor(batch::Batch; stysle::String = "LightRD", print_infos::Bool = false)

    Creates a `BatchProcessor` object from a `Batch` object.
    This constructor generates the `ResultData` object for each of the `Simulation`s
    contained in the `Batch`. It supresses the usual info outputs that
    are being made during the `ResultData` generation. If you want to enable them,
    pass `print_infos = true`.
    """
     function BatchProcessor(batch::Batch; rd_style::String = "LightRD", print_infos::Bool = false)
        prev_print_state = GEMS.PRINT_INFOS
        cnt = 0 # counter for printing

        rds = Vector{ResultData}()
        for sim in simulations(batch)
            printinfo("Processing Simulation $(cnt = cnt + 1)/$(batch |> simulations |> length) in Batch")
            GEMS.PRINT_INFOS = print_infos
            push!(rds, ResultData(sim |> PostProcessor, style = rd_style))
            GEMS.PRINT_INFOS = prev_print_state
        end
        new(rds)
     end
end


###
### PRIVATE FUNCTIONS
###

"""
    extract(batchProcessor::BatchProcessor, func::Function)

Applies the provided `function` to all associated `ResultData` objects in the `rundata` vector. 
"""
function extract(batchProcessor::BatchProcessor, func::Function)
    return(map(
        x -> func(x),
        batchProcessor |> rundata
    ))
end

"""
    extract_unique(batchProcessor::BatchProcessor, func::Function)

Applies the provided `function` to all associated `ResultData` objects in the `rundata` vector and returns all unique values.
"""
function extract_unique(batchProcessor::BatchProcessor, func::Function)
    return(extract(batchProcessor, func) |> unique)
end

###
### run data
###

"""
    rundata(batchProcessor::BatchProcessor)

Returns the vector of `ResultData` objects of simulation runs that are associated with this batch.
"""
function rundata(batchProcessor::BatchProcessor)
    return(batchProcessor.rundata)
end

"""
    run_ids(batchProcessor::BatchProcessor)

Returns the vector of simulation run IDs that are associated with this batch.
"""
function run_ids(batchProcessor::BatchProcessor)
    return(map(
        x -> hash(x) |> string,
        batchProcessor |> rundata
    ))
end

"""
    config_files(batchProcessor::BatchProcessor)

Returns the associated config file.
"""
function config_files(batchProcessor::BatchProcessor)
    return(map(
        x -> config_file(x),
        batchProcessor |> rundata
    ) |> unique)
end

"""
    population_files(batchProcessor::BatchProcessor)

Returns the associated population file.
"""
function population_files(batchProcessor::BatchProcessor)
    return(map(
        x -> population_file(x),
        batchProcessor |> rundata
    ) |> unique)
end


###
### simulation data
###

"""
    tick_unit(batchProcessor::BatchProcessor)

Returns a vector of `tick_units` that were used in the associated simulations.
Values are unique and can originate from multiple simulation runs.
"""
function tick_unit(batchProcessor::BatchProcessor)
    return(map(
        x -> tick_unit(x),
        batchProcessor |> rundata
    ) |> unique)
end

"""
    start_conditions(batchProcessor::BatchProcessor)

Returns a vector of `start_conditions` that were used in the associated simulations.
Values are unique and can originate from multiple simulation runs.
"""
function start_conditions(batchProcessor::BatchProcessor)
    return(extract_unique(batchProcessor, x -> x |> start_condition |> parameters))
end

"""
    stop_criteria(batchProcessor::BatchProcessor)

Returns a vector of `stop_criteria` that were used in the associated simulations.
Values are unique and can originate from multiple simulation runs.
"""
function stop_criteria(batchProcessor::BatchProcessor)
    return(extract_unique(batchProcessor, stop_criterion))
end

"""
    start_dates(batchProcessor::BatchProcessor)

Returns a vector of `start_dates` that were used in the associated simulations.
Values are unique and can originate from multiple simulation runs.
"""
function start_dates(batchProcessor::BatchProcessor)
    return(extract_unique(batchProcessor, start_date))
end



"""
    final_ticks(batchProcessor::BatchProcessor)

Returns a vector of `final ticks` of the associated simulations.
Values are unique and can originate from multiple simulation runs.
"""
function final_ticks(batchProcessor::BatchProcessor)
    return(extract_unique(batchProcessor, final_tick))
end

"""
    number_of_individuals(batchProcessor::BatchProcessor)

Returns a vector of `number_of_individuals` that were used in the associated simulations.
Values are unique and can originate from multiple simulation runs.
"""
function number_of_individuals(batchProcessor::BatchProcessor)
    return(extract_unique(batchProcessor, number_of_individuals))
end

"""
    pathogens(batchProcessor::BatchProcessor)

Returns a vector of `pathogens` that were used in the associated simulations.
Values are unique and can originate from multiple simulation runs.
"""
function pathogens(batchProcessor::BatchProcessor)
    return(vcat(extract_unique(batchProcessor, x -> x |> pathogens |> x -> parameters.(x))...))
end

"""
    pathogens_by_name(batchProcessor::BatchProcessor)

Returns a {name, pathogen[]} dictionary of `pathogens` that were used in the associated simulations.
This is done to keep multiple pathogen configurations of the same name with varying parameters.
Names are unique and can originate from multiple simulation runs.
"""
function pathogens_by_name(batchProcessor::BatchProcessor)
    res = Dict{String, Vector{Dict}}()

    for p in batchProcessor |> pathogens
        if haskey(res, p["name"])
            push!(res[p["name"]], p)
        else
            res[p["name"]] = [p]
        end
    end

    return(res)
end

"""
    total_infections(batchProcessor::BatchProcessor)

Returns a vector of the `total_infections` accross the simulation runs in this batch.
"""
function total_infections(batchProcessor::BatchProcessor)
    rates = map(
        x -> total_infections(x),
        batchProcessor |> rundata
    )

    return(rates)
end


"""
    total_tests(batchProcessor::BatchProcessor)

Returns a Dict of vectors of the `total_tests` per TestType accross the simulation runs in this batch.
"""
function total_tests(batchProcessor::BatchProcessor)

    rates = map(
        x -> total_tests(x),
        batchProcessor |> rundata
    )
    return(rates)
end

"""
    attack_rate(batchProcessor::BatchProcessor)

Returns a vector of the `attack_rate` accross the simulation runs in this batch.
"""
function attack_rate(batchProcessor::BatchProcessor)
    rates = map(
        x -> attack_rate(x),
        batchProcessor |> rundata
    )

    return(rates)
end

"""
    
    settingdata(batchProcessor::BatchProcessor)

Returns a `{String, DataFrame}` dictionary containing information about setting types in the population files
in the simulation runs of this batch. Populations are distinguished by their population file name
stored in the key of the result dictionary.

# Dataframe Columns

| Name                 | Type      | Description                                                      |
| :------------------- | :-------- | :--------------------------------------------------------------- |
| `setting_type`       | `String`  | Setting type identifier (name)                                   |
| `number_of_settings` | `Int64`   | Overall number of settings of that type                          |
| `min_individuals`    | `Float64` | Lowest number of individuals assigned to a setting of this type  |
| `max_individuals`    | `Float64` | Highest number of individuals assigned to a setting of this type |
| `avg_individuals`    | `Float64` | Average number of individuals assigned to a setting of this type |

"""
function settingdata(batchProcessor::BatchProcessor)

    res = Dict{String, Any}()

    for rd in batchProcessor |> rundata

        pf = rd |> population_file

        if !haskey(res, pf)
            res[pf] = rd |> setting_data
        end
    end

    return(res)
end

"""
    parameterset(batchProcessor::BatchProcessor, parameters::Vector{String})

Takes the batchProcessor and a vector of strings corresponding to the keys of parameter values in 
the config file(in the format key.key.key...). Returns a `DataFrame` containing the columns `id`
with the individual simulation ids and `parameter_set` with the parameter values corresponding to
the provided keys. The parameter_set dictionaries have the same keys as the provided strings.

# Dataframe Columns

| Name            | Type     | Description                                                 |
| :---------------| :------- | :---------------------------------------------------------- |
| `run_id`        | `String` | id of the simulation run                                    |
| `parameter_set` | `Dict`   | Parameter set of the provided parameter keys.               |

"""
function parameterset(batchProcessor::BatchProcessor, parameters::Vector{String})
    df = DataFrame(run_id = String[], parameter_set = Dict[])

    for rd in batchProcessor |> rundata

        run_id = rd |> id
        config = rd |> config_file_val
        paramset = Dict()
        for param in parameters
            val = get_nested_value(config, param)
            if !isnothing(val)
                paramset[param] = val
            end
        end
        push!(df, [run_id, paramset])
    end

    return(df)
    
end

"""
    strategies(batchProcessor::BatchProcessor)

Returns a vector of the `strategies` accross the simulation runs in this batch.
"""
function strategies(batchProcessor::BatchProcessor)
    return(extract(batchProcessor, strategies))    
end

"""
    symptom_triggers(batchProcessor::BatchProcessor)

Returns a vector of the `symptom_triggers` accross the simulation runs in this batch.
"""
function symptom_triggers(batchProcessor::BatchProcessor)
    return(extract(batchProcessor, symptom_triggers))    
end

"""
    testtypes(batchProcessor::BatchProcessor)

Returns a vector of the `testtypes` accross the simulation runs in this batch.
"""
function testtypes(batchProcessor::BatchProcessor)
    return(extract(batchProcessor, testtypes))    
end

"""
    total_quarantines(batchProcessor::BatchProcessor)

Returns a vector of the `total_quarantines` accross the simulation runs in this batch.
"""
function total_quarantines(batchProcessor::BatchProcessor)
    rates = map(
        x -> total_quarantines(x),
        batchProcessor |> rundata
    )

    return(rates)
end

###
### system data
###

"""
    runtime(batchProcessor::BatchProcessor)

Returns dataframe of the runtimes of the associated simulation runs in this batch.
The columns correspond to the names of the inner timers while each row corresponds to one run.
(*Note*: This data is only available if the simulation runs were done via the `main()` function)
"""
function runtime(batchProcessor::BatchProcessor)
    # read timer outputs
    tos = map(timer_output, batchProcessor |> rundata)

    # abort if no timer output found
    if tos |> length <= 0
        return
    end

    # read names of inner timers
    nms = unique(vcat([t |> TimerOutputs.todict |> x -> x["inner_timers"]|> keys|>x->String.(x) for t in tos]...))

    # create dict entry for each inner timer with aggregated values
    #res = Dict()
    res = DataFrame()
    for n in nms
        res[!, Symbol(n)] = map(x -> TimerOutputs.todict(x)["inner_timers"]|> x -> get(x, n, Dict("time_ns" => 0))["time_ns"], tos) 
    end

    return(res)
end

"""
    allocations(batchProcessor::BatchProcessor)

Returns a dataframe for the memory allocations of the associated simulation runs in this batch.
The columns correspond to the names of the inner timers while each row corresponds to one run.
(*Note*: This data is only available if the simulation runs were done via the `main()` function)
"""
function allocations(batchProcessor::BatchProcessor)
        # read timer outputs
        tos = map(timer_output, batchProcessor |> rundata)

        # abort if no timer output found
        if tos |> length <= 0
            return
        end
    
        # read names of inner timers
        nms = unique(vcat([t |> TimerOutputs.todict |> x -> x["inner_timers"]|> keys|>x->String.(x) for t in tos]...))
        # create dict entry for each inner timer with aggregated values
        #res = Dict()
        res = DataFrame()
        for n in nms
            res[!, Symbol(n)] = map(x -> TimerOutputs.todict(x)["inner_timers"]|> x -> get(x, n, Dict("allocated_bytes" => 0))["allocated_bytes"], tos) 
        end
        return(res)
end


###
### setting age contacts
###

"""
    setting_age_contacts(batchProcessor::BatchProcessor, settingtype::DataType)

Returns a `{String, DataFrame}` dictionary containing an age X age matrix with sampled
contacts for a provided `settingtype` (i.e. Households) for each population files
of this batch. 
"""
function setting_age_contacts(batchProcessor::BatchProcessor, settingtype::DataType)
    
    res = Dict{String, Any}()

    for rd in batchProcessor |> rundata

        pf = rd |> population_file

        if !haskey(res, pf)
            res[pf] = setting_age_contacts(rd, settingtype)
        end
    end

    return(res)
    
end


###
### data frames
###
"""
    population_pyramid(batchProcessor::BatchProcessor)

Returns a `{String, DataFrame}` dictionary containing
data to generate a population pyramid for each population files
of this batch. 

# Dataframe Columns

| Name     | Type     | Description                                                 |
| :------- | :------- | :---------------------------------------------------------- |
| `age`    | `Int8`   | 1-year age classes                                          |
| `sex`    | `Int8`   | Sex according to population DataFame (0 = female, 1 = male) |
| `gender` | `String` | String variant of Sex [Female, Male]                        |
| `sum`    | `Int64`  | Total of all genders in all ages (females multiplied by -1) |
"""
function population_pyramid(batchProcessor::BatchProcessor)

    res = Dict{String, DataFrame}()

    for rd in batchProcessor |> rundata

        pf = rd |> population_file

        if !haskey(res, pf)
            res[pf] = rd |> population_pyramid
        end
    end

    return(res)
end

"""
    tick_cases(batchProcessor::BatchProcessor)

Returns newly exposed inviduals per tick accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function tick_cases(batchProcessor::BatchProcessor)

    # extract tick cases from each simulation run
    data = map(
        x -> tick_cases(x) |>
            x -> DataFrames.select(x, :tick, :exposed_cnt),
        batchProcessor |> rundata
    )

    # return aggregated valules
    return(
        data
    )
end

"""
    effectiveR(batchProcessor::BatchProcessor)

Returns the effective R value for each tick accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function effectiveR(batchProcessor::BatchProcessor)

    # extract effective R from each simulation run
    data = map(
        x -> effectiveR(x) |>
            x -> DataFrames.select(x, :tick, :effective_R),
        batchProcessor |> rundata
    )

    # return aggregated valules
    return data
end


"""
    tests(batchProcessor::BatchProcessor)

Returns newly exposed inviduals per tick accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function tests(batchProcessor::BatchProcessor)
    res = Dict{String, Vector{DataFrame}}()
    # extract tick cases from each simulation run

    for rd in batchProcessor |> rundata
        for (test_name, test_df) in (rd |> tick_tests)
            if haskey(res, test_name)
                push!(res[test_name], test_df)
            else
                res[test_name] = [test_df]
            end
        end
    end
    # return aggregated valules
    return(res)
end

"""
    cumulative_quarantines(batchProcessor::BatchProcessor)

Returns cumulative quarantines per tick accross the simulation runs in this batch.
"""
function cumulative_quarantines(batchProcessor::BatchProcessor)
    # extract quarantines from each simulation run
    data = map(
        x -> cumulative_quarantines(x) |>
            x -> DataFrames.select(x, :tick, :quarantined),
        batchProcessor |> rundata
    )

    # return aggregated valules
    return data
end

"""
    cumulative_disease_progressions(batchProcessor::BatchProcessor)

Returns cumulative quarantines per tick accross the simulation runs in this batch.
"""
function cumulative_disease_progressions(batchProcessor::BatchProcessor)
    # extract quarantines from each simulation run
    data = map(
        x -> cumulative_disease_progressions(x),
        batchProcessor |> rundata
    )

    # return aggregated valules
    return data
end

###
### PRINTING
###

function Base.show(io::IO, batchProcessor::BatchProcessor)
    write(io, "Batch Processor ($(batchProcessor.rundata |> length) runs)")
end