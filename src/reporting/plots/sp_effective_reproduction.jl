export EffectiveReproduction

###
### STRUCT
###

"""
    EffectiveReproduction <: SimulationPlot

A simulation plot type for generating an effective reproduction number plot.
"""
@with_kw mutable struct EffectiveReproduction <: SimulationPlot

    title::String = "Effective Reproduction Number" # default title
    description::String = "" # default description empty
    filename::String = "effective_r.png" # default filename
    
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
    generate(plt::EffectiveReproduction, rd::ResultData; plotargs...)

Generates a plot for the effective reproduction number per tick.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::EffectiveReproduction`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Effective Reproduction Number plot
"""
function generate(plt::EffectiveReproduction, rd::ResultData; plotargs...)

    # calculate effective R over time from post processor data
    eff_r = rd |> effectiveR

    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # add description
    desc  = "The effective reproduction number is calculated by counting all infections that "
    desc *= "are caused by an infected individual A after its infection at time T. The "
    desc *= "statistics are added to the $uticks of A's initial infection (T) although the actual "
    desc *= "infections might happen at a later $uticks. "
    desc *= "The visualized data is a 7-$uticks rolling average."

    description!(plt, desc)

    plot_eff_R = plot(xlabel=upper_ticks * "s", ylabel="Effective R", reuse = false, dpi=300, fontfamily = "Times Roman")
    plot!(plot_eff_R, eff_r[!,"rolling_R"], label="(7-$uticks Rolling) Effective R")
    plot!(plot_eff_R, eff_r[!,"rolling_in_hh_R"], label="(7-$uticks Rolling) Effective R (In Households)")
    plot!(plot_eff_R, eff_r[!,"rolling_out_hh_R"], label="(7-$uticks Rolling) Effective R (Outside Households)")
    hline!(plot_eff_R, [1], linewidth=1, linestyle=:dash, linecolor = :red, label="R=1") # add criticality threshold (R=1)
    
    # add custom arguments that were passed
    plot!(plot_eff_R; plotargs...)
    
    return(plot_eff_R)    
end


"""
    generate(plt::EffectiveReproduction, rds::Vector{ResultData}; plotargs...)

Generates a plot for the effective reproduction number per tick for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::EffectiveReproduction`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Effective Reproduction Number multi plot
"""
function generate(plt::EffectiveReproduction, rds::Vector{ResultData}; plotargs...)

    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # generate a plot with data grouped by label
    p = plot(xlabel=upper_ticks, ylabel="(7-$uticks Rolling) Effective R", dpi=300, fontfamily = "Times Roman")
    
    plotseries!(p, rd -> effectiveR(rd)[!,"rolling_R"], rds; plotargs...)

    hline!(p, [1], linewidth=1, linestyle=:dash, linecolor = :red, label="R=1") # add criticality threshold (R=1)

    # add custom arguments that were passed
    plot!(p; plotargs...)

    return(p)
end