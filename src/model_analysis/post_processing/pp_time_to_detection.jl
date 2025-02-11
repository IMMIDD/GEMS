export time_to_detection

"""
    time_to_detection(postProcessor::PostProcessor)

Returns the mean, standard deviation, minimum, maximum, upper- and lower 95% confidence intervals
of the time to detection for all *detected* cases. The _time to detection_ is defined as the 
number of ticks between the time of exposure and time of detection. 

# Returns

- `DataFrame` with the following columns:

| Name                         | Type    | Description                                                     |
| :--------------------------- | :------ | :-------------------------------------------------------------- |
| `tick`                       | `Int64` | Simulation tick (time)                                          |
| `mean_time_to_detection`     | `Int64` | Mean time to detection at that tick                             |
| `std_time_to_detection`      | `Int64` | Standard deviation of time to detection at that tick            |
| `min_time_to_detection`      | `Int64` | Minimum time to detection at that tick                          |
| `max_time_to_detection`      | `Int64` | Maximum time to detection at that tick                          |
| `upper_95_time_to_detection` | `Int64` | Upper 95% confidence interval of time to detection at that tick |
| `lower_95_time_to_detection` | `Int64` | Lower 95% confidence interval of time to detection at that tick |
"""
function time_to_detection(postProcessor::PostProcessor)
    return(
        postProcessor |> detected_infections |> 
        x -> DataFrames.select(x, [:tick, :first_detected_tick]) |>
        # calculate time to detection
        x -> transform(x, [:first_detected_tick, :tick] => (-) => :time_to_detection) |>
        x -> DataFrames.select(x, :first_detected_tick => :tick, :time_to_detection) |>
        x -> leftjoin(DataFrame(tick = 1:tick(postProcessor |> simulation)), x, on = [:tick => :tick])|>
        # get aggregated data (mean, std, min, max, confidence bands)
        x -> aggregate_df(x, :tick) 
    )
end