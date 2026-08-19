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

function _incubation_histogram_subplot(incub, uticks; plotargs...)
    histogram(incub,
        bar_width=0.8,
        label="Incubation Period",
        xlabel=uppercasefirst(uticks) * "s",
        ylabel="Number of Infections",
        xlims = (0, max(5, maximum(incub))),
        fontfamily="Times Roman",
        dpi = 300;
        plotargs...)
end

"""
    generate(plt::IncubationHistogram, rd::ResultData; plotargs...)

Generates a histogram of the incubation period distribution (time to symptoms) of collected infections.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

**Note** that this only shows the incubation period for _symptomatic_ individuals!

# Parameters

- `plt::IncubationHistogram`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens as subplots.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Incubation Histogram plot
"""
function generate(plt::IncubationHistogram, rd::ResultData; pathogen = nothing, plotargs...)

    infs_raw = infections(rd)

    if isempty(infs_raw)
        ep = emptyplot("The ResultData object does not contain the data necessary to generate this plot. `infections`-dataframe missing.")
        plot!(ep; plotargs...)
        return ep
    end

    infs, pids, pnames, _ = _pathogen_setup(infs_raw, rd, pathogen)

    uticks = rd |> tick_unit

    incub_for(sub) = DataFrames.select(sub, :tick, :symptom_onset) |>
        df -> df[df.symptom_onset .!= -1, :] |>
        df -> (df.symptom_onset .- df.tick)

    if length(pids) == 1
        incub = incub_for(filter(row -> row.pathogen_id == pids[1], infs))
        if length(incub) < MIN_INFECTIONS_FOR_PLOTS
            ep = emptyplot("Not enough infection data to generate an incubation histogram.")
            plot!(ep; plotargs...)
            return ep
        end
        desc  = "The incubation period is the time between exposure and "
        desc *= "onset of symptoms. The mean incubation period "
        desc *= "was $(round(mean(incub), digits = 3)) " * uticks * "s with a median of $(round(Int, median(incub))) " * uticks * "s."
        description!(plt, desc)
        return _incubation_histogram_subplot(incub, uticks; plotargs...)
    end

    subplots = [begin
        incub = incub_for(filter(row -> row.pathogen_id == pid, infs))
        length(incub) < MIN_INFECTIONS_FOR_PLOTS ?
            emptyplot("Not enough data for $(pnames[pid])") :
            _incubation_histogram_subplot(incub, uticks; _pathogen_subargs(pid, pnames, plotargs)...)
    end for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs; width_per_plot = 500)
end
