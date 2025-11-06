# DATA TYPE AND FUNCTIONALIYT FOR BATCH RUNS. ANALOGOUS TO RESULTDATA
export BatchData
export BatchDataStyle

export merge
export meta_data, execution_date, GEMS_version, id
export runtime, allocations
export system_data, kernel, julia_version, word_size, threads, cpu_data, total_mem_size, free_mem_size, git_repo, git_branch, git_commit
export sim_data, runs, number_of_runs, total_infections, total_tests, attack_rate, total_quarantines
export dataframes, tick_cases, effectiveR, tests, cumulative_quarantines, cumulative_disease_progressions

export exportJLD, exportJSON, import_batchdata, info


abstract type BatchDataStyle end

###
### INCLUDE BATCH DATA STYLES
###

# The src/model_analysis/bd_styles folder contains a dedicated file
# for each BatchDataStyle.
# If you want to set up a new style, simply add a file to the folder and 
# make sure to define the respective struct there and export it (using the export statement).

# include all Julia files from the "rd_styles"-folder
dir = basefolder() * "/src/model_analysis/bd_styles"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)

###
### BATCH DATA STRUCT
###



"""
    BatchData <: AbstractResultData

A struct that stores all processed data of a batch of simulation runs.
It holds four internal dictionaries with meta-, simulation-, system- and data
as well as multiple DataFrames that are the BatchProcessor outcomes.
Note that some information (i.e., execution date or GEMS version) is only read
out upon generation of this BatchData object. Thus, there can be inconsistencies
if the BatchData object is not generated right after simulation execution.
"""
mutable struct BatchData <: AbstractResultData
    data:: Dict{String, Any}

    @doc """

        BatchData(batchProcessor::BatchProcessor; style::String = "DefaultBatchData")

    Create a `BatchData` object using a `BatchProcessor` and a `style`, that defines
    which calculations should be done. Post Processing requires a simulation to be done.
    """
    function BatchData(batchProcessor::BatchProcessor; style::String = "DefaultBatchData")
        # Determine the style to be used
        id = findfirst(x -> occursin(style, x), string.(concrete_subtypes(BatchDataStyle)))
        if isnothing(id)
            @warn "The provided style $style was not found. The `DefaultBatchDataStyle` will be used!"
            id = findfirst(x -> occursin("DefaultBatchData", x), string.(concrete_subtypes(BatchDataStyle)))
        end

        # get style
        style = concrete_subtypes(BatchDataStyle)[id](batchProcessor)

        # Use the data to create the ResultData struct
        bd = new(style.data)

        # add unique ID
        if !haskey(bd.data, "meta_data")
            bd.data["meta_data"] = Dict()
        end
        
        bd.data["meta_data"]["id"] = uuid4() |> string

        return(bd)
    end

    @doc """

        BatchData(batch::Batch; style::String = "DefaultBatchData", rd_style = "LightRD")

    Create a `BatchData` object using a `Batch` and a `style`, that defines
    which calculations should be done during batch processing. As the provided `batch`
    has unprocessed simulation runs inside, this function also triggers post processing
    for the individual simulation runs. The `rd_style` argument defines the calculations
    that should be done during post processing of the individual runs.
    Post processing requires a simulation to be done.
    """
    BatchData(batch::Batch; style::String = "DefaultBatchData", rd_style = "LightRD") =
        BatchData(BatchProcessor(batch, rd_style = rd_style), style = style)

    @doc """

        BatchData(rds::Vector{ResultData}; style::String = "DefaultBatchData")

    Create a `BatchData` object using a vector of `ResultData` objects and a `style`, that defines
    which calculations should be done during batch processing.
    """
    BatchData(rds::Vector{ResultData}; style::String = "DefaultBatchData") = 
        BatchData(BatchProcessor(rds), style = style)

    @doc """

        BatchData(bds::BatchData...; style::String = "DefaultBatchData")

    Calls the `merge()` function for the input `BatchData` objects.
    """ 
    BatchData(bds::BatchData...; style::String = "DefaultBatchData") =
        merge(bds..., style = style)

    @doc """

        BatchData(bds::Vector{BatchData}; style::String = "DefaultBatchData")

    Calls the `merge()` function for the input vector of `BatchData` objects.
    """ 
    BatchData(bds::Vector{BatchData}; style::String = "DefaultBatchData") =
        BatchData(bds...; style = style)
end

"""
    merge(bds::BatchData...; style::String = "DefaultBatchData")
    merge(bds::Vector{BatchData}; style::String = "DefaultBatchData")

Generates a new `BatchData` object from the union of all `ResultData` objects
out of all the passed `BatchData` objects. Naturally, this requires the
input `BatchData` objects to have internal `ResultData` objects.
This requirement is met if the default style (`DefaultBatchData`) was used
during the creation of the input objects. Simply: If you didn't apply
any custom style, this should work.

# Returns

- `BatchData`: (New) combined `BatchData` object with all internal `ResultData` objects
"""
function Base.merge(bds::BatchData...; style::String = "DefaultBatchData")

    rds = ResultData[]
    for bd in bds
        isempty(runs(bd)) ? throw("Not all passed BatchData objects have the individual simulation runs stored (ResultData). Merging BatchData objects effectively generates a new BatchData object from the internal ResultData objects (therefore they must be passed).") : nothing
        append!(rds, runs(bd))
    end

    return BatchData(rds, style = style)
end

Base.merge(bds::Vector{BatchData}; style::String = "DefaultBatchData") = merge(bds...; style = style)


###
### Meta Data
###

"""
    meta_data(bd::BatchData)

Returns the metadata dict of the batch data object.
"""
function meta_data(bd::BatchData)
    get(bd.data, "meta_data", Dict())
end
"""
    execution_date(bd::BatchData)

Returns the timestamp of batch data generation.
"""
function execution_date(bd::BatchData)
    return(get(bd |> meta_data, "execution_date", ""))
end

"""
    GEMS_version(bd::BatchData)

Returns the GEMS version this BatchData object was generated with. 
"""
function GEMS_version(bd::BatchData)
    return(get(bd |> meta_data, "GEMS_version", ""))
end


"""
    runtime(bd::BatchData)

Returns runtime data of the simulation runs in this batch.
(*Note*: This data is only available if the simulation runs were done via the `main()` function)
"""
function runtime(bd::BatchData)
    return(get(bd |> meta_data, "runtime", ""))
end


"""
    allocations(bd::BatchData)

Returns allocation data of the simulation runs in this batch.
(*Note*: This data is only available if the simulation runs were done via the `main()` function)
"""
function allocations(bd::BatchData)
    return(get(bd |> meta_data, "allocations", ""))
end


"""
    id(bd::BatchData)

Returns the stringified SHA1 hash that serves as a unique identifier.
"""
function id(bd::BatchData)
    return(get(bd |> meta_data, "id", ""))
end

###
### System Data
###
"""
    system_data(bd::BatchData)

Returns the systemdata dict of the batch data object.
"""
function system_data(bd::BatchData)
    get(bd.data, "system_data", Dict())
end


"""
    kernel(bd::BatchData)

Returns the system kernel information
"""
function kernel(bd::BatchData)
    return(get(bd |> system_data, "kernel", ""))
end

"""
    julia_version(bd::BatchData)

Returns the Julia version that was used to generate this result data object.
"""
function julia_version(bd::BatchData)
    return(get(bd |> system_data, "julia_version", ""))
end

"""
    word_size(bd::BatchData)

Returns the system word size
"""
function word_size(bd::BatchData)
    return(get(bd |> system_data, "word_size", ""))
end

"""
    threads(bd::BatchData)

Returns the number of threads this Julia instance was started with
"""
function threads(bd::BatchData)
    return(get(bd |> system_data, "threads", ""))
end

"""
    cpu_data(bd::BatchData)

Returns the processor information (not available for ARM Macs)
"""
function cpu_data(bd::BatchData)
    return(get(bd |> system_data, "cpu_data", ""))
end

"""
    total_mem_size(bd::BatchData)

Returns the total system memory
"""
function total_mem_size(bd::BatchData)
    return(get(bd |> system_data, "total_mem_size", ""))
end

"""
    free_mem_size(bd::BatchData)

Returns the available system memory
"""
function free_mem_size(bd::BatchData)
    return(get(bd |> system_data, "free_mem_size", ""))
end

"""
    git_repo(bd::BatchData)

Returns the current git repository.
"""
function git_repo(bd::BatchData)
    return(get(bd |> system_data, "git_repo", ""))
end

"""
    git_branch(bd::BatchData)

Returns the current git branch.
"""
function git_branch(bd::BatchData)
    return(get(bd |> system_data, "git_branch", ""))
end


"""
    git_commit(bd::BatchData)

Returns the current git commit.
"""
function git_commit(bd::BatchData)
    return(get(bd |> system_data, "git_commit", ""))
end



###
### Sim Data
###

"""
    sim_data(bd::BatchData)

Returns the simdata dict of the batch data object.
"""
function sim_data(bd::BatchData)
    get(bd.data, "sim_data", Dict())
end


"""
    runs(bd::BatchData)

Returns the `ResultData` objects of each of the runs in the the batch data object.
"""
function runs(bd::BatchData)
    get(bd |> sim_data, "runs", Dict())
end

"""
    number_of_runs(bd::BatchData)

Returns the number of runs in this batch.
"""
function number_of_runs(bd::BatchData)
    return(get(bd |> sim_data, "number_of_runs", ""))
end

"""
    total_infections(bd::BatchData)

Returns aggregated values for `total_infections` accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function total_infections(bd::BatchData)
    return(get(bd |> sim_data, "total_infections", ""))
end


"""
    total_tests(bd::BatchData)

Returns aggregated values for `total_tests` accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function total_tests(bd::BatchData)
    return(get(bd |> sim_data, "total_tests", ""))
end

"""
    attack_rate(bd::BatchData)

Returns aggregated values for the `attack_rate` accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function attack_rate(bd::BatchData)
    return(get(bd |> sim_data, "attack_rate", ""))
end

"""
    r0(bd::BatchData)

Returns aggregated values for the basic reproduction number`r0` accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function r0(bd::BatchData)
    return(get(bd |> sim_data, "r0", ""))
end

"""
    total_quarantines(batchData)

Returns aggregated values for `total_quarantines` accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function total_quarantines(bd::BatchData)
    return(get(bd |> sim_data, "total_quarantines", ""))
end



###
### Data Frames
###
"""
    dataframes(batchData)

Returns the dataframes dict of the batch data object.
"""
function dataframes(bd::BatchData)
    get(bd.data, "dataframes", Dict())
end

"""
    tick_cases(bd::BatchData)

Returns aggregated values for newly exposed inviduals per tick accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function tick_cases(bd::BatchData)
    return(get(bd |> dataframes, "tick_cases", DataFrame()))
end

"""
    effectiveR(bd::BatchData)

Returns aggregated values for the effective R value for each tick accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function effectiveR(bd::BatchData)
    return(get(bd |> dataframes, "effectiveR", DataFrame()))
end

"""
    tests(bd::BatchData)

Returns aggregated values for tests per tick accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function tests(bd::BatchData)
    return(get(bd |> dataframes, "tests", DataFrame()))
end

"""
    cumulative_quarantines(bd::BatchData)

Returns aggregated values cumulative_quarantines per tick accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function cumulative_quarantines(bd::BatchData)
    return(get(bd |> dataframes, "cumulative_quarantines", DataFrame()))
end

"""
    cumulative_disease_progressions(bd::BatchData)

Returns aggregated values for cumulative_disease_progressions per tick accross the simulation runs in this batch.
It returns mean, standard deviation, range, and confidence intervals.
"""
function cumulative_disease_progressions(bd::BatchData)
    return(get(bd |> dataframes, "cumulative_disease_progressions", DataFrame()))
end


###
### Export FUNCTIONS
###

"""
    exportJLD(batchData, directory)

Exports the `BatchData` object as a JLD2 file, storing it in the specified `directory`.
"""
function exportJLD(bd::BatchData, directory::AbstractString)
    mkpath(directory)
    jldsave(joinpath(directory, "batchdata.jld2"); bd)
end

"""
    exportJSON(batchData, directory)

Exports the `BatchData` object as a JSON file, storing it in the specified `directory`.
All DataFrames are excluded from the JSON export.
This feature is only available in the JLD2-export.
In that case, please use `exportJLD(resultData, directory)` 
"""
function exportJSON(bd::BatchData, directory::AbstractString)
    out = deepcopy(bd.data)
    clean_result!(out)

    # Manually remove cpu data
    delete!(get(out, "system_data", Dict()), "cpu_data")

    # Transform hashes
    haskey(out, "hash") ? out["hash"] = out["hash"] |> string : nothing

    mkpath(directory)
    open(joinpath(directory, "batchdata.json"), "w") do file
        write(file, JSON.json(out))
    end
end

"""
    import_batchdata(filepath::AbstractString)

Import the BatchData object from a jld2 file. Returns the BatchData object.
"""
function import_batchdata(filepath::AbstractString)
    if !isfile(filepath) || split(filepath, ".")[end] != "jld2"
        error("The provided path does not point to a jld2 file!")
    end
    # Load the file and check if it is actually a BatchData object 
    bd = get(load(filepath), "bd", Dict())
    if !isa(bd, BatchData)
        error("The provided file is not a valid BatchData object!")
    end
    return bd
end


###
### PRINTING
###

"""
    info(bd::BatchData)

Prints info about available fields in the `BatchData` object.
"""
function info(bd::BatchData)
    println("BatchData Entries")
    for (category, data) in bd.data
        println("\u2514 $category")
        for (label, value) in data
            println("  \u2514 $label")
        end
    end
end

function Base.show(io::IO, bd::BatchData)
    
    infs = total_infections(bd)
    attr = attack_rate(bd)
    r0vals = r0(bd)
    quar = total_quarantines(bd)
    
    lines = [
        () -> "BatchData Object"
        () -> "\u2514 Dataframes inside: $(bd.data["dataframes"] |> length)"
        () -> "\u2514 Simulation:"
        () -> "  \u2514 Total infections: $(round(infs["mean"], digits = 2)) ($(round(infs["lower_95"], digits = 2)) - $(round(infs["upper_95"], digits = 2)) 95% CI)"
        () -> "  \u2514 Attack rate: $(round(attr["mean"], digits = 2)) ($(round(attr["lower_95"], digits = 2)) - $(round(attr["upper_95"], digits = 2)) 95% CI)"
        () -> "  \u2514 Basic reproduction number (R0): $(round(r0vals["mean"], digits = 2)) ($(round(r0vals["lower_95"], digits = 2)) - $(round(r0vals["upper_95"], digits = 2)) 95% CI)"
        () -> "  \u2514 Total quarantine days: $(round(quar["mean"], digits = 2)) ($(round(quar["lower_95"], digits = 2)) - $(round(quar["upper_95"], digits = 2)) 95% CI)"
    ]

    for l in lines
        try println(io, l()) catch end
    end
        
end
