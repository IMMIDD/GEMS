export BatchEffectiveReproduction

###
### STRUCT
###

"""
    BatchEffectiveReproduction <: BatchPlot
    
A batch plot type for generating a the effective-reproduction-number-per-tick plot.
It includes values per tick, min-max-ranges as well as the 95% confidence band.
"""
@with_kw mutable struct BatchEffectiveReproduction <: BatchPlot

    title::String = "Effective Reproduction Number" # dfault title
    description::String = "" # default description empty
    filename::String = "batch_effective_r.png" # default filename

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
    generate(batchEffectiveReproduction, batchData)

Generates a plot with the effecive reproduction number per tick for a specified batch of simulations.
"""
function generate(plt::BatchEffectiveReproduction, bd::BatchData)

    eff_r = bd |> effectiveR
    xlab = bd |> tick_unit |> length > 1 ? "Ticks" : (bd |> tick_unit)[1] |> uppercasefirst

    plot_ticks = plot(xlabel=xlab, ylabel="Effective R", dpi=300, fontfamily = "Times Roman")
    plot!(plot_ticks, eff_r[!,"minimum"], fillrange = eff_r[!,"maximum"], label="Range", alpha=0.2)
    plot!(plot_ticks, eff_r[!,"lower_95"], fillrange = eff_r[!,"upper_95"], label="95% Confidence Band", alpha=0.4)
    plot!(plot_ticks, eff_r[!,"mean"], label="Mean", linewidth = 2)

    hline!(plot_ticks, [1], linewidth=1, linestyle=:dash, linecolor = :red, label="R=1")
    
    return(plot_ticks)
end