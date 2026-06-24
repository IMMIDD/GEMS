export HouseholdAttackRate

###
### STRUCT
###

"""
    HouseholdAttackRate <: SimulationPlot

A simulation plot type for generating a household-attack-rate plot.
"""
@with_kw mutable struct HouseholdAttackRate <: SimulationPlot

    title::String = "In-Household Attack Rate" # default title
    description::String = "" # default description empty
    filename::String = "household_attack_rate.png" # default filename

    # indicates to which package the result plot belongs
    # is used to parallelize report generation and prevents
    # concurrent generation of plots from the same package
    # if you don't know the origin package or if the function
    # returns different plot types depending on the input,
    # just put ":other" which will trigger sequential generation
    package::Symbol = :Plots

end

###
### PLOT GENERATION
###

function _hh_attack_rate_panel(har_sub, rd; ar_only::Bool = false, markersize = 5, plotargs...)
    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst
    ft = rd |> final_tick

    mean_hh_AR = groupby(har_sub, :hh_size) |>
        x -> combine(x, :hh_attack_rate => mean => :mean_hh_attack_rate)

    mean_hh_AR_over_time = groupby(har_sub, :first_introduction) |>
        x -> combine(x, :hh_attack_rate => mean => :mean_hh_attack_rate)

    mean_hh_size_over_time = groupby(har_sub, :first_introduction) |>
        x -> combine(x, :hh_size => mean => :mean_hh_size)

    hhs_ar = scatter(
        mean_hh_AR.hh_size,
        mean_hh_AR.mean_hh_attack_rate,
        xlims = (0, 15), ylims = (0, 1), xticks = (1:1:15),
        markersize = markersize, markerstrokewidth=0,
        label = "Attack rate and household sizes",
        xlabel = "Household Size", ylabel = "Mean Attack Rate",
        fontfamily = "Times Roman")

    if ar_only
        return plot!(hhs_ar; plotargs...)
    end

    time_ar = plot(
        mean_hh_AR_over_time.first_introduction,
        mean_hh_AR_over_time.mean_hh_attack_rate,
        xlims = (0, ft), ylims = (0, 1),
        label = "Avg. attack rate \n at first infection",
        xlabel = upper_ticks * "s", ylabel = "Mean Attack Rate")

    timem_hhs = plot(
        mean_hh_size_over_time.first_introduction,
        mean_hh_size_over_time.mean_hh_size,
        xlims = (0, ft),
        label = "Avg. size of households \n at first infection",
        xlabel = upper_ticks * "s", ylabel = "Mean Household Size")

    l = @layout [a ; b c]
    p = plot(hhs_ar, time_ar, timem_hhs,
        layout = l, ylabelfontsize = 10, xlabelfontsize = 10)
    plot!(p; plotargs...)
    return p
end

"""
    generate(plt::HouseholdAttackRate, rd::ResultData; plotargs...)

Generates and returns a household-attack-rate plot for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.
However, be aware that the keyword arguments might be applied to each of the subplots individually.

# Parameters

- `plt::HouseholdAttackRate`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `ar_only::Bool = false` *(optional)*: If `true`, only the attack rate plot will be returned, otherwise a multi-plot with attack rate and household size over time.
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Household Attack Rate plot
"""
function generate(plt::HouseholdAttackRate, rd::ResultData; ar_only::Bool = false,
    pathogen = nothing, markersize = 5, plotargs...)

    desc = "This graph shows the in-household attack rates stratified by household size and over time. "
    desc *= "The in-household attack rate is defined as the fraction of individuals in a given household "
    desc *= "that got infected within the household (in-household infection chain) caused by the *first* "
    desc *= "introduction of the pathogen in this household. It does *not* reflect *overall* fraction of "
    desc *= "individuals that were infected in this household throughout the course of the simulation."
    description!(plt, desc)

    har_all, pids, pnames, _ = _pathogen_setup(household_attack_rates(rd), rd, pathogen)

    subplots = [_hh_attack_rate_panel(
        filter(row -> row.pathogen_id == pid, har_all), rd;
        ar_only, markersize,
        (length(pids) > 1 ? _pathogen_subargs(pid, pnames, plotargs) : NamedTuple(plotargs))...)
        for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs; width_per_plot = 700, height = ar_only ? 300 : 500)
end


"""
    generate(plt::HouseholdAttackRate, rds::Vector{ResultData}; plotargs...)

Generates and returns a household-attack-rate plot for a vector of provided `ResultData` objects.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.
However, be aware that the keyword arguments might be applied to each of the subplots individually.

# Parameters

- `plt::HouseholdAttackRate`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Household Attack Rate multi plot
"""
function generate(plt::HouseholdAttackRate, rds::Vector{ResultData}; pathogen = nothing, plotargs...)

    pid_filter = _resolve_pathogen_id(rds[1], pathogen)

    function _scatter_for_pid(pid)
        labels = map(label, rds) |> unique
        colors = Dict(zip(labels, gemscolors(length(labels))))
        data = []
        for rd in rds
            har = filter(row -> row.pathogen_id == pid, household_attack_rates(rd))
            push!(data,
                groupby(har, :hh_size) |>
                    x -> combine(x, :hh_attack_rate => mean => :mean_hh_attack_rate) |>
                    x -> transform(x, :hh_size => ByRow(_ -> label(rd)) => :label) |>
                    x -> transform(x, :label => ByRow(l -> (haskey(plotargs, :color) ? plotargs[:color] : colors[l])) => :color)
            )
        end
        data = vcat(data...)
        means = groupby(data, [:hh_size, :label]) |>
            x -> combine(x, :mean_hh_attack_rate => mean => :total_mean)
        p = scatter(data.hh_size, data.mean_hh_attack_rate,
            group = data.label, color = data.color, markerstrokecolor = data.color,
            alpha = 0.7, xlims = (0, 15), ylims = (0, 1), xticks = (1:1:15),
            xlabel = "Household Size", ylabel = "Mean Attack Rate")
        for lab in labels
            plot!(p,
                means.hh_size[means.label .== lab],
                means.total_mean[means.label .== lab],
                color = haskey(plotargs, :color) ? plotargs[:color] : colors[lab],
                linewidth = 1.5, alpha = .5, label = "Mean of $lab")
        end
        plot!(p; plotargs...)
        return p
    end

    if !isnothing(pid_filter)
        return _scatter_for_pid(pid_filter)
    end

    pids = sort(unique(vcat([unique(household_attack_rates(rd).pathogen_id) for rd in rds]...)))
    pnames = pathogen_names(rds[1])

    length(pids) == 1 && return _scatter_for_pid(pids[1])

    subplots = [begin
        p = _scatter_for_pid(pid)
        plot!(p; title = get(pnames, pid, "Pathogen $pid"), _remove_kw(:plot_title, plotargs)...)
        p
    end for pid in pids]
    return plot(subplots..., layout = (1, length(pids)), size = (600 * length(pids), 400); plotargs...)
end

function generate(plt::HouseholdAttackRate, bd::BatchData; plotargs...)
    rep = median_run(bd)
    !isnothing(rep) && return generate(plt, rep; plotargs...)
    label_plts = _per_group_representative_plots(plt, bd; plotargs...)
    !isnothing(label_plts) && return label_plts
    r = runs(bd)
    isnothing(r) && error("HouseholdAttackRate batch plots require per-run data. Re-run with median_by = pp -> nrow(infectionsDF(pp)) (the default) to plot the median run, or with keep_rundata = true to plot all runs.")
    generate(plt, r; plotargs...)
end
