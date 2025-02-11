export DefaultBatchData

"""
    DefaultBatchData <: BatchDataStyle

The default style for `BatchData` objects. It contains all that can currently
be calculated in the `BatchProcessor` and all `ResultData` objects of the 
individual runs.

# Fields

- `data::Dict{String, Any}`
    - `meta_data::Dict{String, Any}`
        - `execution_date::String`: Time this BatchData object was generated
        - `GEMS_version::VersionNumber`: GEMS version this BatchData object was generated with 

    - `system_data::Dict{String, Any}`
        - `kernel::String`: System kernel
        - `julia_version::String`: Julia version that was used to generate this data object
        - `word_size::Int64`: System word size
        - `threads::Int64`: Number of threads this Julia instance was started with
        - `cpu_data::Markdown.MD`: Information on the processor (not available for ARM Macs)
        - `total_mem_size::Float64`: Total system memory
        - `free_mem_size::Float64`: Available system memory
        - `git_repo::SubString{String}`: Current Git repository
        - `git_branch::SubString{String}`: Current Git branch
        - `git_commit::SubString{String}`: Current Git commit ID

    - `sim_data::Dict{String, Any}`
        - `runs::Vector{ResultData}`: ResultData objects of individual simulation runs runs
        - `number_of_runs::Int64`: Number of simulation runs
        - `total_infections::Dict{String, Real}`: Summary statistics on total infections across simulation runs
        - `attack_rate::Dict{String, Real}`: Summary statistics on attack rates across simulation runs
        - `total_quarantines::Dict{String, Real}`: Summary statistics on total quarantines across simulation runs
        - `total_tests::Dict{String, Real}`: Summary statistics on total tests across simulation runs
        
    - `dataframes::Dict{String, Any}`
        - `tick_cases::Dataframe`: Aggregated data on infections per tick across simulation runs
        - `effectiveR::Dataframe`: Aggregated data on the effective reproduction number per tick across simulation runs
        - `tests::Dataframe`: Aggregated data on tests per tick across simulation runs
        - `cumulative_quarantines::Dataframe`: Aggregated data on cumulative quarantines per tick across simulation runs
        - `cumulative_disease_progressions::Dataframe`: Aggregated data on cumulative disease progressions per tick across simulation runs
"""
mutable struct DefaultBatchData <: BatchDataStyle

    # internal data container
    data::Dict{String, Any}

    function DefaultBatchData(bP::BatchProcessor)
        funcs = Dict(
            # any non-simulation-related data
            "meta_data" =>
                Dict(
                    "execution_date" => () -> Dates.format(now(), "U dd, yyyy - HH:MM"),
                    "GEMS_version" => () -> PkgVersion.Version(GEMS)
                ),

            # system data
            "system_data" =>
                Dict(
                    "kernel" => () -> String(Base.Sys.KERNEL) * String(Base.Sys.MACHINE),
                    "julia_version" => () -> string(Base.VERSION),
                    "word_size" => () -> Base.Sys.WORD_SIZE,
                    "threads" => () -> Threads.nthreads(),
                    "cpu_data" => () -> cpudata(),
                    "total_mem_size" => () -> round(Sys.total_memory()/2^20, digits = 2),
                    "free_mem_size" => () -> round(Sys.free_memory()/2^20, digits = 2),
                    "git_repo" => () -> read_git_repo(),
                    "git_branch" => () -> read_git_branch(),
                    "git_commit" => () -> read_git_commit(),
                ),

            # aggregated data on simulations
            "sim_data" =>
                Dict(
                    "runs" => () -> bP |> rundata, # result data objects of individual runs
                    "number_of_runs" => () -> bP |> rundata |> length,
                    "total_infections" => () -> bP |> total_infections |> aggregate_values,
                    "attack_rate" => () -> bP |> attack_rate |> aggregate_values,
                    "total_quarantines" => () -> bP |> total_quarantines |> aggregate_values,
                    "total_tests" => () -> bP |> total_tests |> aggregate_dicts,
                ),

            # aggregated output data
            "dataframes" =>
                Dict(
                    "tick_cases" => () -> aggregate_dfs(tick_cases(bP), :tick),
                    "effectiveR" => () -> aggregate_dfs(effectiveR(bP), :tick),
                    "tests" => () -> Dict(k => aggregate_dfs_multcol(v, :tick) for (k, v) in tests(bP)),
                    "cumulative_quarantines" => () -> aggregate_dfs(cumulative_quarantines(bP), :tick),
                    "cumulative_disease_progressions" => () -> aggregate_dfs_multcol(cumulative_disease_progressions(bP), :tick),   
                )
        )

        # call all provided functions and replace
        # the dicts with their return values
        return(
            new(process_funcs(funcs))
        )
    end
end