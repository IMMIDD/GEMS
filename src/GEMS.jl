module GEMS
 
    ### IMPORTS
    using CategoricalArrays
    using ContentHashes
    using CpuId
    using CSV
    using DataFrames
    using DataStructures
    using Dates
    using DelimitedFiles
    using Distributions
    using FileIO
    using Format
    import GMT # "import" GMT to prevent namespace conflicts with Plots package. (plot, scatter, etc...)
    using ImageIO
    using InteractiveUtils
    using JLD2
    using JSON
    using LoggingExtras
    using Optimization
    using OptimizationCMAEvolutionStrategy
    using PkgVersion
    using Parameters
    using Plots
    using PrettyTables
    using ProgressBars
    using Random
    using RollingFunctions
    using Shapefile
    using Statistics
    using StatsBase
    using StatsPlots
    using Suppressor
    using TimerOutputs
    using TOML
    using UrlDownload
    using UUIDs
    using VegaLite
    using VideoIO
    using Weave
    using ZipFile

    ### INCLUDES

    # INFRASTRUCTURE
    include("constants.jl")
    include("globals.jl")
    include("utils.jl")
    include("exceptions.jl")
    include("logger/Logger.jl")

    # INTERVENTION ABSTRACTS
    include("interventions/abstract_structs.jl")
    include("interventions/event_queue.jl")

    # CORE SIMULATION - TYPE DEFINITIONS 
    include("pathogen/disease_progression.jl")
    include("registries/infection_registry.jl") 
    include("registries/immunity_registry.jl") 
    include("registries/test_registry.jl")
    include("pathogen/pathogens.jl") 
    include("pathogen/vaccines.jl")
    include("population/age_groups.jl")
    include("settings/ags.jl")
    include("contacts/contact_matrix.jl")
    include("contacts/contact_sampling.jl")
    include("population/individuals.jl")
    include("population/populations.jl")
    include("settings/settings.jl") 
    include("settings/settingscontainers.jl")
    include("simulation/simulation.jl")
    include("registries/registry_iterators.jl")
    include("simulation/batch.jl")

    # CORE SIMULATION - METHODS
    include("rng.jl")
    include("infections/infections.jl")
    include("simulation/simulation_methods.jl")
    include("settings/setting_methods.jl")
    include("contacts/contact_sampling_methods.jl")
    include("contacts/contact_matrix_methods.jl")
    include("simulation/batch_methods.jl")
    include("simulation/calibration.jl")
    include("registries/registry_methods.jl")

    # PATHOGEN IMPLEMENTATIONS
    include("pathogen/pathogen_components.jl")

    # INITALIZATION
    include("initialization/startconditions.jl")

    # TERMINATION
    include("termination/stopcriteria.jl")

    # INTERVENTIONS
    include("interventions/interventions.jl")

    # ANALYSIS
    include("analysis/post_processing.jl")
    include("analysis/result_data.jl")
    include("analysis/batch_processing.jl")
    include("analysis/batch_data.jl")
    include("analysis/contact_structure_analysis/contact_survey.jl")
    include("analysis/contact_structure_analysis/contact_distributions.jl")
    include("analysis/contact_structure_analysis/contact_distribution_plots.jl")

    # REPORTING
    include("reporting/reports.jl")
    include("reporting/movie/movie_renderer.jl")

    # etc
    include("init.jl")
    include("main.jl")
    include("devTools.jl")
    include("runinfo.jl")

    function __init__()
        # Initialize thread-local RNGs
        append!(_DEFAULT_GEMS_RNGS, [Random.Xoshiro() for _ in 1:Threads.maxthreadid()])

        offending_lines = check_naked_rng_calls()

        if !isempty(offending_lines)
            warning_message = """
            The code might contain calls to RNG functions (e.g., rand(), randn(), sample()) that are not using
            the simulation's RNG instance. This can lead to non-reproducible results.
            GEMS offers utility functions that accept an RNG instance or the simulation
            object as an argument. You can simply replace calls like `rand(...)` with
            `gems_rand(rng, ...)` or `gems_rand(sim, ...)` where `sim` is your simulation object.
            The simulation's RNG instance itself can be accessed via `rng(sim)`.

            Please modify the following lines to use the provided RNG instance:
            """
            for (filepath, line_num, content) in offending_lines
                warning_message *= "- $filepath:$line_num`: `$content`\n"
            end
            @warn warning_message
        end
    end
end