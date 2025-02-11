export BatchTickTests, totalonly, totalonly!

###
### STRUCT
###

"""
    BatchTickTests <: BatchPlot
    
A batch plot type for generating a tests-per-tick plot.
It includes mean tests per tick, min-max-ranges as well as the 95% confidence band.
"""
@with_kw mutable struct BatchTickTests <: BatchPlot

    title::String = "Tests per Tick" # dfault title
    description::String = "" # default description empty
    filename::String = "tests_per_tick.png" # default filename

    totalonly::Bool = false # if true, only plot total number of tests    

    # indicates to which package the result plot belongs
    # is used to parallelize report generation and prevents
    # concurrent generation of plots coming from the same package
    # if you don't know the origin package or if the function
    # returns different plot types depending on the input, 
    # just put ":other" which will trigger sequential generation
    package::Symbol = :Plots
end

"""
    totalonly!(batchTickTests, totalonly)

Setter for the totalonly field of the `BatchTickTests` plot specifying whether only the
total number of tests should be plotted or all data series (including positive, negative tests, etc...)
"""
function totalonly!(btt::BatchTickTests, totalonly::Bool)
    btt.totalonly = totalonly
end

"""
    totalonly(batchTickTests)

Getter for the totalonly field of `BatchTickTests` plot structs.

"""
function totalonly(btt::BatchTickTests)
    return(btt.totalonly)
end

###
### PLOT GENERATION
###

"""
    generate(BatchTickTests, batchData)

Generates a plot with subplots for each test type. Each includes tests per tick for a specified batch of simulations.
"""
function generate(plt::BatchTickTests, bd::BatchData)
    # return empty plot with message, if result data does not contain tests
    if bd |> tests |> isempty
        plot_tests = plot(
            xlabel="", 
            ylabel="", 
            legend=false, 
            fontfamily="Times Roman",
            dpi = 300)
        plot!([], [], #=annotation=(0.5, 0.5, Plots.text("There are no Tests available in the ResultData object", :center, 10, :black, "Times Roman")), =#
        fontfamily="Times Roman",
        dpi = 300)
        return(plot_tests)
    end

    xlab = bd |> tick_unit |> length > 1 ? "Ticks" : (bd |> tick_unit)[1] |> uppercasefirst
    # Initialize an array to hold the subplots
    subplots = []

    # Define a list of colors for the subplots
    colors = ["blue", "green", "red", "purple", "orange"]

    # Iterate over the tests and create a subplot for each one
    for (idx, (key, dict)) in enumerate(bd |> tests)
        # Create a subplot for the current test
        push!(subplots, plot(xlabel=xlab, ylabel="Count", dpi=300, fontfamily="Times Roman", title = string(key)))

        # Plot data within the subplot
        for (idy, (col, df)) in enumerate(dict)
            
            # either plot all subseries if totalonly == false or only total_tests series
            if !totalonly(plt) || (totalonly(plt) && col == "total_tests")
                # Mean 
                plot!(subplots[idx], df[!,"mean"], label="Mean $col", linewidth=2, color=colors[idy % length(colors) +  1])
                # Max and min with outline
                plot!(subplots[idx], df[!,"minimum"], fillrange=df[!,"maximum"], label=nothing, alpha=0.1, color=colors[idy % length(colors) +  1])
                plot!(subplots[idx], df[!,"minimum"], linewidth=1,linestyle =:dash, label=nothing, alpha=0.5, color=colors[idy % length(colors) +  1])
                plot!(subplots[idx], df[!,"maximum"], linewidth=1,linestyle =:dash, label=nothing, alpha=0.5, color=colors[idy % length(colors) +  1])
                # 95 with outline
                plot!(subplots[idx], df[!,"lower_95"], fillrange=df[!,"upper_95"],label = nothing, alpha=0.2, color=colors[idy % length(colors) +  1])
                plot!(subplots[idx], df[!,"lower_95"], linewidth=1,linestyle =:dot, label=nothing, alpha=0.5, color=colors[idy % length(colors) +  1])
                plot!(subplots[idx], df[!,"upper_95"], linewidth=1,linestyle =:dot, label=nothing, alpha=0.5, color=colors[idy % length(colors) +  1])
            end
        end
    end

    # Combine all subplots into a single figure
    p = plot(subplots..., 
    fontfamily="Times Roman",
    dpi = 300)

    return p
end