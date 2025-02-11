export tick_generation_times

"""
    tick_generation_times(postProcessor::PostProcessor)

Returns a `DataFrame` containing aggregated information on the generation time per tick.

# Returns

- `DataFrame` with the following columns:

| Name                       | Type      | Description                                                  |
| :------------------------- | :-------- | :----------------------------------------------------------- |
| `tick`                     | `Int16`   | Simulation tick (time)                                       |
| `min_generation_time`      | `Int16`   | Minimal generation time recored for any infection that tick  |
| `max_generation_time`      | `Int16`   | Maximum generation time recored for any infection that tick  |
| `lower_95_generation_time` | `Float64` | Lower 95% confidence interval for generation times that tick |
| `upper_95_generation_time` | `Float64` | Upper 95% confidence interval for generation times that tick |
| `std_generation_time`      | `Float64` | Stanard deviation for generation times that tick             |
| `mean_generation_time`     | `Float64` | Mean for generation times that tick                          |
"""
function tick_generation_times(postProcessor::PostProcessor)
    return(
        aggregate_df(
            postProcessor |> infectionsDF |>
                x -> DataFrames.select(x, [:tick, :generation_time]),
            :tick)
    )
end