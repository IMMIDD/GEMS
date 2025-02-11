export ActiveDarkFigure

###
### STRUCT
###

"""
    ActiveDarkFigure <: SimulationPlot

A simulation plot type for generating an active-darkfigure-per-tick plot.

"""
@with_kw mutable struct ActiveDarkFigure <: SimulationPlot

    title::String = "Active Dark Figure" # default title
    description::String = "" # default description empty
    filename::String = "active_dark_figure.png" # default filename
    
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
    generate(plt::ActiveDarkFigure, rd::ResultData; plotargs...)

Generates and returns a active-darkfigure-per-tick plot for a provided `ResultData` object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::ActiveDarkFigure`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Active Dark Figure plot

"""
function generate(plt::ActiveDarkFigure, rd::ResultData; plotargs...)

    data = rd |> compartment_fill
    uticks = rd |> tick_unit

    # add description
    desc = "This graph shows the total of active cases per $uticks and "
    desc *= "the proportion of cases that were deteced by means of a test. "
    desc *= "The undetected proportion of cases is considered the dark figure."
    description!(plt, desc)

    plot_gt = plot(xlabel=uppercasefirst(uticks)*"s", ylabel="Active Cases", dpi=300, fontfamily = "Times Roman")
    plot!(plot_gt, data[!,"detected_cnt"], fillrange = 0, label="Detected Cases")
    plot!(plot_gt, data[!,"detected_cnt"], fillrange = data[!,"exposed_cnt"]+data[!,"infectious_cnt"], label="Dark Figure", alpha=0.5)

    # add custom arguments that were passed
    plot!(plot_gt; plotargs...)

    return(plot_gt)
end


"""
    generate(plt::ActiveDarkFigure, rds::Vector{ResultData}; plotargs...)

Generates and returns a active-darkfigure-per-tick plot for a provided vector of `ResultData` objects.
In contrast to the single-`ResultData` version of this plot, this implementation will visualize
the fraction of detected cases and not the absolute number of cases.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::ActiveDarkFigure`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Active Dark Figure multi plot

"""
function generate(plt::ActiveDarkFigure, rds::Vector{ResultData}; plotargs...)

    # helper function to calculate fraction of detected cases
    calc_fraction(df) = transform(df, [:exposed_cnt, :infectious_cnt, :detected_cnt] => ByRow((e, i, d) -> 1 - (d / (e + i))) => :detected_fraction).detected_fraction

    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # generate a plot with data grouped by label
    p = plot(
        xlabel = upper_ticks,
        ylabel = "Dark Figure", 
        dpi = 300,
        fontfamily = "Times Roman",
        yticks = (0:.2:1, ["$(100 * i)%" for i in 0:.2:1]),
        ylims = (0, 1))

    # generate a plot with data grouped by label
    p = plotseries!(p, rd -> calc_fraction(rd |> compartment_fill), rds; plotargs...)

    # add custom arguments that were passed
    plot!(p; plotargs...)

    return(p)
end