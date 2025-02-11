export InfectionMap

###
### STRUCT
###

"""
    InfectionMap <: SimulationPlot

A simulation plot type for generating an infection map.
"""
@with_kw mutable struct InfectionMap <: SimulationPlot

    title::String = "Infection Map" # default title
    description::String = "" # default description empty
    filename::String = "infection_map.png" # default filename

    # indicates to which package the result plot belongs
    # is used to parallelize report generation and prevents
    # concurrent generation of plots coming from the same package
    # if you don't know the origin package or if the function
    # returns different plot types depending on the input, 
    # just put ":other" which will trigger sequential generation
    package::Symbol = :GEMS
end

###
### PLOT GENERATION
###

"""
    generate(plt::InfectionMap, rd::ResultData; plotargs...)

Generates a map of the infections if geodata is provided. If more than the maximum
of allowed data points is given (lookup `MAX_MAP_POINTS` in `constants.jl`), a
sample of size `MAX_MAP_POINTS` is taken from the original data for visualization.

The current implementation does not offer the option for additional keyworded arguments.
The `plotargs...` argument is just a placeholder.

# Parameters

- `plt::InfectionMap`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: PLACEHOLDER. Currently not implemented.

# Returns

- `GMTWrapper`: Custom struct containing the storage location of the generated map
"""
function generate(plt::InfectionMap, rd::ResultData; plotargs...)

    # print a warning if any custom plotarg was passed
    length(plotargs) > 0 ? @warn("The InfectionMap plot does currently not accept any additional keyworded arguments. Your keyword arguments will be ignored") : nothing

    # filter for all infections with geolocations
    coords = rd |> infections |>
        x -> DataFrames.select(x, :lat, :lon) |>
        x -> filter(row -> (!any(isnan, row)), x)

    # if there're no coordinates, return empty map
    if coords |> isempty
        desc  = "There is no geodata in this ResultData object which can have multiple reasons. "
        desc *= "(1) The population model does not contain any geodata (e.g. household locations with latitude/longitude pairs). "
        desc *= "(2) If no infections happen during the simulation, there are no infection locations to be plotted. "

        description!(plt, desc)

        plot_empty = plot(
            xlabel="", 
            ylabel="", 
            legend=false, 
            fontfamily="Times Roman",
            dpi = 300)
        plot!([], [], annotation=(0.5, 0.5, Plots.text("The ResultData object does not contain any geodata.", :center, 10, :black, "Times Roman")), 
        fontfamily="Times Roman",
        dpi = 300)
        return(plot_empty)
    end

    # else, plot map.
    # if there're more data points than are being allowed in 'MAX_MAP_POINTS', sample data
    if nrow(coords) > MAX_MAP_POINTS
        coords = coords[sample(1:nrow(coords), MAX_MAP_POINTS, replace=false), :]
    end

    # make sure, temp folder exists
    mkpath(TEMP_FOLDER_PATH)
    path = joinpath(TEMP_FOLDER_PATH, filename(plt))

    inf_map = generate_map(coords, path)

    # generate map
    return(inf_map)
end
