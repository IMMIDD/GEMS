export TickSeroTests

###
### STRUCT
###

"""
    TickSeroTests <: SimulationPlot

A simulation plot type for generating a new-sero-tests-per-tick plot.
"""
@with_kw mutable struct TickSeroTests <: SimulationPlot

    title::String = "Seroprevalence-Tests per Tick" # default title
    description::String = "" # default description empty
    filename::String = "sero_tests_per_tick.png" # default filename

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
    generate(plt::TickSeroTests, rd::ResultData; plotargs...)

Generates and returns a sero-tests-per-tick plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TickSeroTests`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Tick Tests plot
"""
function generate(plt::TickSeroTests, rd::ResultData; detailed=false, plotargs...)

    serotest_summary = rd |> tick_serotests

    if isempty(serotest_summary)
        plot_tests = emptyplot("There are no Seroprevalence Tests\navailable in the ResultData object")
        plot!(plot_tests; plotargs...)
        return(plot_tests)
    end

    uticks = rd |> tick_unit
    upper_ticks = uppercasefirst(uticks)

    # update title and filename
    title!(plt, "Seroprevalence Test Outcomes per $upper_ticks")
    filename!(plt, "serotest_outcomes_per_$uticks.png")

    desc = detailed ?
        "This graph shows the outcome of seroprevalence tests per $uticks, broken down by test result category: _True Positives_, _False Positives_, _True Negatives_, and _False Negatives_. A dashed line shows the _Total Tests_ conducted." :
        "This graph shows the number of seroprevalence tests performed (_Total Tests_) and how many were positive (_Positive Tests_) per $uticks."

    description!(plt, desc)

    # Set up plot
    plot_sero = plot(
        xlabel = "$upper_ticks",
        ylabel = "Tests",
        title = plt.title,
        legend = :topright,
        fontfamily = "Times Roman",
        framestyle = :box,
        grid = :auto
    )

    for (testtype, df) in serotest_summary
        if detailed
            # Stack areas: base layer
            base1 = df.true_positives
            base2 = base1 .+ df.false_positives
            base3 = base2 .+ df.true_negatives
            base4 = base3 .+ df.false_negatives

            # Plot each test outcome category
            plot!(plot_sero, df.tick, base1,
                seriestype = :path, fillrange = 0,
                fillcolor = :red, color = :red, fillalpha = 0.5,
                label = "True Positives")

            plot!(plot_sero, df.tick, base2,
                seriestype = :path, fillrange = base1,
                fillcolor = :blue, color = :blue, fillalpha = 0.5,
                label = "False Positives")

            plot!(plot_sero, df.tick, base3,
                seriestype = :path, fillrange = base2,
                fillcolor = :green, color = :green, fillalpha = 0.5,
                label = "True Negatives")

            plot!(plot_sero, df.tick, base4,
                seriestype = :path, fillrange = base3,
                fillcolor = :gray, color = :gray, fillalpha = 0.5,
                label = "False Negatives")

            # Overlay dashed total line
            plot!(plot_sero, df.tick, df.total_tests,
                color = :black, linewidth = 2, linestyle = :dash,
                label = "Total Tests")
        else
            # Simplified version
            plot!(plot_sero, df.tick, df.total_tests,
                label = "Total Tests", color = palette(:auto)[1],linestyle = :solid)
            plot!(plot_sero, df.tick, df.positive_tests, label = "Positive Tests", color = palette(:auto)[3], linestyle = :solid)
        end
    end

    plot!(plot_sero; plotargs...)
    return plot_sero
end