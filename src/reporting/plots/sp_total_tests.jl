export TotalTests

###
### STRUCT
###

"""
    TotalTests <: SimulationPlot

A simulation plot type for generating a total-tests-per-tick plot.
"""
@with_kw mutable struct TotalTests <: SimulationPlot

    title::String = "Total Tests per Tick" # default title
    description::String = "" # default description empty
    filename::String = "total_tests_per_tick.png" # default filename

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
    generate(plt::TotalTests, rd::ResultData; plotargs...)

Generates and returns a total-tests-per-tick plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TotalTests`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Total Tests plot
"""
function generate(plt::TotalTests, rd::ResultData; plotargs...)

    # return empty plot with message, if result data does not contain tests
    if rd |> tick_tests |> isempty
        plot_tests = emptyplot("There are no Tests available in the ResultData object")
        plot!(plot_tests; plotargs...)
        return(plot_tests)
    end
    
    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    total_tests = Dict(key => sum(value.total_tests) for (key, value) in rd |> tick_tests)


    # update title
    title!(plt, "Total Tests per $upper_ticks")

    # add description
    desc = "This graph shows the overall number of performed tests per TestType[^testtype]. "

    
    for (testname, testcount) in total_tests
        desc *= "A total of $(format(testcount, commas = true)) tests were taken with _$(testname)_. "
    end
    
    desc *= "\n\n[^testtype]: A TestType defines the kind of test being performed (e.g. PCR, Antigen, etc...) and its associated parameters (such as sensitivity)"
    description!(plt, desc) 

    # update filename
    filename!(plt, "total_tests_per_$uticks.png")

    plot_tests = plot(xlabel = upper_ticks * "s", ylabel = "Count", fontfamily = "Times Roman")
    for (key, df) in pairs(rd |> tick_tests)
        plot!(plot_tests, df.tick, df.total_tests, label="Total Tests $key")
    end

    # add custom arguments that were passed
    plot!(plot_tests; plotargs...)

    return(plot_tests)
end

"""
    generate(plt::TotalTests, rds::Vector{ResultData}; plotargs...)

Generates and returns a total tests plot for a provided vector of `ResultData` objects.
It will contain one individual plot per test type available in the `ResultData` object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TotalTests`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Total Tests multi plot
"""
function generate(plt::TotalTests, rds::Vector{ResultData}; plotargs...)

    # get all tests types available in any of the result data objects
    ttypes = []
    for rd in rds
        ttypes = union(ttypes, rd |> tick_tests |> keys |> collect)
    end

    # return emptyplot of none of the RDs has test data
    if isempty(ttypes)
        p = emptyplot("No testing data available.")
        plot!(p; plotargs...)
        return p
    end
    

    # get total tests of rd object and test type string (tt), return all zeros if test type not inside rd
    get_test_data(rd, tt) = haskey(tick_tests(rd), tt) ? tick_tests(rd)[tt].total_tests : zeros(Int, final_tick(rd))

    # tickunits
    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # generate one plot per test type in any of the RDs
    plts = []
    for tt in ttypes     
        # generate a plot with data grouped by label
        p = plot(xlabel=upper_ticks,
            ylabel = tt,
            label = tt,
            dpi=300,
            fontfamily = "Times Roman")

        # generate a plot with data grouped by label
        p = plotseries!(p, rd -> get_test_data(rd, tt), rds; plotargs...)
        push!(plts, p)
    end

    p = plot(plts..., layout = (1, length(ttypes)))

    # add custom arguments that were passed
    plot!(p; plotargs...)

    return(p)
end