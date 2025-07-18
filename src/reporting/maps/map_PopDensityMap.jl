export PopDensityMap

###
### STRUCT
###

"""
    PopDensityMap <: MapPlot

A map that shows the population density per region.
"""
@with_kw mutable struct PopDensityMap <: MapPlot

    title::String = "Population Density per Region" # dfault title
    description::String = "" # default description empty
    filename::String = "populaton_density.png" # default filename

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
    generate(plt::PopDensityMap, sim::Simulation; level::Int = 3, plotargs...)

Generates and returns a map showing the population density per region for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::PopDensityMap`: `MapPlot` struct with meta data (i.e. title, description, and filename)
- `sim::Simulation`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Population density map
"""
function generate(plt::PopDensityMap, sim::Simulation; level::Int = 3, plotargs...)
    
    if isnothing(sim |> municipalities)
        # return default emptyplot if no municipalities available
        return emptyplot("There are no municipalities in this simulation.")
    end

    if all(isunset.(ags.(sim |> municipalities)))
        # return default emptyplot if no AGS data available
        return emptyplot("The municipalities in the provided simulation object are not geolocalized.")
    end

    # transform data
    region_info(sim) |>
        # filter missing regions
        x -> x[.!ismissing.(x.area) .&& x.area .!= 0, :] |>    
        x -> prepare_map_df!(x, level = level) |>
        x -> groupby(x, :ags) |>
        x -> combine(x, 
            :pop_size => sum => :pop_size,
            :area => sum => :area) |>
        x -> transform(x, [:pop_size, :area] => ByRow((p, a) -> log10(p/a)) => :log_density) |>
        x -> DataFrames.select(x, [:ags, :log_density]) |>

        # generate map
        x -> agsmap(x,
            #title="Individuals/km²",
            colorbar_title = "Individuals/km² on Logarithmic Scale (Base 10)",
            clims = (minimum(x.log_density) * 0.9, maximum(x.log_density) * 1.05),
            fontfamily = "Times Roman";
            plotargs...)
end