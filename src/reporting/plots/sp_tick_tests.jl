export TickTests

###
### STRUCT
###

"""
    TickTests <: SimulationPlot

A simulation plot type for generating a new-tests-per-tick plot.
"""
@with_kw mutable struct TickTests <: SimulationPlot

    title::String = "Tests per Tick" # default title
    description::String = "" # default description empty
    filename::String = "tests_per_tick.png" # default filename

    # indicates to which package the result plot belongs
    # is used to parallelize report generation and prevents
    # concurrent generation of plots coming from the same package
    # if you don't know the origin package or if the function
    # returns different plot types depending on the input, 
    # just put ":other" which will trigger sequential generation
    package::Symbol = :Plots
    
end

###
### PLOT GENERATION
###

"""
    generate(plt::TickTests, rd::ResultData; plotargs...)

Generates and returns a tests-per-tick plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TickTests`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Tick Tests plot
"""
function generate(plt::TickTests, rd::ResultData; plotargs...)

    # return empty plot with message, if result data does not contain tests
    if rd |> tick_tests |> isempty
        plot_tests = emptyplot("There are no Tests available in the ResultData object")
        plot!(plot_tests; plotargs...)
        return(plot_tests)
    end

    cases = rd |> tick_cases
    
    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    total_tests = Dict(key => sum(value.total_tests) for (key, value) in rd |> tick_tests)


    # update title
    title!(plt, "Tests per $upper_ticks")

    # add description
    desc = "This graph shows the overall number of performed tests per TestType[^testtype] (_Total Tests_). "
    desc *= "The _Positive Tests_ series shows the total number of tests with a positive result. "
    desc *= "Note that this may also include false positives depending on the TestType's parameterization. "
    desc *= "The _Reported Cases_ series counts the number of newly detected cases (by means of testing) at any given $uticks. "
    desc *= "_New Cases_ is the number of newly exposed individuals at any given $uticks. "
    
    for (testname, testcount) in total_tests
        desc *= "A total of $(format(testcount, commas = true)) tests were taken with _$(testname)_. "
    end
    
    desc *= "\n\n[^testtype]: A TestType defines the kind of test being performed (e.g. PCR, Antigen, etc...) and its associated parameters (such as sensitivity)"
    description!(plt, desc) 

    # update filename
    filename!(plt, "tests_per_$uticks.png")

    linestyles = [:solid, :dash, :dot, :dashdot, :dashdotdot]
    plot_tests = plot(cases.tick, cases.exposed_cnt, color = :red, label="New Cases", xlabel = upper_ticks * "s", ylabel = "Count", fontfamily = "Times Roman")
    i = 1
    for (key, df) in pairs(rd |> tick_tests)
        plot!(plot_tests, df.tick, df.positive_tests, linestyle=linestyles[i], color = :green, label="Positive Tests $key")
        plot!(plot_tests, df.tick, df.total_tests, linestyle=linestyles[i], color = :blue, label="Total Tests $key")
        plot!(plot_tests, df.tick, df.reported_cases, linestyle=linestyles[i], color = :violet, label="Reported Cases $key")
        i+=1
    end

    # add custom arguments that were passed
    plot!(plot_tests; plotargs...)

    return(plot_tests)
end