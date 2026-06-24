export HospitalOccupancy

###
### STRUCT
###

"""
    HospitalOccupancy <: SimulationPlot

A simulation plot type for generating a plot with hospitalization numbers etc.
"""
@with_kw mutable struct HospitalOccupancy <: SimulationPlot

    title::String = "Hospital Occupancy" # default title
    description::String = "" # default description empty
    filename::String = "hospital_occupancy.png" # default filename

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

# generates one hospital-occupancy subplot for a single pathogen's data
function _hospital_subplot(h_df, utick_str; plotargs...)
    p = plot(xlabel=uppercasefirst(utick_str), ylabel="Individuals", dpi=300, fontfamily = "Times Roman")
    plot!(h_df.tick, h_df.current_hospitalized, label = "Hospitalized")
    plot!(h_df.tick, h_df.current_ventilation, label = "Ventilated")
    plot!(h_df.tick, h_df.current_icu, label = "ICU")
    plot!(p; plotargs...)
    return p
end

"""
    generate(plt::HospitalOccupancy, rd::ResultData; plotargs...)

Generates a plot of the number of hospitalized, ventilated and ICU admitted agents for each tick.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::HospitalOccupancy`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `pathogen::Union{Nothing, Int8, Integer, AbstractString} = nothing` *(optional)*: Filter to a single pathogen by id or name. Default shows all pathogens as subplots.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Hospital Occupancy plot
"""
function generate(plt::HospitalOccupancy, rd::ResultData; pathogen = nothing, plotargs...)
    uticks = rd |> tick_unit |> uppercasefirst

    h_all, pids, pnames, _ = _pathogen_setup(tick_hosptitalizations(rd), rd, pathogen)

    if length(pids) == 1
        h_df = filter(row -> row.pathogen_id == pids[1], h_all)
        desc = "This graph shows the number of currently hospitalized, ventilated and ICU admitted "
        desc *= "agents per $uticks for each of the setting types included in the simulation.\n"
        desc *= "The maximum number of hospitalized agents is $(maximum(h_df.current_hospitalized)) "
        desc *= "which occured on $uticks $(h_df.tick[argmax(h_df.current_hospitalized)])."
        description!(plt, desc)
        return _hospital_subplot(h_df, uticks; plotargs...)
    end

    subplots = [_hospital_subplot(
        filter(row -> row.pathogen_id == pid, h_all), uticks;
        _pathogen_subargs(pid, pnames, plotargs)...) for pid in pids]
    return _multi_pathogen_plot(subplots, plotargs)
end
