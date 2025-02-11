export BatchTickIsolations

###
### STRUCT
###

"""
    BatchTickIsolations <: BatchPlot
    
A batch plot type for generating a current-isolations-per-tick plot.
It includes mean number of isolated individuals per tick, min-max-ranges as well as the 95% confidence band.
"""
@with_kw mutable struct BatchTickIsolations <: BatchPlot

    title::String = "Isolations per Tick" # dfault title
    description::String = "" # default description empty
    filename::String = "batch_isolations_per_tick.png" # default filename
    
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
    generate(batchTickIsolations, batchData)

Generates a plot with currently quarantined people per tick for a specified batch of simulations.
"""
function generate(plt::BatchTickIsolations, bd::BatchData)

    # return empty plot with message, if result data does not contain isolations
    if (bd |> cumulative_quarantines)[!, "maximum"] |> sum <= 0
        plot_isolations = plot(
            xlabel="", 
            ylabel="", 
            legend=false, 
            fontfamily="Times Roman",
            dpi = 300)
        plot!([], [], #=annotation=(5, 0.5, Plots.text("There are no Isolations available in the ResultData object", :center, 10, :black, "Times Roman")),=# 
        fontfamily="Times Roman",
        dpi = 300)
        return(plot_isolations)
    end

    qts = bd |> cumulative_quarantines
    xlab = bd |> tick_unit |> length > 1 ? "Ticks" : (bd |> tick_unit)[1] |> uppercasefirst

    plot_isolations = plot(xlabel=xlab, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")

    # mean
    plot!(plot_isolations, qts[!,"mean"], label="Mean Current Isolations per $xlab", linewidth=2, color="red")
    # Max and min with outline
    plot!(plot_isolations, qts[!,"minimum"], fillrange=qts[!,"maximum"], label=nothing, alpha=0.1, color="red")
    plot!(plot_isolations, qts[!,"minimum"], linewidth=1,linestyle =:dash, label=nothing, alpha=0.5, color="red")
    plot!(plot_isolations, qts[!,"maximum"], linewidth=1,linestyle =:dash, label=nothing, alpha=0.5, color="red")
    # 95 with outline
    plot!(plot_isolations, qts[!,"lower_95"], fillrange=qts[!,"upper_95"],label = nothing, alpha=0.2, color="red")
    plot!(plot_isolations, qts[!,"lower_95"], linewidth=1,linestyle =:dot, label=nothing, alpha=0.5, color="red")
    plot!(plot_isolations, qts[!,"upper_95"], linewidth=1,linestyle =:dot, label=nothing, alpha=0.5, color="red")

    return(plot_isolations)
end