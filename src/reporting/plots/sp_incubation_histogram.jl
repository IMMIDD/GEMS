export IncubationHistogram

###
### STRUCT
###

"""
    IncubationHistogram <: SimulationPlot

A simulation plot type for generating the distribution of incubation period lengths for symptomatic individuals.
"""
@with_kw mutable struct IncubationHistogram <: SimulationPlot

    title::String = "Incubation Period Length Distribution" # default title
    description::String = "" # default description empty
    filename::String = "incubation_dist.png" # default filename

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
    generate(plt::IncubationHistogram, rd::ResultData; plotargs...)

Generates a histrogram of the incubation period distribution (time to symptoms) of collected infections.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

**Note** that this only shows the incubation period for _symptomatic_ individuals!

# Parameters

- `plt::IncubationHistogram`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Infectious Histogram plot
"""
function generate(plt::IncubationHistogram, rd::ResultData; plotargs...)
    
    infs = rd |> infections

    if isempty(infs)
        ep = emptyplot("The ResultData object does not contain the data necessary to generate this plot. `infections`-dataframe missing.")
        plot!(ep; plotargs...)
        return ep
    end

    # calculating incubation time for symptomatic individuals
    # (this will be very slow for large simulations)
    incub = infs |>
        df -> DataFrames.select(df, :tick, :symptom_onset) |>
        df -> df[df.symptom_onset .!= -1, :] |>
        df -> (df.symptom_onset .- df.tick)

        
    if incub |> length < MIN_INFECTIONS_FOR_PLOTS
        ep = emptyplot("Not enough infection data to generate a incubation histogram.")
        plot!(ep; plotargs...)
        return ep
    end

    uticks = rd |> tick_unit

    # add description
    desc  = "The incubation period is the time between exposure and "
    desc *= "onset of symptoms. The mean incubation period "
    desc *= "was $(round(mean(incub), digits = 3)) "*uticks*"s with a median of $(round(Int, median(incub))) "*uticks*"s." # TODO maybe remove round again

    description!(plt, desc)

    ih_plot =  histogram(incub,
        bar_width=0.8,
        label="Incubation Period",
        xlabel=uppercasefirst(uticks) * "s",
        ylabel="Number of Infections", 
        xlims = (0, max(5, maximum(incub))),
        fontfamily="Times Roman",
        dpi = 300) 

    # add custom arguments that were passed
    plot!(ih_plot; plotargs...)

    return ih_plot
end