export LatencyHistogram

###
### STRUCT
###

"""
    LatencyHistogram <: SimulationPlot

A simulation plot type for generating the distribution of latency period lengths.
"""
@with_kw mutable struct LatencyHistogram <: SimulationPlot

    title::String = "Latentcy Period Length Distribution" # default title
    description::String = "" # default description empty
    filename::String = "latency_dist.png" # default filename

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
    generate(plt::LatencyHistogram, rd::ResultData; plotargs...)

Generates a histrogram of the latency period distribution of collected infections.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::LatencyHistogram`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Latency Histogram plot
"""
function generate(plt::LatencyHistogram, rd::ResultData; plotargs...)
    
    comp = rd |> compartment_periods

    if isempty(comp)
        ep = emptyplot("The ResultData object does not contain the data necessary to generate this plot.")
        plot!(ep; plotargs...)
        return ep
    end
        
    if comp |> nrow < MIN_INFECTIONS_FOR_PLOTS
        ep = emptyplot("Not enough infection data to generate a latency histogram.")
        plot!(ep; plotargs...)
        return ep
    end



    uticks = rd |> tick_unit

    # add description
    desc  = "The latency is the time between exposure to the pathogen and the $uticks "
    desc *= "an individual becomes infectious. The mean latency was $(round(mean(comp[!,"exposed"]), digits = 3)) "
    desc *= uticks*"s with a median of $(Int(median(comp[!,"exposed"]))) "*uticks*"s."

    description!(plt, desc)

    lh_plot = histogram(comp[!,"exposed"],
        bar_width=0.8,
        label="Latency Period",
        xlabel=uppercasefirst(uticks) * "s",
        ylabel="Number of Infections", 
        xlims = (0, max(5, maximum(comp[!,"exposed"]))),
        fontfamily="Times Roman",
        dpi = 300) 

    # add custom arguments that were passed
    plot!(lh_plot; plotargs...)

    return lh_plot
end