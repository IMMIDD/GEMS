export MultiGenHouseholdMap

###
### STRUCT
###

"""
    MultiGenHouseholdMap <: MapPlot

A map that shows the the basic reproduction number per county.
"""
@with_kw mutable struct MultiGenHouseholdMap <: MapPlot

    title::String = "Mutli-Generational Households (50+ Year Age Difference)" # dfault title
    description::String = "" # default description empty
    filename::String = "multi_gen_households_map.png" # default filename

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
    generate(plt::MultiGenHouseholdMap, sim::Simulation; level::Int = 3, plotargs...)

Generates and returns a map showing the basic reproduction number per county for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::MultiGenHouseholdMap`: `MapPlot` struct with meta data (i.e. title, description, and filename)
- `sim::Simulation`: Input data used to generate plot
- `fit_lims::Bool = false` *(optional)*: If `true`, the color limits of the plot will be set to the minimum and maximum fraction of elderly people.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Percentage of multi-generational households (at least two people with 50+ years age differerence) per county map
"""
function generate(plt::MultiGenHouseholdMap, sim::Simulation; level::Int = 2, fit_lims::Bool = false, plotargs...)
    
    # helper function to evaluate if at least
    # two individuals in household are 50 years apart
    is_multigen(h) = age.(individuals(h)) |>
        a -> (maximum(a) - minimum(a) >= 50)

    if all(isunset.(ags.(sim |> households)))
        # return default emptyplot if no AGS data available
        return emptyplot("The households in the provided simulation object are not geolocalized.")
    end 

    return DataFrame(
            ags = ags.(households(sim)),
            multigen = is_multigen.(households(sim))) |>
        x -> prepare_map_df!(x, level = level) |>
        x -> groupby(x, :ags) |>
        x -> combine(x, :multigen => (m -> (100 * sum(m) / length(m))) => :multigen) |>
        # generate map
        x -> agsmap(x,
            fontfamily = "Times Roman",
            colorbar_title = "Percentage (%)",
            # if fit_lims is true, set clims to min and max of age
            clims = fit_lims ? (minimum(x.multigen), maximum(x.multigen)) : (0, 100);
            plotargs...)

end