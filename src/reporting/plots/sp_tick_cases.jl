export TickCases

###
### STRUCT
###

"""
    TickCases <: SimulationPlot

A simulation plot type for generating a new-cases-per-tick plot.
"""
@with_kw mutable struct TickCases <: SimulationPlot

    title::String = "Cases per Tick" # default title
    description::String = "" # default description empty
    filename::String = "cases_per_tick.png" # default filename

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
    generate(plt::TickCases, rd::ResultData; plotargs...)

Generates and returns a new-cases-per-tick plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TickCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Tick Cases plot
"""
function generate(plt::TickCases, rd::ResultData; dates::Bool = true, plotargs...)

    cases = rd |> tick_cases
    deaths = rd |> tick_deaths
    vaccinations = rd |> tick_vaccinations

    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # update title
    title!(plt, "Cases per $upper_ticks")

    # add description
    desc = "This graph shows the number of new individuals entering any of the disease states per $uticks."
    description!(plt, desc)
    
    # update filename
    filename!(plt, "cases_per_$uticks.png")

    plot_ticks = plot(xlabel=upper_ticks, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")
    plot!(plot_ticks, cases[!,"exposed_cnt"], label="Exposed")
    plot!(plot_ticks, cases[!,"infectious_cnt"], label="Infectious")
    plot!(plot_ticks, cases[!,"removed_cnt"], label="Removed")
    plot!(plot_ticks, deaths[!, "death_cnt"], label="Deaths", c=:black)

    # add custom arguments that were passed
    plot!(plot_ticks; plotargs...)

    # replace x-ticks with dates
    dates ? adddates!(plot_ticks, rd) : nothing

    return(plot_ticks)
end


"""
    generate(plt::TickCases, rds::Vector{ResultData}; plotargs...)

Generates and returns a plot for the new-cases-per-tick for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TickCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Tick Cases multi plot
"""
function generate(plt::TickCases, rds::Vector{ResultData}; dates::Bool = true,  plotargs...)

    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # generate a plot with data grouped by label
    p = plot(xlabel=upper_ticks, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")
    
    # generate a plot with data grouped by label
    p = plotseries!(p, rd -> tick_cases(rd)[!,"exposed_cnt"], rds; plotargs...)

    # add custom arguments that were passed
    plot!(p; plotargs...)

    # replace x-ticks with dates
    dates ? adddates!(p, rds[1]) : nothing

    return(p)
end