export TickCasesBySetting

###
### STRUCT
###

"""
    TickCasesBySetting <: SimulationPlot

A simulation plot type for generating tick cases for each included setting type.
"""
@with_kw mutable struct TickCasesBySetting <: SimulationPlot

    title::String = "Infections per Tick for Each Setting" # default title
    description::String = "" # default description empty
    filename::String = "tick_cases_by_setting.png" # default filename

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

function _tick_cases_by_setting_subplot(data, utick; plotargs...)
    p = plot(xlabel=utick, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")
    for setting in sort(unique(data.setting_type))
        sub = filter(row -> row.setting_type == setting, data)
        sum(sub.daily_cases) != 0 && plot!(p, sub.tick, sub.daily_cases, label=settingstring(setting))
    end
    plot!(p; plotargs...)
    return p
end

"""
    generate(plt::TickCasesBySetting, rd::ResultData; plotargs...)

Generates a plot of tick cases for each included setting type.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TickCasesBySetting`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens as subplots.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Tick Cases By Setting plot
"""
function generate(plt::TickCasesBySetting, rd::ResultData; pathogen = nothing, plotargs...)

    utick = rd |> tick_unit |> uppercasefirst

    title!(plt, "Infections per $utick for each SettingType")
    desc = "This graph shows the number of newly infected individuals per $utick "
    desc *= "for each of the setting types included in the simulation."
    description!(plt, desc)

    all_data, pids, pnames, _ = _pathogen_setup(tick_cases_per_setting(rd), rd, pathogen)

    subplots = [_tick_cases_by_setting_subplot(
        filter(row -> row.pathogen_id == pid, all_data), utick;
        (length(pids) > 1 ? _pathogen_subargs(pid, pnames, plotargs) : NamedTuple(plotargs))...)
        for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs)
end
