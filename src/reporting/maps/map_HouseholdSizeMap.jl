export HouseholdSizeMap

###
### STRUCT
###

"""
    HouseholdSizeMap <: MapPlot

A map that shows the average household size per region.
"""
@with_kw mutable struct HouseholdSizeMap <: MapPlot

    title::String = "Average Household Size per Region" # dfault title
    description::String = "" # default description empty
    filename::String = "average_household_size_per_region.png" # default filename

    # indicates to which package the map plot belongs
    # is used to parallelize report generation and prevents
    # concurrent generation of plots coming from the same package
    # if you don't know the origin package or if the function
    # returns different plot types depending on the input, 
    # just put ":other" which will trigger sequential generation
    package::Symbol = :Plots
end

###
### MAP GENERATION
###

"""
    generate(plt::HouseholdSizeMap, sim::Simulation; level::Int = 3, plotargs...)

Generates and returns a map showing the average household size per region for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::AgeMap`: `MapPlot` struct with meta data (i.e. title, description, and filename)
- `sim::Simulation`: Input data used to generate plot
- `max_size::Int64 = 10` *(optional)*: Maximum size of households considered for this graph (to exclude large outliers)
- `fit_lims::Bool = false` *(optional)*: If `true`, the color limits of the plot will be set to the minimum and maximum household size values.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Average household size map
"""
function generate(plt::HouseholdSizeMap, sim::Simulation; level::Int = 3, max_size::Int64 = 10, fit_lims::Bool = false, plotargs...)
    
    return ags.(sim |> households) |>
        # check if all of the AGS structs are unset/empty
        a -> ifelse(all(isunset.(a)),

            # return default emptyplot if no AGS data available
            emptyplot("The households in the provided simulation object are not geolocalized."),
            
            # build map otherwise
            DataFrame(ags = a, size = size.(sim |> households)) |>
                x -> x[x.size .<= max_size, :] |>
                x -> prepare_map_df!(x, level = level) |>
                x -> groupby(x, :ags) |>
                x -> combine(x, :size => mean => :size) |>
                x -> agsmap(x,
                    level = level,
                    fontfamily = "Times Roman",
                    clims = fit_lims ? (minimum(x.size), maximum(x.size)) : (0, 5); # if fit_lims is true, set clims to min and max of size
                    plotargs...)
        )
end