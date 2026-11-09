export gemsheatmap


"""
    r0_cgrad(outvals)

Returns a color scheme for the `gemsheatmap()` function assuming
that the input data is a vector of R0 values.
"""
function r0_cgrad(outvals)

    minval, maxval = minimum(outvals), maximum(outvals)

    # if all values are above 1
    if (minval >= 1)
        return cgrad([:red, :purple], [0.0, 1.0])
    end

    # if all values are below 1
    if (maxval <= 1)
        return cgrad([:white, :yellow], [0.0, 1.0])
    end

    # if values cross R0 = 1: color stops at fixed R values
    stops = [
        (minval, :blue),
        (0.89, :lightblue),
        (1.0, :white),
        (1.3, :orange),
        (maxval, :red)
    ]

    # keep the end points, and only the inner stops that lie within the data range
    # (otherwise the positions leave [0, 1] or are out of order, which shifts all colors)
    stops = [s for (i, s) in enumerate(stops) if i == 1 || i == length(stops) || minval < s[1] < maxval]

    return cgrad(last.(stops), (first.(stops) .- minval) ./ (maxval - minval))
end

"""
    gemsheatmap(xvals::Vector{<:Any}, yvals::Vector{<:Any}, outvals::Vector{<:Any};
        aggregate::Function = mean,
        xrev::Bool = false,
        yrev::Bool = false,
        xformatter::Function = x -> x, 
        yformatter::Function = y -> y, 
        color = :inferno,
        plotargs...)

Generates a heatmap of the value combinations in `xvals` and `yvals` colored according to values in `outvals`.
This function can be used to visualize the results of sweeps through parameter spaces.

# Parameters

- `xvals::Vector{<:Any}`: X-axis values for heatmap
- `yvals::Vector{<:Any}`: Y-axis values for heatmap
- `outvals::Vector{<:Any}`: outome / colored values for heatmap
- `aggregate::Function = mean` *(optional)*: If multiple outcome values are available per X/Y-combination, this function is applied to aggregate results (e.g., `mean`, `minimum`, `maximum`, `first`, ...)
- `xrev::Bool = false` *(optional)*: If true, reverses order of ticks on x-axis
- `yrev::Bool = false` *(optional)*: If true, reverses order of ticks on y-axis
- `xformatter::Function = x -> x` *(optional)*: One-argument function to format x-axis ticks
- `yformatter::Function = y -> y` *(optional)*: One-argument function to format y-axis ticks
- `color = :inferno` *(optional)*: Any color (-scheme) that is available to the `Plots.jl` package takes. If `:r0` it will apply a color scheme for R0-Maps (with singled-out `R=1`)
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Plot using the `Plots.jl` package's struct.

# Example

```julia

xvals = []
yvals = []
outvals = []

# vary transmission rate
for tr in 0.1:0.02:0.3
    # vary time to recovery
    for rec in 3:13
        sim = Simulation(transmission_rate = tr, time_to_recovery = rec)
        run!(sim)
        rd = ResultData(sim, style = "LightRD")

        # extract data for heatmap
        push!(xvals, tr)
        push!(yvals, rec)
        push!(outvals, r0(rd))
    end
end

# print heatmap
gemsheatmap(xvals, yvals, outvals,
    xlabel = "Transmission Rate",
    ylabel = "Time to Recovery",
    colorbar_title = "Basic Reproduction Number",
    color = :r0) 
```
"""
function gemsheatmap(xvals::Vector{<:Any}, yvals::Vector{<:Any}, outvals::Vector{<:Any};
    aggregate::Function = mean, # aggregation function for duplicate values
    xrev::Bool = false, # reverse order of ticks on x-axis
    yrev::Bool = false, # reverse order of ticks on y-axis
    xformatter::Function = x -> x, # format ticks on x-axis
    yformatter::Function = y -> y, # format ticks on y-axis
    # plot arguments that need to passed during creation
    color = :inferno,
    # other plot arguments
    plotargs...)

    # transform to dataframe for grouping
    df = DataFrame(
            xvals = xvals,
            yvals = yvals,
            outvals = outvals) |>
        df -> groupby(df, [:xvals, :yvals]) |>
        df -> combine(df, :outvals => aggregate => :outvals)

    # get axis labels
    xlabs = df.xvals |> unique |> vec -> sort(vec, rev = xrev)
    ylabs = df.yvals |> unique |> vec -> sort(vec, rev = yrev)

    # convert data to matrix
    xy_matrix = fill(NaN, length(ylabs), length(xlabs))
    for x in 1:length(xlabs)
        for y in 1:length(ylabs)
            vals = df.outvals[df.xvals .== xlabs[x] .&& df.yvals .== ylabs[y]]
            if !isempty(vals)
                xy_matrix[y, x] = first(vals)
            end
        end
    end

    # check if all values are available
    if any(isnan, xy_matrix)
        throw(ArgumentError("There are missing value combinations in the heatmap input data. Make sure all x and y values have an outcome value."))
    end

    # convert color scheme
    c = color != :r0 ? color : r0_cgrad(df.outvals)

    hm = heatmap(xy_matrix,
        # set tick labels
        xticks = (1:length(xlabs), xformatter.(xlabs)),
        yticks = (1:length(ylabs), yformatter.(ylabs)),
        # visual pars
        fontfamily = "Times Roman",
        color = c)

    plot!(hm; plotargs...)

    return hm

end