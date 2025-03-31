export TestPositiveRate

###
### STRUCT
###

"""
    TestPositiveRate <: SimulationPlot

A simulation plot type for generating a tests-positive-rate-per-tick plot.
"""
@with_kw mutable struct TestPositiveRate <: SimulationPlot

    title::String = "Test Positive Rate per Tick" # default title
    description::String = "" # default description empty
    filename::String = "test_positive_rate_per_tick.png" # default filename

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
    generate(plt::TestPositiveRate, rd::ResultData; plotargs...)

Generates and returns a tests-positive-rate-per-tick plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TestPositiveRate`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Test Positive Rate plot
"""
function generate(plt::TestPositiveRate, rd::ResultData; dates::Bool = true,  plotargs...)

    # return empty plot with message, if result data does not contain tests
    if rd |> tick_tests |> isempty
        plot_tests = emptyplot("There are no Tests available in the ResultData object")
        plot!(plot_tests; plotargs...)
        return(plot_tests)
    end
    
    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # update title
    title!(plt, "Test Positive Rate per $upper_ticks")

    # add description
    desc = "This graph shows the fraction of positive test results per $uticks for each TestType[^testtype]."
    desc *= "\n\n[^testtype]: A TestType defines the kind of test being performed (e.g. PCR, Antigen, etc...) and its associated parameters (such as sensitivity). "
    desc *= "The visualized data is a 7-$uticks rolling average."
    description!(plt, desc) 

    # update filename
    filename!(plt, "test_positive_rate_per_$uticks.png")

    yformatter = y -> string(round(y * 100, digits=1), "%") # format y-axis to show percentages

    plot_tests = plot(xlabel = upper_ticks * "s", ylabel = "Test Positive Rate", fontfamily = "Times Roman", ylims = (0, 1))
    for (key, df) in pairs(rd |> tick_tests)
        plot!(plot_tests, df.tick, df.rolling_positive_rate, label="$key Positive Rate", yformatter=yformatter)
    end

    # add custom arguments that were passed
    plot!(plot_tests; plotargs...)

    # replace x-ticks with dates
    dates ? adddates!(plot_tests, rd) : nothing

    return(plot_tests)
end