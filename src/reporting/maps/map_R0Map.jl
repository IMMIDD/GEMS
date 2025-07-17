export R0Map

###
### STRUCT
###

"""
    R0Map <: MapPlot

A map that shows the the basic reproduction number per county.
"""
@with_kw mutable struct R0Map <: MapPlot

    title::String = "Basic Reproduction Number" # dfault title
    description::String = "" # default description empty
    filename::String = "r0_map.png" # default filename

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
    generate(plt::R0Map, rd::ResultData; level::Int = 3, plotargs...)

Generates and returns a map showing the basic reproduction number per county for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::R0Map`: `MapPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Basic reproduction number per county map
"""
function generate(plt::R0Map, rd::ResultData; level::Int = 2, plotargs...)
    
    if rd |> r0_per_county |> isempty
        @warn "This ResultData oject does not contain the data necessary to geneate this map. Generate the RD-object using e.g., the 'DefaultResultData' style."
        return emptyplot("Required data not in ResultData object.")
    end

    if level != 2
        @warn "The Weekly County Incidence Map can only be generated on county level (2). Keyword argument level = $level will be ignored."
    end


    return r0_per_county(rd) |>
        df -> agsmap(df,
            ytickfontsize = 12,
            fontfamily = "Times Roman";
            plotargs...)
end