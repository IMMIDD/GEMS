export CumulativeDiseaseProgressions

###
### STRUCT
###

"""
    CumulativeDiseaseProgressions <: SimulationPlot

A simulation plot type for generating a stacked bar chart on the
cumulative disease progression.
"""
@with_kw mutable struct CumulativeDiseaseProgressions <: SimulationPlot

    title::String = "Cumulative Disease Progressions" # default title
    description::String = "" # default description empty
    filename::String = "cumulative_disease_progressions.png" # default filename

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

function _cum_disease_progressions_subplot(df, uticks; plotargs...)
    groupedbar([df[!, "latent"] df[!, "pre_symptomatic"] df[!, "symptomatic"] df[!, "asymptomatic"]],
        bar_position = :stack,
        bar_width = 0.8,
        xlabel = uppercasefirst(uticks) * "s After Exposure",
        ylabel = "Cumulative Disease Progressions",
        linecolor = :match,
        label = ["Latent" "Pre-Symptomatic" "Symptomatic" "Asymptomatic"],
        fontfamily="Times Roman",
        dpi = 300;
        plotargs...)
end

"""
    generate(plt::CumulativeDiseaseProgressions, rd::ResultData; plotargs...)

Generates a stacked bar chart of cumulative disease progressions for all infections.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::CumulativeDiseaseProgressions`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens as subplots.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Cumulative Disease Progressions plot
"""
function generate(plt::CumulativeDiseaseProgressions, rd::ResultData; pathogen = nothing, plotargs...)

    uticks = rd |> tick_unit

    desc = "This graph shows a cumulative analysis on all disease progressions. "
    desc *= "It displays how many individuals were in a certain disease state at a given $uticks after their initial exposure. "
    desc *= "The states are _Latent_ (infected but not infectious and not symptomatic), "
    desc *= "_Pre-Symptomatic_ (infectious without symptoms but will develop symptoms), "
    desc *= "_Symptomatic_ (infectious and symptomatic), and "
    desc *= "_Asymptomatic_ (infectious but not experiencing symptoms). "
    desc *= "The graph also shows how long the diseases progressed between exposure and recovery."
    description!(plt, desc)

    df_all, pids, pnames, _ = _pathogen_setup(cumulative_disease_progressions(rd), rd, pathogen)

    subplots = [_cum_disease_progressions_subplot(
        filter(row -> row.pathogen_id == pid, df_all), uticks;
        (length(pids) > 1 ? _pathogen_subargs(pid, pnames, plotargs) : NamedTuple(plotargs))...)
        for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs)
end
