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

"""
    generate(plt::HospitalOccupancy, rd::ResultData; plotargs...)

Generates a plot of the number of hospitalized, ventilated and ICU admitted agents for each tick.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::HospitalOccupancy`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Hospital Occupancy plot
"""
function generate(plt::HospitalOccupancy, rd::ResultData; plotargs...)
    # Get Hospital DataFrame
    h_df = rd |> hospital_df

    # Determine the tickunit to use it for the xlabel
    uticks = rd |> tick_unit |> uppercasefirst

    # add description
    desc = "This graph shows the number of currently hosiptalized, ventialted and ICU admitted "
    desc *= "agents per $uticks for each of the setting types included in the simulation.\n"
    desc *= "The maximum number of hospitalized agents is $(maximum(h_df.current_hospitalized)) "
    desc *= "which occured on $uticks $(h_df.tick[argmax(h_df.current_hospitalized)]).\n"
    desc *= "The maximum number of ventilated agents is $(maximum(h_df.current_ventilation)) "
    desc *= "which occured on $uticks $(h_df.tick[argmax(h_df.current_ventilation)]).\n"
    desc *= "The maximum number of ICU admitted agents is $(maximum(h_df.current_icu)) "
    desc *= "which occured on $uticks $(h_df.tick[argmax(h_df.current_icu)])."
    description!(plt, desc)

    p = plot(xlabel=uticks, ylabel="Individuals", dpi=300, fontfamily = "Times Roman")

    plot!(h_df.tick, h_df.current_hospitalized, label = "Hospitalized")
    plot!(h_df.tick, h_df.current_ventilation, label ="Ventilated")
    plot!(h_df.tick, h_df.current_icu, label ="ICU")

    # add custom arguments that were passed
    plot!(p; plotargs...)

    return p
end