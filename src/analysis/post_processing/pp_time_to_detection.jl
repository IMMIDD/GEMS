export time_to_detection

"""
    time_to_detection(postProcessor::PostProcessor)

Returns the mean, standard deviation, minimum, maximum, upper- and lower 95% confidence intervals
of the time to detection for all *detected* cases, per pathogen. The _time to detection_ is defined as the
number of ticks between the time of exposure and time of detection.

# Returns

- `DataFrame` with the following columns:

| Name                         | Type    | Description                                                     |
| :--------------------------- | :------ | :-------------------------------------------------------------- |
| `tick`                       | `Int64` | Simulation tick (time)                                          |
| `pathogen_id`                | `Int8`  | Pathogen identifier                                             |
| `mean_time_to_detection`     | `Int64` | Mean time to detection at that tick                             |
| `std_time_to_detection`      | `Int64` | Standard deviation of time to detection at that tick            |
| `min_time_to_detection`      | `Int64` | Minimum time to detection at that tick                          |
| `max_time_to_detection`      | `Int64` | Maximum time to detection at that tick                          |
| `upper_95_time_to_detection` | `Int64` | Upper 95% confidence interval of time to detection at that tick |
| `lower_95_time_to_detection` | `Int64` | Lower 95% confidence interval of time to detection at that tick |
"""
function time_to_detection(postProcessor::PostProcessor)
    det = postProcessor |> detected_infections |>
        x -> DataFrames.select(x, [:tick, :pathogen_id, :first_detected_tick]) |>
        x -> transform(x, [:first_detected_tick, :tick] => (-) => :time_to_detection) |>
        x -> DataFrames.select(x, :first_detected_tick => :tick, :pathogen_id, :time_to_detection)

    final_tick = tick(postProcessor |> simulation)
    results = DataFrame[]
    for p in pathogens(simulation(postProcessor))
        pid = id(p)
        sub = subset(det, :pathogen_id => ByRow(==(pid)), view=true) |>
            x -> DataFrames.select(x, :tick, :time_to_detection)
        full = leftjoin(DataFrame(tick = 1:final_tick), sub, on = :tick)
        agg = aggregate_df(full, :tick)
        agg.pathogen_id .= pid
        push!(results, agg)
    end
    return isempty(results) ? DataFrame() : vcat(results...)
end
