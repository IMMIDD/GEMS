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
using Formatting
import GMT # "import" GMT to prevent namespace conflicts with Plots package. (plot, scatter, etc...)
using ImageIO
using InteractiveUtils
using JLD2
using JSON
using LoggingExtras
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
include("constants.jl")
include("globals.jl")
include("utils.jl")
include("exceptions.jl")
include("logger/Logger.jl")
include("interventions/abstract_structs.jl")
include("interventions/event_queue.jl")

include("structs.jl") # CORE SIMULATION
include("methods.jl") # CORE SIMULATION

include("interventions/interventions.jl")
include("model_analysis/post_processing.jl")
include("model_analysis/result_data.jl")
include("model_analysis/batch_processing.jl")
include("model_analysis/batch_data.jl")
include("model_analysis/contact_structure_analysis/contact_survey.jl")
include("model_analysis/contact_structure_analysis/contact_distributions.jl")
include("model_analysis/contact_structure_analysis/contact_distribution_plots.jl")
include("reporting/reports.jl")
include("movie/movie_renderer.jl")

include("main.jl")

include("devTools.jl")

include("runinfo.jl")
end