export DetectedCases

# TODO NOTE: I JUST FOUND OUT THAT THIS IS VERY SIMILAR TO
# TICK_TESTS PLOT. IT DOES THE SAME CALCULATION

###
### STRUCT
###

"""
    DetectedCases <: SimulationPlot

A simulation plot type for generating a new-DETECTED-cases-per-tick plot.

"""
@with_kw mutable struct DetectedCases <: SimulationPlot

    title::String = "Detected Cases per Tick" # default title
    description::String = "" # default description empty
    filename::String = "detected_cases_per_tick.png" # default filename
    
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
    generate(plt::DetectedCases, rd::ResultData; plotargs...)

Generates and returns a new-DETECTED-cases-per-tick plot for a provided simulation object.
Sorts infections dataframe by `test_tick`and filters for tested individuals.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::DetectedCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Detected Cases plot
"""
function generate(plt::DetectedCases, rd::ResultData; plotargs...)

    detected_cases = rd |> detected_tick_cases
    
    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # update title
    title!(plt, "Detected Cases per $upper_ticks")

    # add description
    desc = "This graph shows the number of individuals who where tested positive for the first time during their active infection per $uticks."
    description!(plt, desc)
    
    # update filename
    filename!(plt, "detected_cases_per_$uticks.png")

    # build areaplot
    plot_ticks = detected_cases |>
        x -> areaplot(x.tick, [x.new_detections x.double_reports x.false_positives],
                seriescolor = [:red :green :blue], 
                label = ["New Detections" "Double Reports" "False Positives"],
                fillalpha = [0.2 0.3 0.4],
                xlabel=upper_ticks * "s",
                ylabel="Reported Cases (Stacked)",
                dpi=300,
                fontfamily = "Times Roman")

    # add the true new cases
    plot!(plot_ticks, detected_cases.tick, detected_cases.exposed_cnt, label="New True Cases", linestyle=:dot, linewidth = 2, linecolor = :black)

    # add custom arguments that were passed
    plot!(plot_ticks; plotargs...)

    return(plot_ticks)
end