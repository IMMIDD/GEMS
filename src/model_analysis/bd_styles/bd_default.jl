export DefaultBatchData

"""
    DefaultBatchData <: BatchDataStyle

The default style for `BatchData` objects. It contains all that can currently
be calculated from a `BatchProcessor`.

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
        - `runs::Union{Nothing, Vector{ResultData}}`: Individual ResultData objects, or
          `nothing` if `keep_rundata` was `false` during the batch run
        - `median_run::Union{Nothing, ResultData}`: The run whose criterion is closest to
          the median across all runs, or `nothing` if `median_by` was not set
        - `number_of_runs::Int64`: Number of simulation runs
        - `total_infections::Dict{String, Real}`: Summary statistics on total infections across simulation runs
        - `attack_rate::Dict{String, Real}`: Summary statistics on attack rates across simulation runs
        - `r0::Dict{String, Real}`: Summary statistics on the basic reproduction number (R0)
        - `total_quarantines::Dict{String, Real}`: Summary statistics on total quarantines across simulation runs
        - `total_tests::Dict{String, Dict{String, Real}}`: Summary statistics on total tests per TestType

    - `dataframes::Dict{String, Any}`
        - `tick_cases::DataFrame`: Aggregated data on infections per tick across simulation runs
        - `effectiveR::DataFrame`: Aggregated data on the effective reproduction number per tick across simulation runs
        - `tests::Dict{String, Dict{String, DataFrame}}`: Aggregated data on tests per tick across simulation runs
        - `cumulative_quarantines::DataFrame`: Aggregated data on cumulative quarantines per tick across simulation runs
        - `cumulative_disease_progressions::Dict{String, DataFrame}`: Aggregated data on cumulative disease progressions per tick across simulation runs
"""
mutable struct DefaultBatchData <: BatchDataStyle

    data::Dict{String, Any}

    function DefaultBatchData(bP::BatchProcessor)
        funcs = Dict(
            "meta_data" =>
                Dict(
                    "execution_date" => () -> Dates.format(now(), "U dd, yyyy - HH:MM"),
                    "GEMS_version" => () -> PkgVersion.Version(GEMS)
                ),

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

            "sim_data" =>
                Dict(
                    "runs" => () -> rundata(bP),
                    "median_run" => () -> median_run(bP),
                    "number_of_runs" => () -> n_runs(bP),
                    "tick_unit" => () -> tick_unit(bP),
                    "seed" => () -> seed(bP),
                    "total_infections" => () -> total_infections(bP),
                    "attack_rate" => () -> attack_rate(bP),
                    "r0" => () -> r0(bP),
                    "total_quarantines" => () -> total_quarantines(bP),
                    "total_tests" => () -> total_tests(bP),
                    "total_detected_cases" => () -> total_detected_cases(bP),
                    "detection_rate" => () -> detection_rate(bP),
                ),

            "dataframes" =>
                Dict(
                    "tick_cases" => () -> tick_cases(bP),
                    "effectiveR" => () -> effectiveR(bP),
                    "tests" => () -> tests(bP),
                    "pool_tests" => () -> pool_tests(bP),
                    "sero_tests" => () -> sero_tests(bP),
                    "cumulative_quarantines" => () -> cumulative_quarantines(bP),
                    "cumulative_disease_progressions" => () -> cumulative_disease_progressions(bP),
                    "dark_figure" => () -> dark_figure(bP),
                    "cumulative_cases" => () -> cumulative_cases(bP),
                    "generation_times" => () -> generation_times(bP),
                    "hospitalizations" => () -> hospitalizations(bP),
                    "observed_R" => () -> observed_R(bP),
                ),
            "per_label" => () -> Dict(
                lab => BatchData(lbp)
                for (lab, lbp) in bP.per_label
            )
        )

        return new(process_funcs(funcs))
    end
end
