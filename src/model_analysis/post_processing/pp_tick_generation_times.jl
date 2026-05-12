export tick_generation_times

"""
    tick_generation_times(postProcessor::PostProcessor)

Returns a `DataFrame` containing aggregated information on the generation time per tick and pathogen.

# Returns

- `DataFrame` with the following columns:

| Name                       | Type      | Description                                                  |
| :------------------------- | :-------- | :----------------------------------------------------------- |
| `tick`                     | `Int16`   | Simulation tick (time)                                       |
| `pathogen_id`              | `Int8`    | Pathogen identifier                                          |
| `min_generation_time`      | `Int16`   | Minimal generation time recored for any infection that tick  |
| `max_generation_time`      | `Int16`   | Maximum generation time recored for any infection that tick  |
| `lower_95_generation_time` | `Float64` | Lower 95% confidence interval for generation times that tick |
| `upper_95_generation_time` | `Float64` | Upper 95% confidence interval for generation times that tick |
| `std_generation_time`      | `Float64` | Stanard deviation for generation times that tick             |
| `mean_generation_time`     | `Float64` | Mean for generation times that tick                          |
"""
function tick_generation_times(postProcessor::PostProcessor)
    df = infectionsDF(postProcessor) |>
        x -> DataFrames.select(x, [:tick, :pathogen_id, :generation_time])
    results = DataFrame[]
    for p in pathogens(simulation(postProcessor))
        pid = id(p)
        sub = subset(df, :pathogen_id => ByRow(==(pid)), view=true) |>
            x -> DataFrames.select(x, :tick, :generation_time)
        agg = aggregate_df(sub, :tick)
        agg.pathogen_id .= pid
        push!(results, agg)
    end
    return isempty(results) ? DataFrame() : vcat(results...)
end
