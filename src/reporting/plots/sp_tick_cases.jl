export TickCases

###
### STRUCT
###

"""
    TickCases <: SimulationPlot

A simulation plot type for generating a new-cases-per-tick plot.
"""
@with_kw mutable struct TickCases <: SimulationPlot

    title::String = "Cases per Tick" # default title
    description::String = "" # default description empty
    filename::String = "cases_per_tick.png" # default filename

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
    generate(plt::TickCases, rd::ResultData; plotargs...)

Generates and returns a new-cases-per-tick plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TickCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `series::Union{Symbol, Vector{Symbol}} = [:exposed, :infectious, :removed, :deaths]` *(optional)*: Select one or multiple series (exposed, infectious, removed, deaths) to plot (not for multiplots).
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Tick Cases plot
"""
function generate(plt::TickCases, rd::ResultData; series::Union{Symbol, Vector{Symbol}} = [:exposed, :infectious, :removed, :deaths],
    pathogen = nothing, linewidth = 1, plotargs...)

    sers = typeof(series) == Symbol ? [series] : unique(copy(series))

    if isempty(sers)
        throw(ArgumentError("Provide at least one series (:exposed, :infectious, :removed, :deaths) to plot."))
    end

    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    title!(plt, "Cases per $upper_ticks")
    description!(plt, "This graph shows the number of new individuals entering any of the disease states per $uticks.")
    filename!(plt, "cases_per_$uticks.png")

    cases, pids, pnames, colors = _pathogen_setup(tick_cases(rd), rd, pathogen)
    multi = length(pids) > 1

    # linestyles cycle through series when multiple pathogens share an axes
    styles = Dict(:exposed => :solid, :infectious => :dash, :removed => :dot, :deaths => :dashdot)

    plot_ticks = plot(xlabel=upper_ticks, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")

    for pid in pids
        sub = filter(row -> row.pathogen_id == pid, cases)
        c = colors[pid]
        pfx = multi ? pnames[pid] * " — " : ""

        :exposed in sers && plot!(plot_ticks, sub.tick, sub[!, "exposed_cnt"],
            label = pfx * "Exposed",
            color = multi ? c : :blue,
            linestyle = multi ? styles[:exposed] : :solid,
            linewidth = linewidth)

        :infectious in sers && plot!(plot_ticks, sub.tick, sub[!, "infectious_cnt"],
            label = pfx * "Became Infectious",
            color = c,
            linestyle = multi ? styles[:infectious] : :solid,
            linewidth = linewidth)

        :removed in sers && plot!(plot_ticks, sub.tick, sub[!, "recovered_cnt"],
            label = pfx * "Recovered",
            color = c,
            linestyle = multi ? styles[:removed] : :solid,
            linewidth = linewidth)

        :deaths in sers && plot!(plot_ticks, sub.tick, sub[!, "dead_cnt"],
            label = pfx * "Died",
            color = multi ? c : :black,
            linestyle = multi ? styles[:deaths] : :solid,
            linewidth = linewidth)
    end

    unknown = filter(s -> s ∉ [:exposed, :infectious, :removed, :deaths], sers)
    !isempty(unknown) && @warn "Series $(unknown) cannot be plotted."

    plot!(plot_ticks; plotargs...)

    return(plot_ticks)
end


"""
    generate(plt::TickCases, rds::Vector{ResultData}; plotargs...)

Generates and returns a plot for the new-cases-per-tick for a provided vector of `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TickCases`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Tick Cases multi plot
"""
function generate(plt::TickCases, rds::Vector{ResultData}; pathogen = nothing, plotargs...)

    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    p = plot(xlabel=upper_ticks, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")

    pid_filter = _resolve_pathogen_id(rds[1], pathogen)

    if !isnothing(pid_filter)
        p = plotseries!(p, rd -> filter(row -> row.pathogen_id == pid_filter, tick_cases(rd))[!, "exposed_cnt"], rds; plotargs...)
    else
        pids = sort(unique(vcat([unique(tick_cases(rd).pathogen_id) for rd in rds]...)))
        pnames = pathogen_names(rds[1])
        colors = Dict(zip(pids, gemscolors(length(pids))))
        n = length(rds)
        for pid in pids
            labeled = false
            for rd in rds
                sub = filter(row -> row.pathogen_id == pid, tick_cases(rd))
                isempty(sub) && continue
                plot!(p, sub.tick, sub[!, "exposed_cnt"],
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

function generate(plt::TickCases, bd::BatchData; pathogen = nothing, plotargs...)
    uticks = get(sim_data(bd), "tick_unit", "tick")
    p = plot(xlabel = uppercasefirst(uticks), ylabel = "Individuals", dpi = 300, fontfamily = "Times Roman")
    tc = tick_cases(bd)
    pnames = pathogen_names(bd)
    pids = _batch_pids(tc, pnames, pathogen)
    colors = Dict(zip(pids, gemscolors(length(pids))))
    for pid in pids
        pid8 = Int8(pid)
        lbl = length(pids) > 1 ?
            get(pnames, pid8, "Pathogen $pid") * " (mean ± 95% CI)" :
            "Exposed (mean ± 95% CI)"
        _plot_labelled_ribbon!(p, bd, "tick_cases", lbl;
            col_key = "exposed_cnt", pathogen_id = pid8,
            color = length(pids) > 1 ? colors[pid] : nothing, plotargs...)
    end
    plot!(p; plotargs...)
    return p
end
