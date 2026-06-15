export generate_movie

# Number of pixels cropped from the top of each frame to remove the GMT
# north-border artifact (GMT bug: cannot be suppressed via the frame attribute).
const GMT_TOP_BORDER_CROP = 21

"""
    steps(n::Int, base::Int)

Helper function defining substeps for same-tick-groupings
so that not all infections appear on a map at once when the frame reaches
the integer tick in which all infections would lie. (Makes the video prettier)
"""
function steps(n::Int, base::Int)
    step = 1.0 / (n + 1)
    return [base + i * step for i in 1:n]
end


"""
    prepare_frame_data(infections::DataFrame, max_points::Int)

Prepares the infections dataframe for frame-by-frame rendering.

Filters to geolocated infections, applies subsampling if the total exceeds
`max_points`, and assigns a fractional `start_time` and `end_time` to each
infection by spreading same-tick events evenly across the tick interval via
`steps`.

Throws if no geolocated infections are present.

# Parameters

- `infections::DataFrame`: Raw infections dataframe from `ResultData`.
    Must contain `:infection_id`, `:tick`, `:recovery`, `:death`, `:lat`, `:lon`.
- `max_points::Int`: Maximum number of infections to render on the map.
    Excess points are randomly excluded via the `:show` flag.

# Returns

- `DataFrame` with columns `:tick`, `:removed_tick`, `:lat`, `:lon`, `:show`,
    `:start_time`, `:end_time`.
"""
function prepare_frame_data(infections::DataFrame, max_points::Int)

    data = infections |>
        x -> transform(x, [:recovery, :death] => ((r, d) -> max.(r, d)) => :removed_tick) |>
        x -> DataFrames.select(x, :infection_id, :tick, :removed_tick, :lat, :lon)

    selection = data |>
        x -> filter(row -> !any(isnan, row), x) |>
        x -> DataFrames.select(x, :infection_id)

    if isempty(selection)
        throw("The infections dataframe does not have any geolocated entries.")
    end

    totalpoints = nrow(selection)
    showpoints = min(max_points, totalpoints)
    selection.show = vcat(ones(Bool, showpoints), zeros(Bool, totalpoints - showpoints)) |> shuffle!

    data = data |>
        x -> leftjoin(x, selection, on = :infection_id) |>
        x -> DataFrames.select(x, :tick, :removed_tick, :lat, :lon, :show => ByRow(x -> coalesce(x, false)) => :show)

    data = transform(groupby(data, :tick), :tick => (x -> steps(length(x), Int64(x[1]))) => :start_time)
    data.start_time = reduce(vcat, data.start_time)

    data = transform(groupby(data, :removed_tick), :removed_tick => (x -> steps(length(x), Int64(x[1]))) => :end_time)
    data.end_time = reduce(vcat, data.end_time)

    return data
end


"""
    crop_image(img)

Crops a GMT-rendered frame so that:
- The GMT north-border artifact is removed from the top (`GMT_TOP_BORDER_CROP` rows).
- Width and height are rounded down to even numbers, as required by VideoIO.
"""
function crop_image(img)
    h, w = size(img)
    new_h = h - mod(h, 2)
    new_w = w - mod(w, 2)
    return img[GMT_TOP_BORDER_CROP:new_h, 1:new_w]
end


"""
    render_frames(data::DataFrame, reg::Vector{Float64}, ft::Integer, max_act_inf::Real,
        utick::String, seconds::Int64, fps::Int64)

Iterates over all frames, filters the active infections per timestep, renders each
frame to a temporary PNG via `generate_frame`, crops and loads it into
memory, then removes the temporary file.

Returns a vector of cropped images ready for video encoding.

# Parameters

- `data::DataFrame`: Prepared frame data from `prepare_frame_data`.
- `reg::Vector{Float64}`: Map region bounds.
- `ft::Int`: Final tick of the simulation.
- `max_act_inf::Real`: Peak active infection count, used as the Y-axis limit.
- `utick::String`: Tick unit label for the X-axis.
- `seconds::Int64`: Desired video length in seconds.
- `fps::Int64`: Frames per second.
"""
function render_frames(data::DataFrame, reg::Vector{Float64}, ft::Integer, max_act_inf::Real, utick::String, seconds::Int64, fps::Int64)

    stepsize = ft / (seconds * fps)
    active_infections = DataFrame(time = [0.0], count = [0.0])
    imgs = []

    for i in ProgressBar(0:((seconds * fps) - 1))

        coords = data |>
            x -> filter(row -> row.start_time <= (i * stepsize) < row.end_time, x) |>
            x -> DataFrames.select(x, :lat, :lon, :show)

        mkpath(TEMP_FOLDER_PATH)
        push!(active_infections, [i * stepsize, nrow(coords)])

        coords = filter(row -> row.show, coords)

        img_path = joinpath(TEMP_FOLDER_PATH, "frame$i.png")

        generate_frame(coords, img_path, reg, active_infections, Int64(ft), Int64(ceil(max_act_inf)), utick)

        push!(imgs, crop_image(load(img_path)))
        rm(img_path)
    end

    return imgs
end


"""
    generate_frame(coords::DataFrame, dest::AbstractString, reg::Vector{Float64},
        active_infections::DataFrame, plot_xmax::Int64, plot_ymax::Int64, plot_xlabel::String)

Generates one video frame for the `generate_movie()` function.

# Parameters

- `coords::DataFrame`: Dataframe with points to plot (`:lon` and `:lat` columns required).
- `dest::AbstractString`: Storage location for the frame.
- `reg::Vector{Float64}`: Four-item region vector defining the map limits as
    lon_min, lon_max, lat_min, lat_max (see `GMT.jl` documentation).
- `active_infections::DataFrame`: Dataframe with `:time` and `:count` columns used
    to plot the infection curve below the map.
- `plot_xmax::Int64`: Right X-axis limit for the infection curve plot.
- `plot_ymax::Int64`: Upper Y-axis limit for the infection curve plot.
- `plot_xlabel::String`: X-axis label for the infection curve plot.

# Returns

- `GMTWrapper`: Custom struct containing the storage location of the generated frame.
"""
function generate_frame(coords::DataFrame,
    dest::AbstractString,
    reg::Vector{Float64},
    active_infections::DataFrame,
    plot_xmax::Int64,
    plot_ymax::Int64,
    plot_xlabel::String)

    data = [coords.lon coords.lat]

    try
        lon_range = abs(reg[1] - reg[2])
        lat_range = abs(reg[3] - reg[4])

        mid_lat = (reg[3] + reg[4]) / 2
        midpoint_stretch = sec(deg2rad(mid_lat))
        effective_lat_range = lat_range * midpoint_stretch

        map_scale = 20
        map_asp_ratio = (lon_range / effective_lat_range) / 1.1

        GMT.gmtbegin(dest, fmt=:png)

            GMT.subplot(grid="2x1", frame=:none, margins=0, dims=(size=(map_scale, map_scale / map_asp_ratio + 0.1 * map_scale), frac=((map_scale, map_scale / map_asp_ratio), (map_scale, 0.1 * map_scale))))

                GMT.coast(region=reg, proj=:Mercator, shore=:thinnest, land=:white, borders=:a, water=:lightblue, frame=:n, panel=(1, 1))
                if !isempty(data)
                    GMT.scatter(data, marker=:point, mc="#DC143C@70", markersize=0.03, panel=(1, 1))
                end

                GMT.plot(active_infections.time, active_infections.count, region=[-0.02 * plot_xmax, 1.02 * plot_xmax, -0.02 * plot_ymax, 1.02 * plot_ymax], lw=1.5, lc="#DC143C", panel=(2, 1), frame=:S, xlabel=plot_xlabel)

            GMT.subplot(:end)

        GMT.gmtend(show=false)
    catch e
        @error e
    end

    if isfile(dest)
        return GMTWrapper(dest)
    else
        throw("Error while trying to generate GMT Map. File was not successfully created at $dest. Are you missing the '*.png?'")
    end
end


"""
    generate_movie(rd::ResultData; seconds::Int64 = 60, fps::Int64 = 24, savepath::String = "video.mp4")

Generates a video of the disease progression on a geographical map based on the
`infections` dataframe in the `ResultData` object. Note that the population model
used in the simulation must contain geolocated settings, otherwise there is nothing
to show. The optional parameters control video length (`seconds`), framerate (`fps`),
and output path (`savepath`).

For very large models the number of rendered points is capped at `MAX_MAP_POINTS_VIDEO`
(set in `constants.jl`; a value between 1,000,000 and 2,000,000 is recommended).
If there are more geolocated infections than the cap, a random subsample is taken.

# Parameters

- `rd::ResultData`: Must contain the `infections` dataframe with geolocations.
- `seconds::Int64 = 60` *(optional)*: Length of the video in seconds.
- `fps::Int64 = 24` *(optional)*: Frames per second.
- `savepath::String = "video.mp4"` *(optional)*: Output path (must end in `.mp4`).
"""
function generate_movie(rd::ResultData; seconds::Int64 = 60, fps::Int64 = 24, savepath::String = "video.mp4")

    ft = rd |> final_tick
    if ft <= 0
        throw("You need to run the simulation before attempting to render a movie.")
    end

    data = prepare_frame_data(infections(rd), GEMS.MAX_MAP_POINTS_VIDEO)
    reg = data |> x -> filter(row -> !any(isnan, row), x) |> region_range
    max_act_inf = maximum(compartment_fill(rd).exposed_cnt + compartment_fill(rd).infectious_cnt)

    printinfo("Generating video frames")
    imgs = render_frames(data, reg, ft, max_act_inf, rd |> tick_unit |> uppercasefirst, seconds, fps)

    printinfo("Rendering video")
    VideoIO.save(savepath, imgs, framerate=fps, encoder_options=(crf=17, preset="slow", tune="film"), codec_name="libx264")
end