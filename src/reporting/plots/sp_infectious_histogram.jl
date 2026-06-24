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

function _infectious_histogram_subplot(comp, uticks; plotargs...)
    histogram(comp[!, "infectious"],
        bar_width=0.8,
        label="Infectious Period",
        xlabel=uppercasefirst(uticks) * "s",
        ylabel="Number of Infections",
        fontfamily="Times Roman",
        dpi = 300;
        plotargs...)
end

"""
    generate(plt::InfectiousHistogram, rd::ResultData; plotargs...)

Generates a histogram of the infectious period distribution of collected infections.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::InfectiousHistogram`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens as subplots.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Infectious Histogram plot
"""
function generate(plt::InfectiousHistogram, rd::ResultData; pathogen = nothing, plotargs...)

    comp_all = compartment_periods(rd)

    if isempty(comp_all)
        ep = emptyplot("The ResultData object does not contain the data necessary to generate this plot.")
        plot!(ep; plotargs...)
        return ep
    end

    comp_all, pids, pnames, _ = _pathogen_setup(comp_all, rd, pathogen)

    uticks = rd |> tick_unit

    if length(pids) == 1
        comp = filter(row -> row.pathogen_id == pids[1], comp_all)
        if nrow(comp) < MIN_INFECTIONS_FOR_PLOTS
            ep = emptyplot("Not enough infection data to generate an infectious histogram.")
            plot!(ep; plotargs...)
            return ep
        end
        desc  = "The infectious period is the time between becoming infectious until "
        desc *= "an individual recovers from the infection. The mean infectious period "
        desc *= "was $(round(mean(comp[!, "infectious"]), digits = 3)) " * uticks * "s with a median of $(round(Int, median(comp[!, "infectious"]))) " * uticks * "s."
        description!(plt, desc)
        return _infectious_histogram_subplot(comp, uticks; plotargs...)
    end

    subplots = [begin
        comp = filter(row -> row.pathogen_id == pid, comp_all)
        nrow(comp) < MIN_INFECTIONS_FOR_PLOTS ?
            emptyplot("Not enough data for $(pnames[pid])") :
            _infectious_histogram_subplot(comp, uticks; _pathogen_subargs(pid, pnames, plotargs)...)
    end for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs; width_per_plot = 500)
end
