export CompartmentFill

###
### STRUCT
###

"""
    CompartmentFill <: SimulationPlot

A simulation plot type for generating a cumulative infections plot.
"""
@with_kw mutable struct CompartmentFill <: SimulationPlot

    title::String = "Current Compartment Fill" # default title
    description::String = "" # default description empty
    filename::String = "compartment_fill.png" # default filename
   
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
    generate(plt::CompartmentFill, rd::ResultData; plotargs...)

Generates and returns a plot of the current compartment fill for a provided ResultData object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::CompartmentFill`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Compartment Fill plot

"""
function generate(plt::CompartmentFill, rd::ResultData; plotargs...)

    comp_fill = rd |> compartment_fill
    xlab = (rd |> tick_unit |> uppercasefirst) * "s"

    # add description
    desc = "This graph shows the number of individuals currently asymptomatic, infectious, recovered and deceased agents "
    desc *= "for each  $(rd |> tick_unit) during the simulation."
    description!(plt, desc)

    plot_cum = Plots.plot(xlabel=xlab, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")
    plot!(plot_cum, comp_fill[!,"exposed_cnt"], label="Exposed")
    plot!(plot_cum, comp_fill[!, "infectious_cnt"], label="Infectious")
    plot!(plot_cum, comp_fill[!, "dead_cnt"], label="Deceased", c=:black)

    # add custom arguments that were passed
    plot!(plot_cum; plotargs...)

    return(plot_cum)
end
