export BatchTickCases

###
### STRUCT
###

"""
    BatchTickCases <: BatchPlot

A batch plot type for generating a new-cases-per-tick plot.
It includes mean cases per tick, min-max-ranges as well as the 95% confidence band.
"""
@with_kw mutable struct BatchTickCases <: BatchPlot

    title::String = "Cases per Tick" # dfault title
    description::String = "" # default description empty
    filename::String = "batch_cases_per_tick.png" # default filename
    
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
    generate(batchTickCases, batchData)

Generates a plot with cases per tick for a specified batch of simulations.
"""
function generate(plt::BatchTickCases, bd::BatchData)

    cases = bd |> tick_cases
    xlab = bd |> tick_unit |> length > 1 ? "Ticks" : (bd |> tick_unit)[1] |> uppercasefirst

    plot_ticks = plot(xlabel=xlab, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")

    # mean
    plot!(plot_ticks, cases[!,"mean"], label="Mean Cases per $xlab", linewidth=2, color="blue")
    # Max and min with outline
    plot!(plot_ticks, cases[!,"minimum"], fillrange=cases[!,"maximum"], label=nothing, alpha=0.1, color="blue")
    plot!(plot_ticks, cases[!,"minimum"], linewidth=1,linestyle =:dash, label=nothing, alpha=0.5, color="blue")
    plot!(plot_ticks, cases[!,"maximum"], linewidth=1,linestyle =:dash, label=nothing, alpha=0.5, color="blue")
    # 95 with outline
    plot!(plot_ticks, cases[!,"lower_95"], fillrange=cases[!,"upper_95"],label = nothing, alpha=0.2, color="blue")
    plot!(plot_ticks, cases[!,"lower_95"], linewidth=1,linestyle =:dot, label=nothing, alpha=0.5, color="blue")
    plot!(plot_ticks, cases[!,"upper_95"], linewidth=1,linestyle =:dot, label=nothing, alpha=0.5, color="blue")

    return(plot_ticks)
end