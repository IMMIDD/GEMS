export InfectiousHistogram

###
### STRUCT
###

"""
    InfectiousHistogram <: SimulationPlot

A simulation plot type for generating the distribution of infectious period lengths.
"""
@with_kw mutable struct InfectiousHistogram <: SimulationPlot

    title::String = "Infectious Period Length Distribution" # default title
    description::String = "" # default description empty
    filename::String = "infectious_dist.png" # default filename

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
    generate(plt::InfectiousHistogram, rd::ResultData; plotargs...)

Generates a histrogram of the infectious period distribution of collected infections.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::InfectiousHistogram`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Infectious Histogram plot
"""
function generate(plt::InfectiousHistogram, rd::ResultData; plotargs...)
    
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
    desc  = "The infectious period is the time between becoming infectious until "
    desc *= "an individual recovers from the infection. The mean inectious period "
    desc *= "was $(round(mean(comp[!,"infectious"]), digits = 3)) "*uticks*"s with a median of $(round(Int, median(comp[!,"infectious"]))) "*uticks*"s." # TODO maybe remove round again

    description!(plt, desc)

    ih_plot =  histogram(comp[!,"infectious"],
        bar_width=0.8,
        label="Infectious Period",
        xlabel=uppercasefirst(uticks) * "s",
        ylabel="Number of Infections", 
        fontfamily="Times Roman",
        dpi = 300) 

    # add custom arguments that were passed
    plot!(ih_plot; plotargs...)

    return ih_plot
end