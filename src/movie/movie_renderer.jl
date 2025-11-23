export generate_movie

"""
    steps(n::Int, base::Int)

Helper function defining substeps for same-tick-groupings 
so that not all infections appear on a map, once the respective
frame has reached the integer tick in which all infections
would lie. (Makes the video prettier)
"""
function steps(n::Int, base::Int)
    step = 1.0 / (n + 1)
    return [base + i * step for i in 1:n]
end

"""
    generate_frame(coords::DataFrame, dest::AbstractString, reg::Vector{Float64},
        active_infections::DataFrame, plot_xmax::Int64, plot_ymax::Int64, plot_xlabel::String)

Generates one video frame for the `generate_movie()` function.

# Parameters

- `coords::DataFrame`: Dataframe with points to plot (`lon` and `lat` columns required)
- `dest::AbstractString`: Storage location for the frame (the function cannot return the frame directly)
- `reg::Vector{Float64}`: four-item region vector defining the map limits in lat/lon min/max pairs
    (look up `GMT.jl` package to learn about regions)
- `active_infections::DataFrame`: Dataframe with `time` and `count` column used to plot the infection curve below the map
- `plot_xmax::Int64`:  Right X-axis limit for infection curve plot
- `plot_ymax::Int64`:  Upper Y-axis limit for infection curve plot
- `plot_xlabel::String`: X-Axis label fo the infection curve plot

# Returns

- `GMTWrapper`: Custom struct containing the storage location of the generated frame 
"""
function generate_frame(coords::DataFrame,
    dest::AbstractString,
    reg::Vector{Float64},
    active_infections::DataFrame,
    plot_xmax::Int64,
    plot_ymax::Int64,
    plot_xlabel::String)

    # put coordinates into data 
    data = [coords.lon coords.lat]
    
    try 
        lon_range = abs(reg[1] - reg[2])
        lat_range = abs(reg[3] - reg[4])

        # mid point of latitude range
        mid_lat = (reg[3] + reg[4]) / 2
        midpoint_stretch = sec(deg2rad(mid_lat))
        effective_lat_range = lat_range * midpoint_stretch

        map_scale = 20
        map_asp_ratio = (lon_range / effective_lat_range) / 1.1

        GMT.gmtbegin(dest, fmt=:png)

            # Starting the subplot configuration
            GMT.subplot(grid="2x1", frame=:none, margins=0, dims=(size=(map_scale, map_scale / map_asp_ratio + 0.1 * map_scale), frac=((map_scale, map_scale / map_asp_ratio),(map_scale, 0.1 * map_scale))))

                # Plot the first panel with the map
                GMT.coast(region=reg, proj=:Mercator, shore=:thinnest, land=:white, borders=:a, water=:lightblue, frame=:n, panel=(1, 1))
                if !isempty(data)
                    GMT.scatter(data, marker=:point, mc="#DC143C@70", markersize=0.03,  panel=(1, 1))
                end

                # Plot the second panel with the line plot
                GMT.plot(active_infections.time, active_infections.count, region=[- 0.02 * plot_xmax, 1.02 * plot_xmax, -0.02 * plot_ymax, 1.02 * plot_ymax], lw=1.5, lc="#DC143C", panel=(2, 1), frame=:S, xlabel=plot_xlabel)

            # End the subplot context
            GMT.subplot(:end)

            # Ends the modern mode session and actually outputs the plot
        GMT.gmtend(show=false)
    catch e 
        @error e
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
    generate_movie(rd::ResultData; seconds::Int64 = 60, fps::Int64 = 24, savepath::String = "video.mp4")

Generates a video of the disease progression on a geographical map based on the 
`infections` dataframe in the `ResultData` object. Note, that the population model
used in the simulation must contain geolocated settings. Otherwise there is nothing
to show. The optional parameters steer custom video length (`seconds`), 
custom framerates (`fps`) and a custom filepath (`savepath`).

We've noticed that very large models may cause problems both in terms of runtime
(too many points to put on the map for each frame) and explanatory value of the 
movie (as it can result in widespread 'red surfaces'). For this reason, there is a 
maximum number of points that will be put on the maps in videos. The value can be
adapted via the `MAX_MAP_POINTS_VIDEO` constant in the `constants.jl` file. Generally,
a value between 1,000,000 and 2,000,000 has proven to be a good maximum. If there are
more geolocated infections in the `ResultData` object than specified in the maximum, 
a subsample will be taken.

# Parameters

- `rd::ResultData`: Data used to generate the movie (must contain the `infections`-dataframe with geolocations)
- `seconds::Int64 = 60` *(optional)*: Length of the video in seconds
- `fps::Int64 = 24` *(optoional)*: Frames per second
- `savepath::String = "video.mp4"` *(optional)*: Path to where the video shall be stored (must end in .mp4)

"""
function generate_movie(rd::ResultData; seconds::Int64 = 60, fps::Int64 = 24, savepath::String = "video.mp4")

    printinfo("Generating video frames")

    # final tick
    ft = rd |> final_tick
    if ft <= 0
        throw("You need to run the simulation before attempting to render a movie.")
    end

    # tick unit
    utick = rd |> tick_unit |> uppercasefirst

    # calculate time window of one frame
    stepsize = ft / (seconds * fps)

    # prepare infections dataframe
    data = rd |> infections |>
        x -> transform(x, [:recovery, :death] => ((r, d) -> max(r,d)) => :removed_tick) |>
        x -> DataFrames.select(x,:infection_id, :tick, :removed_tick, :lat, :lon) # only interested in time window to plot

    # select data with geolocations
    selection = data |>
        x -> filter(row -> (!any(isnan, row)), x) |>
        x -> DataFrames.select(x, :infection_id)

    # if data doesn't have any geolocations
    if selection |> isempty
        throw("The infections dataframe does not have any geolocated entries.")
    end
    
    # calculate which data points to plot (make subselection if too many)
    totalpoints = selection |> nrow
    showpoints = minimum([GEMS.MAX_MAP_POINTS_VIDEO, totalpoints])

    # add flag to wether to show 
    selection.show = vcat(ones(Bool, showpoints), zeros(Bool, totalpoints-showpoints)) |> shuffle! 

    # join flag with initial DataFrame
    data = data |>
        x -> leftjoin(x, selection, on = [:infection_id => :infection_id]) |>
        x -> DataFrames.select(x, :tick, :removed_tick, :lat, :lon, :show => ByRow(x -> coalesce(x, false)) => :show)

    # calculate start "time" by grouping all infections 
    # at a certain tick and spreading them out across
    # tick and tick + 1. Value stored in "start" column
    data = transform(groupby(data, :tick), :tick => (x -> steps(length(x), Int64(x[1]))) => :start_time)
    data.start_time = reduce(vcat, data.start_time)

    # do the same for "end" column
    data = transform(groupby(data, :removed_tick), :removed_tick => (x -> steps(length(x), Int64(x[1]))) => :end_time)
    data.end_time = reduce(vcat, data.end_time)

    # get region outer bounds for map
    reg = data |>
             x -> filter(row -> (!any(isnan, row)), x) |> # remove rows without geolocations
             region_range

    # get limits for current infection plot below map
    max_act_inf = maximum(compartment_fill(rd).exposed_cnt + compartment_fill(rd).infectious_cnt)

    # infection data collector
    active_infections = DataFrame(
        time  = [0.0],
        count = [0.0]
    )

    # image collector
    imgs = []

    # generate frames
    for i in ProgressBar(0:((seconds * fps) - 1))

        # filter data in time range
        coords = data |> 
            x -> filter(row -> row.start_time <= (i*stepsize) < row.end_time, x) |>
            x -> DataFrames.select(x, :lat, :lon, :show)

        # make sure, temp folder exists
        mkpath(TEMP_FOLDER_PATH)
        # add current number of active infections to temp dataframe
        push!(active_infections, [i*stepsize, coords |> nrow]) 

        # filter data to show on map
        coords = coords |>
            x -> filter(row -> row.show, x) # select only rows to show

        img_path = joinpath(TEMP_FOLDER_PATH, "frame$i.png")

        # generate image
        generate_frame(coords,
            img_path,
            reg,
            active_infections,
            Int64(ft),
            Int64(ceil(max_act_inf)),
            utick)

        # load image into Memory & crop it as VideoIO requires X,Y dimensions to be even
        img = load(img_path)
        h, w = size(img)
        new_h = h - mod(h, 2)
        new_w = w - mod(w, 2)
        img_cropped = img[21:new_h, 1:new_w] # remove a bit of the top to crop the GMT-north border that could be removed via the "frame" attribute (GMT bug?)
        push!(imgs, img_cropped)

        # remove temporary image file
        rm(img_path)

    end

    # render video and export it
    printinfo("Rendering video")
    encoder_options = (crf=17, preset="slow", tune="film")
    VideoIO.save(savepath, imgs, framerate=fps, encoder_options=encoder_options, codec_name = "libx264")
end