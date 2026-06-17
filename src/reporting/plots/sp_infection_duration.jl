export InfectionDuration

###
### STRUCT
###

"""
    InfectionDuration <: SimulationPlot

A simulation plot type for visualizing the distribution of infection durations as a histogram.
"""
@with_kw mutable struct InfectionDuration <: SimulationPlot
    title::String = "Infection Duration"
    description::String = ""
    filename::String = "infection_duration.png"

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

function _infection_duration_bar(data, uticks; linecolor = :black, plotargs...)
    formatter = x -> string(round(x * 100; digits=1), "%")
    bar(data.duration, data.total,
        bar_width=0.8,
        label="Disease Duration",
        xlabel=uppercasefirst(uticks) * "s",
        ylabel="Fraction of Infections",
        yformatter=formatter,
        linecolor = linecolor,
        fontfamily="Times Roman",
        dpi = 300;
        plotargs...)
end

"""
    generate(plt::InfectionDuration, rd::ResultData; plotargs...)

Generates and returns a histogram of the total infection durations in ticks.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::InfectionDuration`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens as subplots.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Infection Duration plot
"""
function generate(plt::InfectionDuration, rd::ResultData; pathogen = nothing, linecolor = :black, plotargs...)

    all_data = aggregated_compartment_periods(rd)

    if isempty(all_data)
        @warn "Infection duration data not available in RD-object. Consider adding the 'aggregated_compartment_periods' field to your RD-Style."
        return emptyplot("Infection duration data not available in RD-object.")
    end

    uticks = rd |> tick_unit

    all_data, pids, pnames, _ = _pathogen_setup(all_data, rd, pathogen)

    if length(pids) == 1
        data = filter(row -> row.pathogen_id == pids[1], all_data)
        mean_dur = sum(data.duration .* data.total)
        desc  = "The duration is the time between exposure to the pathogen until recovery. "
        desc *= "The mean duration was $(round(mean_dur, digits = 3)) $(uticks)s."
        description!(plt, desc)
        return _infection_duration_bar(data, uticks; linecolor, plotargs...)
    end

    subplots = [_infection_duration_bar(
        filter(row -> row.pathogen_id == pid, all_data), uticks;
        linecolor, _pathogen_subargs(pid, pnames, plotargs)...) for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs; width_per_plot = 500)
end


"""
    generate(plt::InfectionDuration, rds::Vector{ResultData}; plotargs...)

Generates and returns a histogram of the total infection durations in ticks for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::InfectionDuration`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Infection Duration plot
"""
function generate(plt::InfectionDuration, rds::Vector{ResultData}; pathogen = nothing, plotargs...)

    if _someempty(aggregated_compartment_periods, rds)
        @warn "Infection duration data not available in all RD-objects. Consider adding the 'aggregated_compartment_periods' field to your RD-Style or use a style that already contains the required data (e.g., the DefaultResultData style)"
        return emptyplot("Infection duration data not available in all RD-object.")
    end

    uticks = rds[1] |> tick_unit

    pid_filter = _resolve_pathogen_id(rds[1], pathogen)

    function _boxplot_for_pid(pid_filter)
        data = vcat(map(rd -> filter(row -> row.pathogen_id == pid_filter, aggregated_compartment_periods(rd)), rds)...)
        sort!(data, :duration)
        max_len = length(rds)
        ids = unique(data.duration)
        result_matrix = zeros(max_len, length(ids))
        for (idx, id) in enumerate(ids)
            col_values = data.total[data.duration .== id]
            result_matrix[1:length(col_values), idx] .= col_values
        end
        formatter = x -> string(round(x * 100; digits=1), "%")
        boxplot(transpose(ids), result_matrix,
            legend = false,
            xlabel=uppercasefirst(uticks) * "s",
            color = haskey(plotargs, :color) ? plotargs[:color] : gemscolors(1)[1],
            ylabel="Fraction of Infections",
            yformatter=formatter,
            fontfamily="Times Roman",
            dpi = 300)
    end

    if !isnothing(pid_filter)
        p = _boxplot_for_pid(pid_filter)
        plot!(p; plotargs...)
        return p
    end

    pids = sort(unique(vcat([unique(aggregated_compartment_periods(rd).pathogen_id) for rd in rds]...)))
    pnames = pathogen_names(rds[1])

    if length(pids) == 1
        p = _boxplot_for_pid(pids[1])
        plot!(p; plotargs...)
        return p
    end

    subplots = [begin
        p = _boxplot_for_pid(pid)
        plot!(p; title = get(pnames, pid, "Pathogen $pid"), remove_kw(:plot_title, plotargs)...)
        p
    end for pid in pids]
    return plot(subplots..., layout = (1, length(pids)), size = (500 * length(pids), 400); plotargs...)
end

function generate(plt::InfectionDuration, bd::BatchData; plotargs...)
    rep = median_run(bd)
    !isnothing(rep) && return generate(plt, rep; plotargs...)
    label_plts = _per_group_representative_plots(plt, bd; plotargs...)
    !isnothing(label_plts) && return label_plts
    r = runs(bd)
    isnothing(r) && error("InfectionDuration batch plots require per-run data. Re-run with median_by = pp -> nrow(infectionsDF(pp)) (the default) to plot the median run, or with keep_rundata = true to plot all runs.")
    generate(plt, r; plotargs...)
end
