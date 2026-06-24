export EffectiveReproduction

###
### STRUCT
###

"""
    EffectiveReproduction <: SimulationPlot

A simulation plot type for generating an effective reproduction number plot.
"""
@with_kw mutable struct EffectiveReproduction <: SimulationPlot

    title::String = "Effective Reproduction Number" # default title
    description::String = "" # default description empty
    filename::String = "effective_r.png" # default filename

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
    generate(plt::EffectiveReproduction, rd::ResultData; plotargs...)

Generates a plot for the effective reproduction number per tick.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::EffectiveReproduction`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Effective Reproduction Number plot
"""
function generate(plt::EffectiveReproduction, rd::ResultData; pathogen = nothing, linewidth = 1, plotargs...)

    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    desc  = "The effective reproduction number is calculated by counting all infections that "
    desc *= "are caused by an infected individual A after its infection at time T. The "
    desc *= "statistics are added to the $uticks of A's initial infection (T) although the actual "
    desc *= "infections might happen at a later $uticks. "
    desc *= "The visualized data is a 7-$uticks rolling average."
    description!(plt, desc)

    eff_r, pids, pnames, colors = _pathogen_setup(effectiveR(rd), rd, pathogen)
    multi = length(pids) > 1

    plot_eff_R = plot(xlabel=upper_ticks * "s", ylabel="Effective R", reuse = false, dpi=300, fontfamily = "Times Roman")

    for pid in pids
        sub = filter(row -> row.pathogen_id == pid, eff_r)
        c = colors[pid]
        pfx = multi ? pnames[pid] * " — " : ""
        plot!(plot_eff_R, sub.tick, sub[!, "rolling_R"],
            linewidth = linewidth, label = pfx * "(7-$uticks Rolling) Effective R", color = c)
        if !multi
            plot!(plot_eff_R, sub.tick, sub[!, "rolling_in_hh_R"],
                linewidth = linewidth, label = "(7-$uticks Rolling) Effective R (In Households)")
            plot!(plot_eff_R, sub.tick, sub[!, "rolling_out_hh_R"],
                linewidth = linewidth, label = "(7-$uticks Rolling) Effective R (Outside Households)")
        end
    end

    hline!(plot_eff_R, [1], linewidth=1, linestyle=:dash, linecolor = :red, label="R=1")

    plot!(plot_eff_R; plotargs...)

    return(plot_eff_R)
end


"""
    generate(plt::EffectiveReproduction, rds::Vector{ResultData}; plotargs...)

Generates a plot for the effective reproduction number per tick for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::EffectiveReproduction`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Effective Reproduction Number multi plot
"""
function generate(plt::EffectiveReproduction, rds::Vector{ResultData}; pathogen = nothing, plotargs...)

    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    p = plot(xlabel=upper_ticks, ylabel="(7-$uticks Rolling) Effective R", dpi=300, fontfamily = "Times Roman")

    pid_filter = _resolve_pathogen_id(rds[1], pathogen)

    if !isnothing(pid_filter)
        plotseries!(p, rd -> filter(row -> row.pathogen_id == pid_filter, effectiveR(rd))[!, "rolling_R"], rds; plotargs...)
    else
        pids = sort(unique(vcat([unique(effectiveR(rd).pathogen_id) for rd in rds]...)))
        pnames = pathogen_names(rds[1])
        colors = Dict(zip(pids, gemscolors(length(pids))))
        n = length(rds)
        for pid in pids
            labeled = false
            for rd in rds
                sub = filter(row -> row.pathogen_id == pid, effectiveR(rd))
                isempty(sub) && continue
                plot!(p, sub.tick, sub[!, "rolling_R"],
                    color = colors[pid],
                    label = labeled ? nothing : get(pnames, pid, "Pathogen $pid"),
                    alpha = 0.2 + 0.8 / n,
                    linewidth = 2)
                labeled = true
            end
        end
    end

    hline!(p, [1], linewidth=1, linestyle=:dash, linecolor = :red, label="R=1")

    plot!(p; plotargs...)

    return(p)
end

function generate(plt::EffectiveReproduction, bd::BatchData; pathogen = nothing, plotargs...)
    uticks = get(sim_data(bd), "tick_unit", "tick")
    p = plot(xlabel = uppercasefirst(uticks), ylabel = "(7-$uticks Rolling) Effective R", dpi = 300, fontfamily = "Times Roman")
    er = effectiveR(bd)
    pnames = pathogen_names(bd)
    pids = _batch_pids(er, pnames, pathogen)
    colors = Dict(zip(pids, gemscolors(length(pids))))
    for pid in pids
        pid8 = Int8(pid)
        lbl = length(pids) > 1 ?
            get(pnames, pid8, "Pathogen $pid") * " (mean ± 95% CI)" :
            "Effective R (mean ± 95% CI)"
        _plot_labelled_ribbon!(p, bd, "effectiveR", lbl;
            col_key = "rolling_R", pathogen_id = pid8,
            color = length(pids) > 1 ? colors[pid] : nothing, plotargs...)
    end
    hline!(p, [1], linewidth = 1, linestyle = :dash, linecolor = :red, label = "R=1")
    plot!(p; plotargs...)
    return p
end
