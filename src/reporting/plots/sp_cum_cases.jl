export CumulativeCases

###
### STRUCT
###

"""
    CumulativeCases <: SimulationPlot

A simulation plot type for generating a cumulative infections plot.
"""
@with_kw mutable struct CumulativeCases <: SimulationPlot

    title::String = "Cumulative Cases" # default title
    description::String = "" # default description empty
    filename::String = "cumulative_cases.png" # default filename

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
    generate(plt::CumulativeCases, rd::ResultData; plotargs...)

Generates and returns a cumulative infections plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::CumulativeCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Cumulative Cases plot
"""
function generate(plt::CumulativeCases, rd::ResultData; pathogen = nothing, plotargs...)

    xlab = (rd |> tick_unit |> uppercasefirst) * "s"

    desc = "This graph shows the cumulative number of infections, recoveries, and deaths "
    desc *= "for each $(rd |> tick_unit) during the simulation."
    description!(plt, desc)

    cum_cases, pids, pnames, colors = _pathogen_setup(cumulative_cases(rd), rd, pathogen)
    multi = length(pids) > 1

    styles = Dict("exposed_cum" => :solid, "recovered_cum" => :dash, "deaths_cum" => :dot)

    plot_cum = plot(xlabel=xlab, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")

    for pid in pids
        sub = filter(row -> row.pathogen_id == pid, cum_cases)
        c = colors[pid]
        pfx = multi ? pnames[pid] * " — " : ""
        plot!(plot_cum, sub.tick, sub[!, "exposed_cum"],
            label = pfx * "Infections",
            color = c, linestyle = styles["exposed_cum"])
        plot!(plot_cum, sub.tick, sub[!, "recovered_cum"],
            label = pfx * "Recoveries",
            color = c, linestyle = styles["recovered_cum"])
        plot!(plot_cum, sub.tick, sub[!, "deaths_cum"],
            label = pfx * "Deaths",
            color = multi ? c : :black,
            linestyle = styles["deaths_cum"])
    end

    plot!(plot_cum; plotargs...)

    return(plot_cum)
end


"""
    generate(plt::CumulativeCases, rds::Vector{ResultData}; plotargs...)

Generates and returns a cumulative infections plot for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...`
that are available in the `Plots.jl` package.

# Parameters

- `plt::CumulativeCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Cumulative Cases multi plot
"""
function generate(plt::CumulativeCases, rds::Vector{ResultData}; pathogen = nothing, plotargs...)

    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    p = plot(xlabel=upper_ticks, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")

    pid_filter = _resolve_pathogen_id(rds[1], pathogen)

    if !isnothing(pid_filter)
        p = plotseries!(p, rd -> filter(row -> row.pathogen_id == pid_filter, cumulative_cases(rd))[!, "exposed_cum"], rds; plotargs...)
    else
        pids = sort(unique(vcat([unique(cumulative_cases(rd).pathogen_id) for rd in rds]...)))
        pnames = pathogen_names(rds[1])
        colors = Dict(zip(pids, gemscolors(length(pids))))
        n = length(rds)
        for pid in pids
            labeled = false
            for rd in rds
                sub = filter(row -> row.pathogen_id == pid, cumulative_cases(rd))
                isempty(sub) && continue
                plot!(p, sub.tick, sub[!, "exposed_cum"],
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

function generate(plt::CumulativeCases, bd::BatchData; pathogen = nothing, plotargs...)
    uticks = get(sim_data(bd), "tick_unit", "tick")
    p = plot(xlabel = uppercasefirst(uticks), ylabel = "Individuals", dpi = 300, fontfamily = "Times Roman")
    cc = cumulative_cases(bd)
    pnames = pathogen_names(bd)
    pids = _batch_pids(cc, pnames, pathogen)
    colors = Dict(zip(pids, gemscolors(length(pids))))
    for pid in pids
        pid8 = Int8(pid)
        lbl = length(pids) > 1 ?
            get(pnames, pid8, "Pathogen $pid") * " (mean ± 95% CI)" :
            "Cumulative Exposed (mean ± 95% CI)"
        _plot_labelled_ribbon!(p, bd, "cumulative_cases", lbl;
            col_key = "exposed_cum", pathogen_id = pid8,
            color = length(pids) > 1 ? colors[pid] : nothing, plotargs...)
    end
    plot!(p; plotargs...)
    return p
end
