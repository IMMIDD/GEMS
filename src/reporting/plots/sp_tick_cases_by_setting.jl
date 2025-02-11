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

"""
    generate(plt::TickCasesBySetting, rd::ResultData; plotargs...)

Generates a plot of tick cases for each included setting type.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::TickCasesBySetting`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Tick Cases By Setting plot
"""
function generate(plt::TickCasesBySetting, rd::ResultData; plotargs...)
    
    # Assume this function exists to get the daily cases by setting
    # The returned DataFrame might have columns: "tick", "school", "office", ...
    tick_cases_data = rd |> tick_cases_per_setting
    
    # Get unique setting types 
    unique_settings = unique(tick_cases_data.setting_type) 
    
    # Determine the tickunit to use it for the xlabel
    uticks = rd |> tick_unit |> uppercasefirst

    # add title
    title!(plt, "Infections per $uticks for each SettingType")

    # add description
    desc = "This graph shows the number of newly infected individuals per $uticks "
    desc *= "for each of the setting types included in the simulation."
    description!(plt, desc)

    p = plot(xlabel=uticks, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")

    for setting in unique_settings
        subset_df = filter(row -> row.setting_type == setting, tick_cases_data)
        # Plot the setting if there are any cases to be plotted
        if sum(subset_df.daily_cases) != 0
            plot!(p, subset_df.tick, subset_df.daily_cases, label=settingstring(setting))
        end 
    end

    # add custom arguments that were passed
    plot!(p; plotargs...)

    return p
end