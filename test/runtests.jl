using GEMS
using Test

using CSV
using CategoricalArrays
using DataFrames
using DataStructures: OrderedSet
using Dates
using Distributions
using FileIO: load # has the function filename which clashes with GEMS
using InteractiveUtils
using JLD2
using Logging
using Plots
using Random
using TimerOutputs
using TOML
using Parameters
using StatsBase

@testset "GEMS" begin
    testfiles = [
        "agentstest.jl",
        "populationstest.jl",
        "pathogentest.jl",
        "diseaseprogressiontest.jl",
        "settingstest.jl",
        "simulationtest.jl",
        "infectionstest.jl",
        "reportingtest.jl",
        "loggertest.jl",
        "postprocessortest.jl",
        "resultdatatest.jl",
        "batchtest.jl",
        "utilstest.jl",
        "contactsamplingtest.jl",
        "contactmatrixtest.jl",
        "interventionstest.jl",
        "codevalidationtest.jl"
    ]

    println("Begin to run test cases.")
    
    # Logging.AboveMaxLevel is a LogLevel above Logging.Debug. This essentially means that no log messages, except those from failing test cases and compilation errors will be printed!
    with_logger(ConsoleLogger(stderr, Logging.AboveMaxLevel)) do
        for file in testfiles
            # print current running file without LogLevel, so that it isn't surpressed. This should inform the user, that the tests are still running.
            println("Running $file")
            include(file)
        end
    end
    return # prevents output of ran test sets
end
