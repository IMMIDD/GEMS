export AttackRateMap

###
### STRUCT
###

"""
    AttackRateMap <: MapPlot

A map that shows the fraction of individuals that got infected at least one time per region.
The region code (AGS) is taken from the individuals' household location, not the location of infection.
"""
@with_kw mutable struct AttackRateMap <: MapPlot

    title::String = "Attack Rate" # dfault title
    description::String = "" # default description empty
    filename::String = "attack_rate.png" # default filename

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
    generate(plt::AttackRateMap, sim::Simulation; level::Int = 3, plotargs...)

Generates and returns a map showing the fraction of individuals that got infected
at least one time for a provided `ResultData` object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::AttackRateMap`: `MapPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `fit_lims::Bool = false` *(optional)*: If `true`, the color limits of the plot will be set to the minimum and maximum fraction.
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Attack rate map plot
"""
function generate(plt::AttackRateMap, rd::ResultData; level::Int = 3, fit_lims::Bool = false, plotargs...)

    # if no raw infections data is in RD object
    if rd |> infections |> isempty
        @warn "This ResultData oject does not contain the raw infections data which is necessary to geneate this map. Generate the RD-object using e.g., the 'DefaultResultData' style."
        return emptyplot("Required data not in ResultData object.")
    end

    # if no raw infections data is in RD object
    if rd |> region_info |> isempty
        @warn "This ResultData oject does not contain geodata. The reason might be that you're using a model that isn't geolocalized or an RD-Style that doesn't contain the 'region_info' dataframe,. In that case, try using the 'DefaultResultData' style."
        return emptyplot("Required data not in ResultData object.")
    end

    # if RD doesn't contain geolocalized data
    ags = (rd |> infections).ags
    if length(ags[ags .== -1]) == length(ags)
        return emptyplot("Infections in the ResultData object are not geolocalized.")
    end

    # for now, we can only do this on level 3
    level != 3 ? (@warn "This map can only be generated on municipality level (3). Your input ($level) will be ignored.") : nothing

    # build map (level 3)
    return rd |> infections |>
        x -> DataFrames.select(x, :id_b, :household_ags_b => :ags) |>
        x -> unique(x, [:id_b, :ags]) |>
        x -> groupby(x, :ags) |>
        x -> combine(x, nrow => :reg_infs) |>
        x -> leftjoin(region_info(rd), x, on = :ags) |>
        x -> transform(x, :reg_infs => ByRow(x -> coalesce(x, 0)) => :reg_infs) |>
        x -> transform(x, [:reg_infs, :pop_size] => ByRow((i, n) -> 100 * i/n) => :attack_rate) |>
        x -> DataFrames.select(x, :ags, :attack_rate) |>
        x -> agsmap(x,
            fontfamily = "Times Roman",
            colorbar_title = "Percentage (%)",
            clims = fit_lims ? (minimum(x.attack_rate), maximum(x.attack_rate)) : (0, 100); 
            plotargs...)
end