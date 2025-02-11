export SettingSizeDistribution

###
### STRUCT
###

"""
    SettingSizeDistribution <: SimulationPlot

A simulation plot type for generating a population pyramid for the associated population model.
"""
@with_kw mutable struct SettingSizeDistribution <: SimulationPlot

    title::String = "Setting Size Distribution" # default title
    description::String = "" # default description empty
    filename::String = "setting_size_distribution.png" # default filename

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
    generate(plt::SettingSizeDistribution, rd::ResultData; plotargs...)

Generates the setting size distributions for all included settings.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::SettingSizeDistribution`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Setting Size Distribution plot
"""
function generate(plt::SettingSizeDistribution, rd::ResultData; plotargs...)

    size_dict = rd |> setting_sizes

    # Create dictionaries containing the setting types and their corresponding 
    # titles / letters
    pls = []
    abc = collect('a':'z')[1:length(size_dict)]
    d = Dict(zip(abc, size_dict |> keys))

    # add description
    desc = "These graphs show the setting size distributions for all included settingtypes." 
    desc *= "The subplots show the following settings: $(join(["$l) $(d[l])" for l in abc], ", ", " and "))."
    desc *= "The x-axis shows the size of the setting and the y-axis the number of settings with this size. "
    description!(plt, desc)
    
    # Create a bar plot for each setting type
    for l in abc

        sizes = size_dict[d[l]]

        min_size = minimum(keys(sizes))
        max_size = maximum(keys(sizes))
        xtick_step = max(1, ceil(Int, (max_size - min_size) / 5))
        bar_width = 0.7
        
        # Create a bar plot for each type
        p = bar(
            collect(keys(sizes)),
            collect(values(sizes)),
            xticks = min_size:xtick_step:max_size,
            bar_width = bar_width,
            title = "$l)",
            legend = false,
            tickfont = font(8, "Times Roman"),
            guidefont = font(10, "Times Roman"),
            titlefont = font(10, "Times Roman", halign=:left),
            xtickfont = font(8, "Times Roman"),
            ytickfont = font(8, "Times Roman")
        )
        push!(pls, p)
    end
    
    # Plot layout configuration
    nplots = length(pls)
    ncols = min(nplots, 2)
    nrows = ceil(Int, nplots / 2)
    
    # Combine the plots into a single layout with shared x and y labels
    plt = plot(
        pls...,
        layout = (nrows, ncols),
        dpi = 600,
        fontfamily = "Times Roman",
        titleloc = :left,
        top_margin = -1.5Plots.mm,
        bottom_margin = -1.8Plots.mm
    )

    # add custom arguments that were passed
    plot!(plt; plotargs...)    

    return plt
end