export WeeklyIncidenceMap

###
### STRUCT
###

"""
    WeeklyIncidenceMap <: MapPlot

A map that shows the incidence per week.
"""
@with_kw mutable struct WeeklyIncidenceMap <: MapPlot

    title::String = "7-Day Incidence per 100,000" # dfault title
    description::String = "" # default description empty
    filename::String = "Weekly_incidence_per_county.png" # default filename

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
    generate(plt::WeeklyIncidenceMap, sim::Simulation; level::Int = 3, plotargs...)

Generates and returns a map showing the weekly incidence per county for a provided simulation object.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::WeeklyIncidenceMap`: `MapPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Weekly incidence per county map
"""
function generate(plt::WeeklyIncidenceMap, rd::ResultData; level::Int = 2, week::Int = 0, plotargs...)
    
    if rd |> weekly_county_incidence |> isempty
        @warn "This ResultData oject does not contain the data necessary to geneate this map. Generate the RD-object using e.g., the 'DefaultResultData' style."
        return emptyplot("Required data not in ResultData object.")
    end

    if level != 2
        @warn "The Weekly County Incidence Map can only be generated on county level (2). Keyword argument level = $level will be ignored."
    end


    return weekly_county_incidence(rd) |>
        df -> DataFrames.select(df, :ags, Symbol("week_$week")) |>
        df -> agsmap(df,
            title = "Week $week",
            ytickfontsize = 12,
            fontfamily = "Times Roman";
            plotargs...)
end