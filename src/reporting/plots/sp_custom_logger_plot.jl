export CustomLoggerPlot

###
### STRUCT
###

"""
    CustomLoggerPlot <: SimulationPlot

A simulation plot type for generating a time series plot displaying values
stored in a `ResultData`s `CustomLogger` dataframe.
"""
@with_kw mutable struct CustomLoggerPlot <: SimulationPlot

    title::String = "Custom Logger" # default title
    description::String = "" # default description empty
    filename::String = "custom_logger.png" # default filename

    # indicates to which package the result plot belongs
    # is used to parallelize report generation and prevents
    # concurrent generation of plots coming from the same package
    # if you don't know the origin package or if the function
    # returns different plot types depending on the input, 
    # just put ":other" which will trigger sequential generation
    package::Symbol = :Plots
    
end

###
### PLOT GENERATION
###

"""
    generate(plt::CustomLoggerPlot, rd::ResultData; plotargs...)

Generates and returns a plot for the values contained in the custom logger of a `ResultData` object.
It will contain one individual plot per function that was passed to the custom logger.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.
However, be aware that the keyword arguments might be applied to each of the
subplots individually.

# Parameters

- `plt::CustomLoggerPlot`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Custom Logger Plot plot
"""
function generate(plt::CustomLoggerPlot, rd::ResultData; dates::Bool = true,  plotargs...)

    # data
    ticks = (rd |> customlogger).tick
    cl_data = rd |> customlogger |>
        x -> select(x, Not(:tick))

    # tickunits
    uticks = rd |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # generate one plot for each customlogger data
    plts = map(
        col -> plot(ticks, cl_data[!, col],
            xlabel = upper_ticks,
            ylabel = col,
            label = col,
            dpi = 300,
            fontfamily = "Times Roman")
        ,names(cl_data))

    
    p = plot(plts..., layout = (1, cl_data |> names |> length))
    plot!(p; plotargs...)
    # replace x-ticks with dates
    dates ? adddates!(p, rd) : nothing
    return p
end


"""
    generate(plt::CustomLoggerPlot, rds::Vector{ResultData}; plotargs...)

Generates and returns a plot for the values contained in the custom loggers of a provided vector of `ResultData` objects.
It will contain one individual plot per function that was passed to the custom logger.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::CumulativeIsolations`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rds::Vector{ResultData}`: Vector of input data objects used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Cumulative Isolations multi plot
"""
function generate(plt::CustomLoggerPlot, rds::Vector{ResultData}; dates::Bool = true,  plotargs...)

    # throw exception if rds-Vector is empty
    isempty(rds) ? throw("The passed ResultData vector is empty.") : nothing

    # check that all rds have same custom loggers
    cols = try
         map(rd -> rd |> customlogger |>
            x -> select(x, Not(:tick)) |> names, rds)
    catch
        throw("Not all passed ResultData objects have custom logger data")
    end

    # check if all cols have the same names
    ref = Set(cols[1])
    for c in cols
        Set(c) != ref ? throw("All ResultData objects need to have customloggers with the exact same column names (mismatch in $c and $(cols[1]))") : nothing
    end

    cols = cols[1]

    # tickunits
    uticks = rds[1] |> tick_unit
    upper_ticks = uticks |> uppercasefirst

    # generate one plot per column name in custom logger
    plts = []
    for col in cols     
        # generate a plot with data grouped by label
        p = plot(xlabel=upper_ticks,
            ylabel = col,
            label = col,
            dpi=300,
            fontfamily = "Times Roman")

        # generate a plot with data grouped by label
        p = plotseries!(p, rd -> customlogger(rd)[!,col], rds; plotargs...)
        push!(plts, p)
    end

    p = plot(plts..., layout = (1, length(cols)))

    # add custom arguments that were passed
    plot!(p; plotargs...)
    # replace x-ticks with dates
    dates ? adddates!(p, rd) : nothing

    return(p)
end