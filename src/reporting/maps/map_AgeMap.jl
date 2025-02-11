export AgeMap

###
### STRUCT
###

"""
    AgeMap <: MapPlot

A map that shows the average age per region.
"""
@with_kw mutable struct AgeMap <: MapPlot

    title::String = "Average Age per Region" # dfault title
    description::String = "" # default description empty
    filename::String = "average_age_per_region.png" # default filename

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
    generate(plt::AgeMap, sim::Simulation; level::Int = 3, plotargs...)

Generates and returns a map showing the average age per region for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::AgeMap`: `MapPlot` struct with meta data (i.e. title, description, and filename)
- `sim::Simulation`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Average age map
"""
function generate(plt::AgeMap, sim::Simulation; level::Int = 3, plotargs...)
    
    if all(isunset.(ags.(sim |> households)))
        # return default emptyplot if no AGS data available
        return emptyplot("The households in the provided simulation object are not geolocalized.")
    end

    # prepare data
    return DataFrame(
            ags = (i -> ags(household(i, sim))).(sim |> individuals),
            age = age.(sim |> individuals)) |>
        x -> prepare_map_df!(x, level = level) |>
        x -> groupby(x, :ags) |>
        x -> combine(x, :age => mean => :age) |>
        
        # generate map
        x -> agsmap(x,
            level = level,
            fontfamily = "Times Roman",
            clims = (0, 100);
            plotargs...)
end