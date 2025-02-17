export Incidence

###
### STRUCT
###

"""
    Incidence <: SimulationPlot

A simulation plot type for generating an incidence plot.
"""
@with_kw mutable struct Incidence <: SimulationPlot

    title::String = "" # default title
    description::String = "" # default description empty
    filename::String = "incidence.png" # default filename
    
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
    generate(plt::Incidence, rd::ResultData; plotargs...)

Generates an age-stratified incidence plot.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::Incidence`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Incidence plot
"""
function generate(plt::Incidence, rd::ResultData; dates::Bool = true,  plotargs...)

    incidence = rd |> age_incidence

    # update title
    utick = rd |> tick_unit |> uppercasefirst
    ttl = "7-$utick Incidence per 100,000 Individuals"
    title!(plt, ttl)

    # add description
    desc = "This graph displays the 7-$utick incidence per 100,000 individuals and 10-year age group at any given time during the simulation. "
    desc *= "The _incidence_ is defined as the number of currently infected individuals in proportion to population size."
    description!(plt, desc)


    incidence_plot = groupedbar([incidence[!, "a0_10"] incidence[!, "a11_20"] incidence[!, "a21_30"] incidence[!, "a31_40"] incidence[!, "a41_50"] incidence[!, "a51_60"] incidence[!, "a61_70"] incidence[!, "a71_80"] incidence[!, "a81_90"] incidence[!, "a91_100"]],
        bar_position = :stack,
        bar_width = 0.6,
        xlabel = utick,
        ylabel = ttl,
        linecolor = :match,
        label = ["Age 0-10" "Age 11-20" "Age 21-30" "Age 31-40" "Age 41-50" "Age 51-60" "Age 61-70" "Age 71-80" "Age 81-90" "Age 91-100"], 
        fontfamily="Times Roman",
        dpi = 300)

    # add custom arguments that were passed
    plot!(incidence_plot; plotargs...)

    # replace x-ticks with dates
    dates ? adddates!(incidence_plot, rd) : nothing

    return(incidence_plot)
end