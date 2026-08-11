export CaseFatalityMap

###
### STRUCT
###

"""
    CaseFatailityMap <: MapPlot

A map that shows the fraction of infections that led to death time per region.
"""
@with_kw mutable struct CaseFatalityMap <: MapPlot

    title::String = "Case Fataility" # dfault title
    description::String = "" # default description empty
    filename::String = "case_fatality_map.png" # default filename

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
    generate(plt::CaseFatalityMap, sim::Simulation; level::Int = 3, plotargs...)

Generates and returns a map showing the fraction of infecftions that led to death
for a provided `ResultData` object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::CaseFatalityMap`: `MapPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Case fatality map plot
"""
function generate(plt::CaseFatalityMap, rd::ResultData; level::Int = 3, plotargs...)

    # if no raw infections data is in RD object
    if rd |> infections |> isempty
        @warn "This ResultData oject does not contain the raw infections data which is necessary to geneate this map. Generate the RD-object using e.g., the 'DefaultResultData' style."
        return emptyplot("Required data not in ResultData object.")
    end

    # if no raw deaths data is in RD object
    if rd |> deaths |> isempty
        @warn "This ResultData oject does not contain the raw deaths data which is necessary to geneate this map. Generate the RD-object using e.g., the 'DefaultResultData' style."
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
    #level != 3 ? (@warn "This map can only be generated on municipality level (3). Your input ($level) will be ignored.") : nothing

    # distinct hosts on both sides: a per-host case fatality rate
    infected_hosts = rd |> infections |>
        x -> DataFrames.select(x, :household_ags_b => :ags, :id_b) |>
        x -> prepare_map_df(x, level = level) |>
        x -> groupby(x, :ags) |>
        x -> combine(x, :id_b => (h -> length(unique(h))) => :reg_infs)

    dead_hosts = rd |> deaths |>
        x -> DataFrames.select(x, :household_ags => :ags, :id) |>
        x -> prepare_map_df(x, level = level) |>
        x -> groupby(x, :ags) |>
        x -> combine(x, :id => (h -> length(unique(h))) => :reg_deaths)

    # build map (level 3)
    return leftjoin(infected_hosts, dead_hosts, on = :ags) |>
        x -> transform(x, :reg_deaths => ByRow(d -> coalesce(d, 0)) => :reg_deaths) |>
        x -> transform(x, [:reg_deaths, :reg_infs] => ByRow((d, i) -> 100 * d/i) => :case_fatality_rate) |>
        x -> DataFrames.select(x, :ags, :case_fatality_rate) |>
        x -> agsmap(x,
            fontfamily = "Times Roman",
            #clims = (0, 1);
            ;plotargs...)
end