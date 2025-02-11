export GenerationTime

###
### STRUCT
###

"""
    GenerationTime <: SimulationPlot

A simulation plot type for generating a generation-time-per-tick.
"""
@with_kw mutable struct GenerationTime <: SimulationPlot

    title::String = "Generation Time" # default title
    description::String = "" # default description empty
    filename::String = "generation_time.png" # default filename
    
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
    generate(plt::GenerationTime, rd::ResultData; plotargs...)

Generates and returns a generation-time-per-tick plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::GenerationTime`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Generation Time plot
"""
function generate(plt::GenerationTime, rd::ResultData; plotargs...)

    data = rd |> tick_generation_times |> dropmissing
    uticks = rd |> tick_unit

    # add description
    desc = "This graph shows the generation time which is defined as the "
    desc *= "duration (in $(uticks)s) between an index person's exposure and the exposure of its immediate "
    desc *= "predecessor in an infection chain. For any current infection event, it shows how many $(uticks)s before "
    desc *= "the _infecting_ agent was exposed to the pathogen himself."
    description!(plt, desc)

    plot_gt = plot(xlabel=uppercasefirst(uticks)*"s", ylabel="Generation Time ($(uppercasefirst(uticks))s)", dpi=300, fontfamily = "Times Roman")
    plot!(plot_gt, data[!,"min_generation_time"], fillrange = data[!,"max_generation_time"], label="Range", alpha=0.2)
    plot!(plot_gt, data[!,"mean_generation_time"]-data[!,"std_generation_time"], fillrange = data[!,"mean_generation_time"]+data[!,"std_generation_time"], label="+/- 1 Std. Deviation", alpha=0.4)
    plot!(plot_gt, data[!,"mean_generation_time"], label="Mean", linewidth = 2)

    # add custom arguments that were passed
    plot!(plot_gt; plotargs...)

    return(plot_gt)
end


"""
    generate(plt::GenerationTime, rds::Vector{ResultData}; plotargs...)

Generates and returns a plot for the mean generation-time-per-tick for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TickCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Generation Time multi plot
"""
function generate(plt::GenerationTime, rds::Vector{ResultData}; plotargs...)

    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # generate a plot with data grouped by label
    p = plot(xlabel=upper_ticks, ylabel="Mean Gen. Time ($(upper_ticks)s)", dpi=300, fontfamily = "Times Roman", xlims = (0, rds[1] |> final_tick))
    
    # generate a plot with data grouped by label
    p = plotseries!(p, rd -> dropmissing(tick_generation_times(rd))[!,"mean_generation_time"], rds; plotargs...)

    # add custom arguments that were passed
    plot!(p; plotargs...)

    return(p)
end