export SinglesMap

###
### STRUCT
###

"""
    SinglesMap <: MapPlot

A map that shows the fraction of single-person households per region.
"""
@with_kw mutable struct SinglesMap <: MapPlot

    title::String = "Fraction of Single-Person Households" # dfault title
    description::String = "" # default description empty
    filename::String = "single_person_households.png" # default filename

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
    generate(plt::SinglesMap, sim::Simulation; level::Int = 3, plotargs...)

Generates and returns a map showing the fraction of single-person households for 
a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::SinglesMap`: `MapPlot` struct with meta data (i.e. title, description, and filename)
- `sim::Simulation`: Input data used to generate plot
- `fit_lims::Bool = false` *(optional)*: If `true`, the color limits of the plot will be set to the minimum and maximum fraction.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Fraction of single-person households map plot
"""
function generate(plt::SinglesMap, sim::Simulation; level::Int = 3, fit_lims::Bool = false, plotargs...)
    
    return ags.(sim |> households) |>
        # check if all of the AGS structs are unset/empty
        a -> ifelse(all(isunset.(a)),

            # return default emptyplot if no AGS data available
            emptyplot("The households in the provided simulation object are not geolocalized."),
            
            # build map otherwise
            DataFrame(ags = a, size = size.(sim |> households)) |>
                x -> prepare_map_df!(x, level = level) |>
                x -> groupby(x, :ags) |>
                x -> combine(x, :size => (x -> 100 * count(y -> y == 1, x) / length(x)) => :singles) |>
                x -> agsmap(x,
                    fontfamily = "Times Roman",
                    # if fit_lims is true, set clims to min and max of values
                    clims = fit_lims ? (minimum(x.singles), maximum(x.singles)) : (0, 100); 
                    plotargs...)
        )
end