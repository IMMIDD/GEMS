export MapPlot
export region_range
export generate_map

# shapefile maps
export agsmap, statemap, countymap, municipalitymap, prepare_map_df!

# gemsmap
export gemsmap

export maptypes

"""
    region_range(coords::DataFrame)

returns outer bound lat/lon for map plotting based in the provided
coordinates dataframe. Adds a padding as specified in `MAP_PADDING`
in constants.jl
"""
function region_range(coords::DataFrame)
    padding = MAP_PADDING

    # margins
    min_lat = minimum(coords.lat)
    max_lat = maximum(coords.lat)
    min_lon = minimum(coords.lon)
    max_lon = maximum(coords.lon)

    # lat/lon range
    lat_range = max_lat - min_lat
    lon_range = max_lon - min_lon

    # add padding
    min_lat = maximum([-90, min_lat - padding * lat_range])
    max_lat = minimum([90, max_lat + padding * lat_range])        
    min_lon = maximum([-180, min_lon - padding * lon_range])
    max_lon = minimum([180, max_lon + padding * lon_range])

    return([min_lon, max_lon, min_lat, max_lat])
end


"""
    generate_map(coords::DataFrame, dest::AbstractString; region = [], plotempty::Bool = false)

Generates a GMT map and stores it into the folder specified in `dest`.
The `coords` DataFrame must provide at least a `lat`- and a `lon`-column
specifying latitude and longitude data pairs.
The `region` parameter expects an array of four integer values providing the
outer bounds of the map according to `[min_lon, max_lon, min_lat, max_lat]`.
If no `region` parameter is passed, the bounds are taken from the lan/lon 
range provided in the `coords` data with a %-padding according to `MAP_PADDING`
defined in constants.jl . With the `plotempty` flag you can force to plot a map
without any data points.

# Parameters

- `coords::DataFrame`: Dataframe with `lat` and `lon` column
- `dest::AbstractString`: Storage location for the generated map
- `region = []` *(optional)*: four-item region vector defining the map limits in lat/lon min/max pairs
    (look up `GMT.jl` package to learn about regions)
- `plotempty::Bool = false` *(optional)*: Allows to plot an empty map if no data points are given

# Returns

- `GMTWrapper`: Custom struct containing the storage location of the generated map 

"""
function generate_map(coords::DataFrame, dest::AbstractString; region = [], plotempty::Bool = false)
    
    # catch empty dataframes
    if coords |> isempty && !plotempty
        throw("You passed an empty dataframe")
    end

    # catch empty region when force plotting
    if region |> isempty && plotempty
        throw("If you force an empty plot, you must specify a region")
    end

    # set up region framing based on passed data points
    r = region |> isempty ? region_range(coords) : region
        
    # put coordinates into data 
    data = [coords.lon coords.lat]
    
    try 
        GMT.gmtbegin(dest, fmt=:png)
            # Using coast to draw the geographic aspects
            GMT.coast(region=r, proj=:Mercator, shore=:thinnest, land=:white, borders=:a, #=rivers=(type=:a, pen=(0.25,:blue)),=# water=:lightblue, frame=:none)
            # only plot data, if data is there
            if data |> !isempty
                GMT.scatter(data, marker=:point, mc="#DC143C@70", show=true, markersize=0.03)
            end
            # Ends the modern mode session and actually outputs the plot
        GMT.gmtend(show=false);
    catch e 
        #@error e
    end

    if isfile(dest)
        return(
            GMTWrapper(dest)
        )
    else
        throw("Error while trying to generate GMT Map. File was not successfully created at $dest. Are you missing the '*.png?'")
    end
end


"""
    agsmap(df::DataFrame, level::Int64; plotargs...)

Returns a `Plot.js` plot with shapes of German states, counties, or municipalities.
The input dataframe `df` requires two columns. The first column needs to be named `ags`
and has to be a vector of `AGS` structs (Amtlicher Gemeindeschlüssel). The second
column needs to be a vector of numerical values which are used to color-code the map.
The `level` argument defines wether the map plots states (`level = 1`),
counties (`level = 2`) or municipalities (`level = 3`). Note that the `AGS` in the
dataframe must thus also be of the same geographic resolution. The optional
`plotargs...` are passed to the plot object. Please lookup the `Plots.jl`
package for more information about what arguments can be used to customize a plot.

# Parameters

- `df::DataFrame`: DataFrame with `ags`-named column that contains `AGS` structs and
    a second column with numerical values.
- `level::Int64`: Map resolution. states (`level = 1`), counties (`level = 2`) or municipalities (`level = 3`)
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Plot using the `Plots.jl` package's struct.

"""
function agsmap(df::DataFrame, level::Int64; plotargs...)
    # check if the dataframe has the right columns
    names(df)[1] != "ags" ? throw("The first column of the input dataframe must be named 'ags'.") : nothing
    typeof(df[:,1]) != Vector{AGS} ? throw("The first column of the input dataframe must contain a Vector of AGS structs") : nothing
    !(eltype(df[:,2]) <: Real) ? throw("The second column of the input dataframe must contain a Vector of numeric values") : nothing

    # check if all AGS are of the right level (state, county, municipality)
    level == 1 && sum(is_state.(df.ags)) != nrow(df) ? throw("The AGSs provided in the input dataframes are not all refering to states (level 1)") : nothing
    level == 2 && sum(is_county.(df.ags)) != nrow(df) ? throw("The AGSs provided in the input dataframes are not all refering to counties (level 2)") : nothing
    level == 3 && sum(is_district.(df.ags)) + sum(is_state.(df.ags)) > 0 ? throw("The AGSs provided in the input dataframes are not all refering to municipalities (level 3)") : nothing

    # check if all ags values are unique
    length(df.ags) != length(unique(df.ags)) ? throw("All AGS values need to be unique! There are duplicates in the input dataframe") : nothing

    # check if level is between 1 and 3
    !(1 <= level <= 3) ? throw("The level must be either 1 (States), 2 (Counties), or 3 (Municipalities)") : nothing

    # load shapefile for Germany
    shptable = germanshapes(level)

    # match input data with shapefile (based on AGS)
    shpdata = DataFrame(ags = AGS.(shptable.AGS_0), gen = shptable.GEN, geometry = shptable.geometry) |>
        x -> leftjoin(x, df, on = :ags) |>
        x -> filter(row -> !ismissing(row[4]), x)

    # build the plot
    p = plot(fillcolor=:reds, size = (1000,800), aspect_ratio = :equal, axis = false, grid = false) # default parameters
    plot!(p; plotargs...) # overwrite with argument parameters

    argdict = Dict(plotargs)
    for row in eachrow(shpdata)
        # there seems to be a fillcolor bug in Plots.js where the color is
        # not transferred to the shapes if it's not explicitly stated each
        # time a new shape is drawn. Thus, when fillcolor is provided, it's
        # forwarded to the individual shape calls here. The same applies 
        # to the linecolor

        # prepare keyword arguments for the plot! function
        kwargs = Dict{Symbol, Any}(:fill_z => row[4])
        if haskey(argdict, :fillcolor)
            kwargs[:fillcolor] = argdict[:fillcolor]
        end
        if haskey(argdict, :linecolor)
            kwargs[:linecolor] = argdict[:linecolor]

        end
        plot!(p, row.geometry; kwargs...)
    end

    return(p)
end


"""
    agsmap(df::DataFrame; plotargs...)

Wrapper for the agsmap function that infers the correct geographical
resolution (`level`) from the input dataframe. Please lookup the
`agsmap(df, level; plotargs...)` function's docstring for more information.
"""
function agsmap(df::DataFrame; plotargs...)
    # if level kw is passed, dispatch level-function and pass other arguments without level
    if haskey(plotargs, :level)
        agsmap(df, plotargs[:level]; remove_kw(:level, plotargs)...)
    end

    # if all states, call level 1 plot function
    if sum(is_state.(df.ags)) == nrow(df) return agsmap(df, 1; plotargs...) end

    # if all states, call level 2 plot function
    if sum(is_county.(df.ags)) == nrow(df) return agsmap(df, 2; plotargs...) end

    # else
    return agsmap(df, 3; plotargs...)
end


statemap(df::DataFrame; plotargs...) = agsmap(df, 1; plotargs...)
countymap(df::DataFrame; plotargs...) = agsmap(df, 2; plotargs...)
municipalitymap(df::DataFrame; plotargs...) = agsmap(df, 3; plotargs...)


"""
    prepare_map_df!(df::DataFrame; level::Int = 3)

Input `df` requires the format that can go into the `agsmap()` function. This means, at least
two columns, the first one being an `AGS` column called `ags` and a second column
with numerical values. The `level` argument converts the `AGS`s to the
desired geographical resolution: states (`level = 1`),
counties (`level = 2`) or municipalities (`level = 3`)

# Returns

- `DataFrame`: Adapted dataframe with desired `AGS` resolution in first column.
"""
function prepare_map_df!(df::DataFrame; level::Int = 3)
    names(df)[1] != "ags" ? throw("The first column of the input dataframe must be named 'ags'.") : nothing
    typeof(df[:,1]) != Vector{AGS} ? throw("The first column of the input dataframe must contain a Vector of AGS structs") : nothing

    # handle states
    if level == 1
        df.ags = state.(df.ags)
    end

    # handle counties
    if level == 2
        df.ags = county.(df.ags)
        df = df[is_county.(df.ags),:]
    end

    # handle municipalities
    if level == 3
        df = df[.!is_state.(df.ags),:]
    end

    return df
end

###
### MAP PLOTS
###


"Supertype for all maps that go into single-run simulation reports"
abstract type MapPlot <: ReportPlot end

"Abstract wrapper function for all map plots. Requires concrete implementation in subtypes"
function generate(plot::MapPlot, data)
    error("generate(...) is not defined for concrete map plot type $(typeof(plot))")
end

# The src/reporting/maps folder contains a dedicated file
# for each map plot. 
# If you want to set up a new map plot, simply add a file to the folder and 
# make sure to define the MapPlot-Struct and the generate() function.

# include all Julia files from the "plots"-folder
dir = basefolder() * "/src/reporting/maps/"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)


"""
    gemsmap(data; type = :nothing, level = 3, plotargs...)

Generates a geographical map of a desired `type`. Just pass the name of 
the map-type as a `Symbol` (must be exactly the same as the respective 
`SimulationPlot`-struct). The `data` argument mus be either a `Simulation`
object (used to map model-related features such as average household sizes
per region) or a `ResultData` object (used to map simulation-result-related
features such as the attack rate per region). Most of the maps that can be
generated also take the `level` argument that converts the `AGS`s to the
desired geographical resolution: states (`level = 1`), counties (`level = 2`)
or municipalities (`level = 3`).

# Parameters

- `data`: `Simulation` or `ResultData` object.
- `type = :nothing` *(optional)*: Map type (instantiates a map with the exact same struct name).
- `level = 3` *(optional)*: Desired geographical resolution: states (`level = 1`), counties (`level = 2`)
    or municipalities (`level = 3`)
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Map using the `Plots.jl` package's struct.

# Examples

Given that you have a simulation with geolocalized settings (available in the
predefined models accessible via the German state codes. e.g., "SH" for the 
northern-most state of "Schleswig-Holstein"), you can plot the average age per
region on a map like this:

```julia
sim = Simulation(population = "SH")
gemsplot(sim, type = :AgeMap)
```

If you want to change the resolution to counties, try:

```julia
sim = Simulation(population = "SH")
gemsplot(sim, type = :AgeMap, level = 2)
```

All `gemsmap`s can be nested and combined with any plot of the `Plots.jl`
package or `gemsplot`s:

```julia
using Plots
plot(
    gemsmap(sim, type = :AgeMap),
    gemsplot(rd, type = :TickCases)
)
```

# Map Types

| Type                   | Input Object | Description                                                | Plot-Specific Parameters                                                                                         |
| :--------------------- | :----------- | :--------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------- |
| `:AgeMap`              | `Simulation` | Average age per region.                                    |                                                                                                                  |
| `:AttackRate`          | `ResultData` | Fraction of people who got infected per region.            |                                                                                                                  |
| `:CaseFatalityMap`     | `ResultData` | Fraction of infections that led to death per region.       |                                                                                                                  |
| `:HouseholdSizeMap`    | `Simulation` | Average household size per region.                         | `max_size = 10`: Maximum size of households (default = 10) considered for this graph (to exclude large outliers) |
| `:PopDensityMap`       | `Simulation` | Population density per region.                             |                                                                                                                  |
| `:SinglesMap`          | `Simulation` | Fraction of single-person households per region.           |                                                                                                                  |

**Note:** Maps that use infection data (e.g., the `AttackRate`) use the individuals'
household location to map the data, not the loction of infection.

# Some Useful Keyword Arguments

Here are some examples of the `Plots.jl` package's keyword arguments that you can
also pass to the `gemsmap()` function and might find helpful:

- `clims = (0, 1)`: Setting the color bar range between 0 and 1
- `colorbar = false`: Disabling the colorbar
- `size = (300, 400)`: Resizing the map plot
- `title = "My Subtitle"`: Adding a subtitle
- `plot_title = "My New Title"`: Changing the map title
- `fillcolor = :blues`: Changing color scheme
- `linecolor = nothing`: Removing the outline of the map shapes

*Please consult the `Plots.jl` package documentation for a comprehensive list*

"""
function gemsmap(data::Union{Simulation, ResultData}; type = :nothing, plotargs...)

    # throw exception if type unknown
    !is_subtype(type, MapPlot) ? throw("There's no plot type that matches $type") : nothing

    plt = try 
        # instantiate plot
        # we go via the subtypes function as it evaluates the "known"
        # subtypes at runtime, not compilation time. This allows
        # to also add user-defined plots.
        get_subtype(type, MapPlot)()
    catch
        # throws exception if the plot type doesn't have a 0-argument constructor
        throw("$type plots cannot be create using the gemsmap-function as they require additional arguments in their constructor. Please use generate($type(args...), data) instead to generate this map.")
    end

    return generate(plt, data; plot_title = title(plt), plotargs...)

end


"""
    maptypes()

Returns a list of all map types that can be used for the `gemsmap()` function.
"""
maptypes() = Symbol.(subtypes(MapPlot))