export ElderlyMap

###
### STRUCT
###

"""
    ElderlyMap <: MapPlot

A map that shows the the basic reproduction number per county.
"""
@with_kw mutable struct ElderlyMap <: MapPlot

    title::String = "Elderly Map (65+)" # dfault title
    description::String = "" # default description empty
    filename::String = "elderly_map.png" # default filename

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
    generate(plt::ElderlyMap, sim::Simulation; level::Int = 3, plotargs...)

Generates and returns a map showing the basic reproduction number per county for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::ElderlyMap`: `MapPlot` struct with meta data (i.e. title, description, and filename)
- `sim::Simulation`: Input data used to generate plot
- `fit_lims::Bool = false` *(optional)*: If `true`, the color limits of the plot will be set to the minimum and maximum fraction of elderly people.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Percentage of elderly (65+) per county map
"""
function generate(plt::ElderlyMap, sim::Simulation; level::Int = 2, fit_lims::Bool = false, plotargs...)
    
    if all(isunset.(ags.(sim |> households)))
        # return default emptyplot if no AGS data available
        return emptyplot("The households in the provided simulation object are not geolocalized.")
    end 

    return DataFrame(
            ags = (i -> ags(household(i, sim))).(sim |> individuals),
            age = age.(sim |> individuals)) |>
        x -> prepare_map_df!(x, level = level) |>
        x -> groupby(x, :ags) |>
        x -> combine(x, :age => (a -> (100 * sum(a .>= 65) / length(a))) => :elderly) |>
        x -> DataFrames.select(x, :ags, :elderly) |>
        # generate map
        x -> agsmap(x,
            fontfamily = "Times Roman",
            # if fit_lims is true, set clims to min and max of age
            colorbar_title = "Percentage (%)",
            clims = fit_lims ? (minimum(x.elderly), maximum(x.elderly)) : (0, 100);
            plotargs...)

end