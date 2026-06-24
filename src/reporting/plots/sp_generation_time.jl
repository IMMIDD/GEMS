export GenerationTime

###
### STRUCT
###

"""
    GenerationTime <: SimulationPlot

A simulation plot type for generating a generation-time-per-tick.
"""
@with_kw mutable struct GenerationTime <: SimulationPlot

    title::String = "Generation Time" # default title
    description::String = "" # default description empty
    filename::String = "generation_time.png" # default filename

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
    generate(plt::GenerationTime, rd::ResultData; plotargs...)

Generates and returns a generation-time-per-tick plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::GenerationTime`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Generation Time plot
"""
function generate(plt::GenerationTime, rd::ResultData; pathogen = nothing, plotargs...)

    uticks = rd |> tick_unit

    desc = "This graph shows the generation time which is defined as the "
    desc *= "duration (in $(uticks)s) between an index person's exposure and the exposure of its immediate "
    desc *= "predecessor in an infection chain. For any current infection event, it shows how many $(uticks)s before "
    desc *= "the _infecting_ agent was exposed to the pathogen himself."
    description!(plt, desc)

    gt_all, pids, pnames, colors = _pathogen_setup(tick_generation_times(rd), rd, pathogen)
    multi = length(pids) > 1

    plot_gt = plot(xlabel=uppercasefirst(uticks)*"s", ylabel="Generation Time ($(uppercasefirst(uticks))s)", dpi=300, fontfamily = "Times Roman")

    for pid in pids
        data = filter(row -> row.pathogen_id == pid, gt_all) |> dropmissing
        isempty(data) && continue
        c = colors[pid]
        pfx = multi ? pnames[pid] * " — " : ""
        if !multi
            # show full range and std band for single pathogen
            plot!(plot_gt, data[!, "min_generation_time"], fillrange = data[!, "max_generation_time"], label = "Range", alpha=0.2)
            plot!(plot_gt, data[!, "mean_generation_time"] .- data[!, "std_generation_time"],
                fillrange = data[!, "mean_generation_time"] .+ data[!, "std_generation_time"],
                label="+/- 1 Std. Deviation", alpha=0.4)
            plot!(plot_gt, data[!, "mean_generation_time"], label = "Mean", linewidth = 2)
        else
            plot!(plot_gt, data.tick, data[!, "mean_generation_time"],
                label = pfx * "Mean", color = c, linewidth = 2)
        end
    end

    plot!(plot_gt; plotargs...)

    return(plot_gt)
end


"""
    generate(plt::GenerationTime, rds::Vector{ResultData}; plotargs...)

Generates and returns a plot for the mean generation-time-per-tick for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::GenerationTime`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Generation Time multi plot
"""
function generate(plt::GenerationTime, rds::Vector{ResultData}; pathogen = nothing, plotargs...)

    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    p = plot(xlabel=upper_ticks, ylabel="Mean Gen. Time ($(upper_ticks)s)", dpi=300, fontfamily = "Times Roman", xlims = (0, rds[1] |> final_tick))

    pid_filter = _resolve_pathogen_id(rds[1], pathogen)

    if !isnothing(pid_filter)
        p = plotseries!(p, rd -> begin
            sub = filter(row -> row.pathogen_id == pid_filter, tick_generation_times(rd)) |> dropmissing
            sub[!, "mean_generation_time"]
        end, rds; plotargs...)
    else
        pids = sort(unique(vcat([unique(tick_generation_times(rd).pathogen_id) for rd in rds]...)))
        pnames = pathogen_names(rds[1])
        colors = Dict(zip(pids, gemscolors(length(pids))))
        n = length(rds)
        for pid in pids
            labeled = false
            for rd in rds
                sub = filter(row -> row.pathogen_id == pid, tick_generation_times(rd)) |> dropmissing
                isempty(sub) && continue
                plot!(p, sub.tick, sub[!, "mean_generation_time"],
                    color = colors[pid],
                    label = labeled ? nothing : get(pnames, pid, "Pathogen $pid"),
                    alpha = 0.2 + 0.8 / n,
                    linewidth = 2)
                labeled = true
            end
        end
    end

    plot!(p; plotargs...)

    return(p)
end

function generate(plt::GenerationTime, bd::BatchData; pathogen = nothing, plotargs...)
    uticks = get(sim_data(bd), "tick_unit", "tick")
    upper_ticks = uppercasefirst(uticks)
    p = plot(xlabel = upper_ticks, ylabel = "Mean Gen. Time ($(upper_ticks)s)", dpi = 300, fontfamily = "Times Roman")
    gt = generation_times(bd)
    pnames = pathogen_names(bd)
    pids = _batch_pids(gt, pnames, pathogen)
    colors = Dict(zip(pids, gemscolors(length(pids))))
    for pid in pids
        pid8 = Int8(pid)
        lbl = length(pids) > 1 ?
            get(pnames, pid8, "Pathogen $pid") * " (mean ± 95% CI)" :
            "Mean Gen. Time (mean ± 95% CI)"
        _plot_labelled_ribbon!(p, bd, "generation_times", lbl;
            pathogen_id = pid8,
            color = length(pids) > 1 ? colors[pid] : nothing, plotargs...)
    end
    plot!(p; plotargs...)
    return p
end
