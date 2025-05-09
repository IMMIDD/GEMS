export CumulativeCases

###
### STRUCT
###

"""
    CumulativeCases <: SimulationPlot

A simulation plot type for generating a cumulative infections plot.
"""
@with_kw mutable struct CumulativeCases <: SimulationPlot

    title::String = "Cumulative Cases" # default title
    description::String = "" # default description empty
    filename::String = "cumulative_cases.png" # default filename
    
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
    generate(plt::CumulativeCases, rd::ResultData; plotargs...)

Generates and returns a cumulative infections plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::CumulativeCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Cumulative Cases plot
"""
function generate(plt::CumulativeCases, rd::ResultData; dates::Bool = true,  plotargs...)

    cum_cases = rd |> cumulative_cases
    cum_vaccinations = rd |> cumulative_vaccinations
    #h_df = rd |> hospital_df
    xlab = (rd |> tick_unit |> uppercasefirst) * "s"

    # add description
    desc = "This graph shows the cumulative number of infections, recoveries, deaths, vaccinations "
    desc *= "and hospitalizations for each $(rd |> tick_unit) during the simulation."
    description!(plt, desc)

    plot_cum = plot(xlabel=xlab, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")
    plot!(plot_cum, cum_cases[!,"exposed_cum"], label="Infections")
    plot!(plot_cum, cum_cases[!,"recovered_cum"], label="Recoveries")
    plot!(plot_cum, cum_cases[!, "deaths_cum"], label="Deaths", c=:black)
    #plot!(plot_cum, h_df.tick, cumsum(h_df.hospital_cnt), label="Hospitalizations")

    # add custom arguments that were passed
    plot!(plot_cum; plotargs...)

    # replace x-ticks with dates
    dates ? adddates!(plot_cum, rd) : nothing

    return(plot_cum)
end



"""
    generate(plt::CumulativeCases, rds::Vector{ResultData}; plotargs...)

Generates and returns a cumulative infections plot for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...`
that are available in the `Plots.jl` package.

# Parameters

- `plt::CumulativeCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Cumulative Cases multi plot
"""
function generate(plt::CumulativeCases, rds::Vector{ResultData}; dates::Bool = true,  plotargs...)

    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # generate a plot with data grouped by label
    p = plot(xlabel=upper_ticks, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")

    # generate a plot with data grouped by label
    p = plotseries!(p, rd -> cumulative_cases(rd)[!,"exposed_cum"], rds; plotargs...)

    # add custom arguments that were passed
    plot!(p; plotargs...)

    # replace x-ticks with dates
    dates ? adddates!(p, rds[1]) : nothing

    return(p)
end