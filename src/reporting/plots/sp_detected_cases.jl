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

# generates one detected-cases subplot for a single pathogen
function _detected_cases_subplot(detected_cases, utick_str, pid_label; plotargs...)
    sub = areaplot(detected_cases.tick, [detected_cases.new_detections detected_cases.double_reports detected_cases.false_positives],
            seriescolor = [:red :green :blue],
            label = [pid_label * "New Detections" pid_label * "Double Reports" pid_label * "False Positives"],
            fillalpha = [0.2 0.3 0.4],
            xlabel = uppercasefirst(utick_str) * "s",
            ylabel = "Reported Cases (Stacked)",
            dpi = 300,
            fontfamily = "Times Roman")
    plot!(sub, detected_cases.tick, detected_cases.exposed_cnt,
        label = pid_label * "New True Cases", linestyle=:dot, linewidth = 2, linecolor = :black)
    plot!(sub; plotargs...)
    return sub
end

"""
    generate(plt::DetectedCases, rd::ResultData; plotargs...)

Generates and returns a new-DETECTED-cases-per-tick plot for a provided simulation object.
Sorts infections dataframe by `test_tick` and filters for tested individuals.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::DetectedCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens as subplots.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Detected Cases plot
"""
function generate(plt::DetectedCases, rd::ResultData; pathogen = nothing, plotargs...)

    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    title!(plt, "Detected Cases per $upper_ticks")
    desc = "This graph shows the number of individuals who where tested positive for the first time during their active infection per $uticks."
    description!(plt, desc)
    filename!(plt, "detected_cases_per_$uticks.png")

    detected_all, pids, pnames, _ = _pathogen_setup(detected_tick_cases(rd), rd, pathogen)

    subplots = [_detected_cases_subplot(
        filter(row -> row.pathogen_id == pid, detected_all), uticks, "";
        (length(pids) > 1 ? _pathogen_subargs(pid, pnames, plotargs) : NamedTuple(plotargs))...)
        for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs)
end
