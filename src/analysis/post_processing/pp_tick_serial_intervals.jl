
"""
    _tick_serial_intervals(postProcessor::PostProcessor)

Returns a `DataFrame` containing aggregated information on the serial interval per tick and pathogen.

# Returns

- `DataFrame` with the follwing columns:

| Name          | Type      | Description                                                  |
| :------------ | :-------- | :----------------------------------------------------------- |
| `tick`        | `Int16`   | Simulation tick (time)                                       |
| `pathogen_id` | `Int8`    | Pathogen identifier                                          |
| `min_SI`      | `Int16`   | Minimal serial interval recored for any infection that tick  |
| `max_SI`      | `Int16`   | Maximum serial interval recored for any infection that tick  |
| `lower_95_SI` | `Float64` | Lower 95% confidence interval for serial intervals that tick |
| `upper_95_SI` | `Float64` | Upper 95% confidence interval for serial intervals that tick |
| `std_SI`      | `Float64` | Stanard deviation for serial intervals that tick             |
| `mean_SI`     | `Float64` | Mean for serial intervals that tick                          |
"""
function _tick_serial_intervals(postProcessor::PostProcessor)
    infs = infectionsDF(postProcessor)
    results = DataFrame[]
    for p in pathogens(simulation(postProcessor))
        pid = id(p)
        sub = subset(infs, :pathogen_id => ByRow(==(pid)), view=true) |>
            x -> DataFrames.select(x, :tick, :serial_interval => :SI)
        agg = aggregate_df(sub, :tick)
        agg.pathogen_id .= pid
        push!(results, agg)
    end
    return isempty(results) ? DataFrame() : vcat(results...)
end
