export CumulativeIsolations

###
### STRUCT
###

"""
    CumulativeIsolations <: SimulationPlot

A simulation plot type for generating a plot displaying the cumulative number
of individuals currently in isolation.
"""
@with_kw mutable struct CumulativeIsolations <: SimulationPlot

    title::String = "Cumulative Isolations" # default title
    description::String = "" # default description empty
    filename::String = "cumulative_isolations.png" # default filename
    
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
    generate(plt::CumulativeIsolations, rd::ResultData; plotargs...)

Generates a plot for the cumulative number of isolated individuals per tick.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::CumulativeIsolations`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Cumulative Isolations plot
"""
function generate(plt::CumulativeIsolations, rd::ResultData; dates::Bool = true,  plotargs...)

    # return empty plot with message, if result data does not contain any isolations
    if (rd |> cumulative_quarantines).quarantined |> sum <= 0
        ep = emptyplot("No one was isolated in this simulation.")
        plot!(ep; plotargs...)
        return ep
    end

    uticks = rd |> tick_unit

    # add description
    desc = "This stracked graph shows the number of individuals who are currently "
    desc *= "in household isolation at any given time during the simuation. "
    desc *= "A total of $(format(rd |> total_quarantines, commas=true)) person-$(uticks)s were spent in isolation "
    desc *= "(area below the curve(s)). $(format((rd |> cumulative_quarantines).students |> sum, commas = true)) "
    desc *= "school-$(uticks)s were lost as well as $(format((rd |> cumulative_quarantines).workers |> sum, commas = true)) "
    desc *= "work-$(uticks)s"

    description!(plt, desc)

    # add "Other" column which is 
    cum_iso = rd |> cumulative_quarantines |>
        x -> areaplot(x.tick, [x.other x.students x.workers],
                seriescolor = [:red :green :blue], 
                label = ["Isolated Other" "Isolated Students" "Isolated Workers"],
                fillalpha = [0.2 0.3 0.4],
                xlabel=uppercasefirst(uticks) * "s",
                ylabel="Current Isolations (Stacked)",
                dpi=300,
                fontfamily = "Times Roman")  


    # add custom arguments that were passed
    plot!(cum_iso; plotargs...)

    # replace x-ticks with dates
    dates ? adddates!(cum_iso, rd) : nothing

    return cum_iso
end



"""
    generate(plt::CumulativeIsolations, rds::Vector{ResultData};
        series::Symbol = :all, plotargs...)

Generates and returns a plot for the cumulative isolations for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

The `series` argument allows to specifcy if quarantined `:workers`, `:students`, or `:other` should be plotted.

# Parameters

- `plt::CumulativeIsolations`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `series::Symbol = :all` *(optional)*: specifcy if quarantined `:workers`, `:students`, or `:other` should be plotted
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Cumulative Isolations multi plot
"""
function generate(plt::CumulativeIsolations, rds::Vector{ResultData};
    dates::Bool = true, series::Symbol = :all, plotargs...)


    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    if series == :workers
        ylabel = "Workers in Isolation"
        col = "workers"
    elseif series == :students
        ylabel = "Students in Isolation"
        col = "students"
    elseif series == :other
        ylabel = "Non-students and- workers in Isolation"
        col = "other"
    else
        ylabel = "Individuals in Isolation"
        col = "quarantined"
    end

    # generate a plot with data grouped by label
    p = plot(xlabel=upper_ticks, ylabel=ylabel, dpi=300, fontfamily = "Times Roman")
    
    # generate a plot with data grouped by label
    p = plotseries!(p, rd -> cumulative_quarantines(rd)[!,col], rds; plotargs...)

    # add custom arguments that were passed
    plot!(p; plotargs...)

    # replace x-ticks with dates
    dates ? adddates!(p, rds[1]) : nothing

    return(p)
end