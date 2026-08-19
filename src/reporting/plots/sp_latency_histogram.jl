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

function _latency_histogram_subplot(comp, uticks; plotargs...)
    histogram(comp[!, "exposed"],
        bar_width=0.8,
        label="Latency Period",
        xlabel=uppercasefirst(uticks) * "s",
        ylabel="Number of Infections",
        xlims = (0, max(5, maximum(comp[!, "exposed"]))),
        fontfamily="Times Roman",
        dpi = 300;
        plotargs...)
end

"""
    generate(plt::LatencyHistogram, rd::ResultData; plotargs...)

Generates a histogram of the latency period distribution of collected infections.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::LatencyHistogram`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens as subplots.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Latency Histogram plot
"""
function generate(plt::LatencyHistogram, rd::ResultData; pathogen = nothing, plotargs...)

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
            ep = emptyplot("Not enough infection data to generate a latency histogram.")
            plot!(ep; plotargs...)
            return ep
        end
        desc = "The latency is the time between exposure to the pathogen and the $uticks "
        desc *= "an individual becomes infectious. The mean latency was $(round(mean(comp[!, "exposed"]), digits = 3)) "
        desc *= uticks * "s with a median of $(Int(median(comp[!, "exposed"]))) " * uticks * "s."
        description!(plt, desc)
        return _latency_histogram_subplot(comp, uticks; plotargs...)
    end

    subplots = [begin
        comp = filter(row -> row.pathogen_id == pid, comp_all)
        nrow(comp) < MIN_INFECTIONS_FOR_PLOTS ?
            emptyplot("Not enough data for $(pnames[pid])") :
            _latency_histogram_subplot(comp, uticks; _pathogen_subargs(pid, pnames, plotargs)...)
    end for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs; width_per_plot = 500)
end
