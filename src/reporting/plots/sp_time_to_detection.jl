export TimeToDetection

###
### STRUCT
###

"""
    TimeToDetection <: SimulationPlot

A simulation plot type for generating a time-to-detection plot.
"""
@with_kw mutable struct TimeToDetection <: SimulationPlot

    title::String = "Time To Detection" # default title
    description::String = "" # default description empty
    filename::String = "time_to_detection.png" # default filename

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
    generate(plt::TimeToDetection, rd::ResultData; plotargs...)

Generates and returns a time-to-detection plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TimeToDetection`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Time To Detection plot
"""
function generate(plt::TimeToDetection, rd::ResultData; plotargs...)

    # return empty plot with message, if result data does not contain tests
    if rd |> tick_tests |> isempty
        plot_tests = emptyplot("There are no Tests available in the ResultData object")
        plot!(plot_tests; plotargs...)
        return(plot_tests)
    end

    detection_times = rd |> time_to_detection
    
    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # add description
    desc = "This graph shows the average time in $(uticks)s between exposure and detection (by means of testing) of an active infection. "
    desc *= "Red shaded areas indicate that no infection was deteceted during that period. "
    desc *= "It does, however, not indicate that no tests were performed during that period."
    description!(plt, desc) 

    # identify missing data regions
    # build a flat array that contains start- and endpoints of missing ticks
    emptyzones = []

    for row in eachrow(detection_times)
        if ismissing(row.mean_time_to_detection)
            push!(emptyzones, row.tick)
            push!(emptyzones, row.tick+1)
        end
    end

    plot_detections = plot(detection_times.tick, detection_times.mean_time_to_detection, label="Mean Time To Detection", xlabel = upper_ticks * "s", ylabel="Time To Detection in $(upper_ticks)s", fontfamily = "Times Roman")
    # add shaded areas to indicate no dection-durations
    vspan!(plot_detections, emptyzones, linewidth = 0, fillcolor = :red, alpha = 0.3, label = "No Detected Cases")

    # add custom arguments that were passed
    plot!(plot_detections; plotargs...)

    return(plot_detections)
end