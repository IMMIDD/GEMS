# CREATION OF PLOTS AND FIGURES FOR THE REPORT
export ReportPlot, SimulationPlot, BatchPlot, GMTWrapper
export title, description, description!, filename, filename!, generate
export fontfamily!, dpi!, title!, titlefontsize!, saveplot, emptyplot
export gemsplot
export plottypes, splitlabel, splitplot, plotseries!

###
### ABSTRACT HIERARCHY & TYPES
###

"Supertype for all plots that go into reports"
abstract type ReportPlot end

"Supertype for all plots that go into single-run simulation reports"
abstract type SimulationPlot <: ReportPlot end

"Supertype for all plots that go into batch-run simulation reports"
abstract type BatchPlot <: ReportPlot end

"""
    GMTWrapper

Wrapper-struct to inform saveplot function about 
the existance of a GMT-generated plot in the 
temp-folder (`path_to_map`).
"""
struct GMTWrapper
    path_to_map::String
end


"Abstract wrapper function for all simulation report plots. Requires concrete implementation in subtypes"
function generate(plot::SimulationPlot, rd::ResultData)
    error("generate(...) is not defined for concrete report plot type $(typeof(plot))")
end

# dispatch BatchData to internal vector of ResultData
generate(plot::SimulationPlot, bd::BatchData; plotargs...) = generate(plot, runs(bd); plotargs...)

###
### COMMON FUNCTIONS
###

"""
    title(plot::ReportPlot)

Returns title from report plot object.
"""
function title(plot::ReportPlot)
    return(plot.title)
end

"""
    title!(plot::ReportPlot, title::String)

Setter for report plot title.
"""
function title!(plot::ReportPlot, title::String)
    plot.title = title
end

"""
    description(plot::ReportPlot)

Return description from report plot object.
"""
function description(plot::ReportPlot)
    return(plot.description)
end

"""
    description!(plot::ReportPlot, description::String)

Setter for report plot description.
"""
function description!(plot::ReportPlot, description::String)
    plot.description = description
end

"""
    filename(plot::ReportPlot)

Return filename from report plot object.
"""
function filename(plot::ReportPlot)
    return(plot.filename)
end

"""
    filename!(plot::ReportPlot, filename::String)

Setter for report plot filename.
"""
function filename!(plot::ReportPlot, filename::String)
    plot.filename = filename
end

"""
    emptyplot(message::String)

Returns an empty plot with the argument message as a text overlay.
This can be used as a default for plot-generate()-functions, if no
data is available in the `ResultData` object.
"""
function emptyplot(message::String)
    eplt = plot(
        xlabel="", 
        ylabel="", 
        legend=false, 
        fontfamily="Times Roman",
        dpi = 300)
    plot!([], [], annotation=(0.5, 0.5, Plots.text(message, :center, 10, :black, "Times Roman")), 
    fontfamily="Times Roman",
    dpi = 300)
    return(eplt)
end


function fontfamily!(plot::Plots.Plot, fontfamily::String)
    ff = fontfamily
    # What Pandoc calls "Times New Roman" is "Times Roman" in Plots. Hence the conversion
    plot!(plot, fontfamily = cmp(ff, "Times New Roman") == 0 ? "Times Roman" : ff)
end


function fontfamily!(plot::VegaLite.VLSpec, fontfamily::String)
    println("Custom fontfamily cannot be set for VegaLite plots")
end


function dpi!(plot::Plots.Plot, dpi::Int)
    plot!(plot, dpi = dpi)
end


function dpi!(plot::VegaLite.VLSpec, dpi::Int)
    println("Custom dpi cannot be set for VegaLite plots")
end


title!(plot::Plots.Plot, title::String) = plot!(plot, title = title)
titlefontsize!(plot::Plots.Plot, size::Int) = plot!(plot, titlefontsize = size)
   


###
### EXPORT PLOTS TO HARDDRIVE
###

"""
    saveplot(plot::Plots.Plot, path::AbstractString)

Stores a plot from the juliaplots package to the provided path.
"""
function saveplot(plot::Plots.Plot, path::AbstractString)
    png(plot, path)
end

"""
    saveplot(plot::VegaLite.VLSpec, path::AbstractString)

Stores a plot from the VegaLite package to the provided path.
"""
function saveplot(plot::VegaLite.VLSpec, path::AbstractString)
    plot |> FileIO.save(path)
end

"""
    saveplot(plot::GMTWrapper, path::AbstractString)

Copies a GMT plot from the temp folder into the provided path (removes the temporary file).
"""
function saveplot(plot::GMTWrapper, path::AbstractString)
    mv(plot.path_to_map, path, force = true)
end


###
### COMMON PLOTTING INTERFACE
###

"""
    
    gemsplot(rd::ResultData; type::Symbol = :nothing, plotargs...)
    gemsplot(bd::BatchData; type::Symbol = :nothing, combined::Symbol = :all, plotargs...)
    gemsplot(rd::Vector{ResultData}; type::Symbol = :nothing, combined::Symbol = :all, plotargs...)
   
Facilitates the usage of GEMS' inbuilt plots. Just pass the name of the plot-type
 as a `Symbol` (must be exactly the same as the respective `SimulationPlot`-struct).
The `plotargs...` can be any keyworded argument that is available in
the standard `Plots.jl` package.

You can pass a `ResultData` object to get a plot for one simulation run or even
pass a vector of `ResultData` objects or even a `BatchData` object. Passing data
of multiple simulation runs (`ResultData`-vector or `BatchData`) will generate
the respective plot with the data of all simulation runs inside. E.g., the
`:TickCases` plot will show one line for each run. Simulations with the same
`label` attribute will be grouped using the same color.

The keyword `combined` (only applicable for `ResultData`-vectors or `BatchData`-objects)
determines whether all data is combined in a single plot (`:all`), each simulation
run gets its own subplot (`:single`), or the plots are separated by label (`:bylabel`).
**Note:** There might be plots without a multi-plot implementation. They will
always be printed as if `combined = :single` was passed. Check the table below
to see which plots are available for single- and multiplots.

# Parameters

- `rd/bd`: Data object to plot. Can be `ResultData`, `Vector{ResultData}` or `BatchData`
- `type = :nothing` *(optional)*: Plot type (instantiates a plot with the exact same struct name).
    You can pass a tuple of plots to generate one graph with multiple visualizations
- `combined::Symbol = :all` *(optional)*: all data in one plot (`:all`), all individual plots (`:singe`),
    plot separated by label (`:bylabel`).
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Plot using the `Plots.jl` package's struct.

# Examples

Given that `rd` is a valid `ResultData` object that came out of a simulation,
you can plot a summary like this:

```julia
gemsplot(rd)
```

If you want a specific plot, say the cases-per-tick plot, try this and add a custom title:

```julia
gemsplot(rd, type = :TickCases, title = "My Tick Case Plot")
```

You can also generate multiple plots in one figure like so:

```julia
gemsplot(rd, type = (:CompartmentFill, :EffectiveReproduction), layout = (2,1))
```

The `layout` keyword makes the plots appear on top of each other in stead of side-by-side.

Generate a multi-plot for a vector of `ResultData` objects and separate plots by label like so:

```julia
# assuming you have a baseline, and a lockdown scenario with two simulation runs each.
# the simulations of these ResultData objects must have the same label ("Baseline" and "Lockdown") to group them
rds = [rd_baseline_1, rd_baseline_2, rd_lockdown_1, rd_lockdown_2]
gemsplot(rds, type = :EffectiveReproduction, combined = :bylabel)
```

# Plot Types

The following plot types can be generated using the `gemsplot()` function.
The mutli-plot column describes which plots can work with `ResultData`-vector or `BatchData`-objects.
Some of the plots have keyword arguments that are only applicable to that very plot.

| Type                             | Description                                                                           | Multi-Plot | Plot-Specific Parameters                                                                                                                       |
| :------------------------------- | :------------------------------------------------------------------------------------ | :--------- | :--------------------------------------------------------------------------------------------------------------------------------------------- |
| `:ActiveDarkFigure`              | Fraction of current infections per tick that are "known"/detected at that tick.       | Yes        |                                                                                                                                                |
| `:AggregatedSettingAgeContacts`  | Age-X-Age contact matrix for all setting types in the simulation (e.g., `Household`). | No         | `settingtype::DataType`: Filter for specific setting type (e.g., `Household`), `show_values::Bool`: Enable or disable printed values in cells. |
| `:CompartmentFill`               | Current number of individuals per compartment (classic SEIR curves).                  | No         |                                                                                                                                                |
| `:CumulativeCases`               | Summed-up cases over time.                                                            | Yes        |                                                                                                                                                |
| `:CumulativeDiseaseProgressions` | Number of people in a certain disease state at a given tick after their exposure.     | No         |                                                                                                                                                |
| `:CumulativeIsolations`          | Number of currently isolated individuals over time.                                   | Yes        | `series::Symbol`: Filter for `:workers`, `:students`, `:other`, or `:all`                                                                      |
| `:CustomLoggerPlot`              | CustomLogger values. One subplot per logging function in the multi-plot variant.      | Yes        |                                                                                                                                                |
| `:DetectedCases`                 | New detected cases per time step.                                                     | No         |                                                                                                                                                |
| `:EffectiveReproduction`         | Effective reproduction number (R_eff) over time.                                      | Yes        |                                                                                                                                                |
| `:GenerationTime`                | Mean generation time over time.                                                       | Yes        |                                                                                                                                                |
| `:HospitalOccupancy`             | Number of hospitalized, ventilated, and ICU-admitted indivudual over time.            | No         |                                                                                                                                                |
| `:HouseholdAttackRate`           | In-Household attack rate per household size.                                          | Yes        |                                                                                                                                                |
| `:Incidence`                     | Indicende over time by 10-year age group (stacked chart).                             | No         |                                                                                                                                                |
| `:InfectionDuration`             | Histogram of total infection durations.                                               | Yes        |                                                                                                                                                |
| `:InfectiousHistogram`           | Histogram of infectious period duratons.                                              | No         |                                                                                                                                                |
| `:LatencyHistogram`              | Histogram of latency period durations.                                                | No         |                                                                                                                                                |
| `:ObservedReproduction`          | Observed rffective reproduction number (R_eff) over time (based on detected cases).   | No         |                                                                                                                                                |
| `:ObservedSerialInterval`        | Observed serial interval (SI) over time (based on detected cases).                    | No         |                                                                                                                                                |
| `:PopulationPyramid`             | Population Pyramid by age and sex.                                                    | No         |                                                                                                                                                |
| `:SettingSizeDistribution`       | Histograms of setting sizes for all setting types (e.g., `Household`s)                | No         |                                                                                                                                                |
| `:SymptomCategories`             | Heatmap of the fraction of symptom categories (asymptomatic, mild, severe...) by age. | No         |                                                                                                                                                |
| `:TestPositiveRate`              | Fraction of all performed tests that were positive per test type (e.g., `PCR`).       | No         |                                                                                                                                                |
| `:TickCases`                     | New cases per time step. For single sim. also with new infectious, removed, dead.     | Yes        |                                                                                                                                                |
| `:TickCasesBySetting`            | New cases stratified by setting type (e.g., `Household` or `Office`)                  | No         |                                                                                                                                                |
| `:TickTests`                     | Performed tests per time step, including positive and total tests and reported cases. | No         |                                                                                                                                                |
| `:TimeToDetection`               | Average time between exposure and detected for all infections over time.              | No         |                                                                                                                                                |
| `:TotalTests`                    | Total number of performed tests per test type (e.g., `PCR`)                           | Yes        |                                                                                                                                                |

# Some Useful Keyword Arguments

Here are some examples of the `Plots.jl` package's keyword arguments that you can
also pass to the `gemsplot()` function and might find helpful:

    - `xlims = (0, 100)`: Setting the X-axis range between 0 and 100
    - `ylims = (0, 200)`: Setting the Y-axis range between 0 and 200
    - `size = (300, 400)`: Resizing the plot
    - `plot_title = "My New Title"`: Changing the plot title
    - `xlabel = "New X-label"`: Changing the x-axis label
    - `ylabel = "New Y-label"`: Changing the y-axis label
    - `legend = :topright`: Changing the legend position (`false` to disable)
    - `aspect_ratio = :equal`: Having the axis of equal size

*Please consult the `Plots.jl` package documentation for a comprehensive list*

"""
function gemsplot(rd::Vector{ResultData}; type = :nothing, combined::Symbol = :all, plotargs...)

    # handle empty inputs
    isempty(rd) ? throw("The ResultData vector cannot be empty") : nothing

    ### RECURSIVE CALLS
    # if no type was passed, print the default plot (R, cases, and SEIR)
    if type == :nothing
        return gemsplot(rd,
            type = (:TickCases, :CumulativeCases, :EffectiveReproduction),
            #layout = (3, 1),
            titlefontsize = 10,
            size = (600, 800); combined = combined, plotargs...)
    end

    # if multiple types were passed
    if isa(type, Tuple{Vararg{Symbol}})
        p = plot(((t -> gemsplot(rd, type = t; combined = combined, plotargs...)).(type))...,
            titlefontsize = 12,
            plot_titlefontsize = 12,
            labelfontsize = 8,
            layout = (length(type), 1),
            size = (600, 250 * length(type)),
            bottom_margin = 4Plots.mm)
        plot!(p, ; plotargs...)
        return p
    end

    # SINGLE PLOTTING
    # throw exception if type unknown
    type ∉ Symbol.(subtypes(SimulationPlot)) ? throw("There's no plot type that matches $type") : nothing

    # get index in subtype list
    i = findfirst(x -> x == type, Symbol.(subtypes(SimulationPlot)))

    plt = try 
        # instantiate plot
        # we go via the subtypes function as it evaluates the "known"
        # subtypes at runtime, not compilation time. This allows
        # to also add user-defined plots.
        subtypes(SimulationPlot)[i]()
    catch
        # throws exception if the plot type doesn't have a 0-argument constructor
        throw("$type plots cannot be create using the gemsplot-function as they require additional arguments in their constructor. Please use generate($type(args...), rd) instead to generate this plot.")
    end

    # actually generate plot

    # if one RD was passed
    if length(rd) == 1
        return generate(plt, rd[1]; plot_title = title(plt), plotargs...)
    end

    # if multiple RDs were passed and plot has a multi-RD implementation, call that.
    # if not, build a multiplot with one plot per RD object
    if hasmethod(generate, (typeof(plt), Vector{ResultData}))

        # handle combined keyword
        # generate individual plots if :single is passed
        if combined == :single
            p = splitplot(plt, rd; plot_title = title(plt), titlefontsize = 10, plotargs...)
        # separate plots by label if :bylabel is passed
        elseif combined == :bylabel
            p = splitlabel(plt, rd; plot_title = title(plt), titlefontsize = 10, plotargs...)
        # default is a combined plot of everything
        else
            p = generate(plt, rd; plot_title = title(plt), titlefontsize = 10, plotargs...)
        end
    else
        # NOTE: THIS WILL NOW ONLY WORK WITH PLOTS FROM THE PLOTS.JS PACKAGE
        p = splitplot(plt, rd; plot_title = title(plt), titlefontsize = 10, plotargs...)
    end

    return p
end


# further dispatching
gemsplot(rd::ResultData; plotargs...) = gemsplot([rd]; plotargs...)
gemsplot(bd::BatchData; plotargs...) = gemsplot(bd |> runs; plotargs...)


"""
    plottypes()

Returns a list of all plot types that can be used for the `gemsplot()` function.
"""
plottypes() = Symbol.(subtypes(SimulationPlot))

"""
    splitplot(plt::SimulationPlot, rds::Vector{ResultData}; plotargs...)

Returns a split side-by-side plot for multiple `ResultData` objects.

# Parameters

- `plt::SimulationPlot`: Simulation plot struct (e.g. `TickCases()`)
- `rds::Vector{ResultData}`: Vector of `ResultData` objects to plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Plot using the `Plots.jl` package's struct.
"""
splitplot(plt::SimulationPlot, rds::Vector{ResultData}; plotargs...) = plot((map(rd -> generate(plt, rd, title = label(rd); remove_kw(:plot_title, plotargs)...), rds))...; plotargs...)


"""
    splitlabel(plt::SimulationPlot, rds::Vector{ResultData}; plotargs...)

Returns a split side-by-side plot for multiple `ResultData` objects
but groups simulation runs by label. If you have 2 scenarios with 10
simulation runs each, this function will generate two plots with
10 data series each.

- `plt::SimulationPlot`: Simulation plot struct (e.g. `TickCases()`)
- `rds::Vector{ResultData}`: Vector of `ResultData` objects to plot
    (requires the `rd` objects to have the `label` attribute)
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Plot using the `Plots.jl` package's struct.
"""
function splitlabel(plt::SimulationPlot, rds::Vector{ResultData}; plotargs...)

    labels = map(label, rds) |> unique
    colors = Dict(zip(labels, palette(:auto, length(labels))))
    data = Dict(zip(labels, [Vector{ResultData}() for _ in 1:length(labels)]))

    # sort data by label
    for rd in rds
        push!(data[label(rd)], rd)
    end

    # generate one plot for each label
    plts = [generate(plt, rd,
                title = lab,
                color = colors[lab];
                remove_kw(:plot_title, plotargs)...) for (lab, rd) in data]
    return plot(plts..., plot_title = title(plt), layout = (1, length(labels)); plotargs...)
end

"""
    plotseries!(p::Plots.Plot, extract_function::Function, rds::Vector{ResultData}; plotargs...)

Extends a plot and adds data grouped by the labels of the `ResultData` objects.
The `extract_function` argument must be a one-argument function that
is the called with a single `ResultData` object. It must return the
data series that should be plotted.

# Parameters

- `p::Plots.Plot`: Input plot object to extend
- `extract_function::Function`: One-argument lambda function that will be called with
    each of the `ResultData` objects in the input vector. This function must return 
    a vector of numberical values that is being added as a line series to input plot `p`.
- `rds::Vector{ResultData}`: Vector of `ResultData` objects to plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Plot using the `Plots.jl` package's struct.

# Example

This code generates a plot of the effective reproduction number
with one line per `ResultData` object and grouped by `label`.

```julia
p = plotseries!(plot(), rd -> effectiveR(rd)[!,"rolling_R"], rds)
```

"""
function plotseries!(p::Plots.Plot, extract_function::Function, rds::Vector{ResultData}; plotargs...)

    # prepare colors & data per label
    # read labels from result data vector
    labels = map(label, rds) |> unique
    colors = Dict(zip(labels, palette(:auto, length(labels))))
    data = Dict(zip(labels, [[] for _ in 1:length(labels)]))

    # sort data by label
    for rd in rds
        push!(data[label(rd)], rd)
    end
    
    # iterate through dict by label
    for (lab, values) in data
        label_printed = false
        for rd in values
            plot!(p, extract_function(rd),
                color = haskey(plotargs, :color) ? plotargs[:color] : colors[lab], # take plotargs... color if it was passed
                label = !label_printed ? lab : nothing,
                linewidth = 2,    
                alpha = 0.2 + 0.8 / length(values))
            label_printed = true
        end
    end

    plot!(p; plotargs...)

    return p
end



###
### INCLUDE PLOT STRUCTS & GENERATE FUNCTIONS
###

# The src/reporting/plots folder contains a dedicated file
# for each plot. Files starting with "sp_" are SimulationPlots
# Files starting with "bp_" are BatchPlots.
# If you want to set up a new plot, simply add a file to the folder and 
# make sure to define the Plot-Struct and the generate() function.

# include all Julia files from the "plots"-folder
dir = basefolder() * "/src/reporting/plots/"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)