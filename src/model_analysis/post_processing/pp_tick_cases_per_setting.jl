export tick_cases_per_setting

"""
    tick_cases_per_setting(postProcessor::PostProcessor)

Returns a `DataFrame` containing information about the infections in different setting types,
per pathogen.

# Returns

- `DataFrame` with the following columns:

| Name                 | Type      | Description                                                      |
| :------------------- | :-------- | :--------------------------------------------------------------- |
| `tick`               | `Int16`   | Current tick of the simulation                                   |
| `setting_type`       | `String`  | Setting type identifier (name)                                   |
| `pathogen_id`        | `Int8`    | Pathogen identifier                                              |
| `daily_cases`        | `Int64`   | Cases for setting, pathogen and tick                             |
"""
function tick_cases_per_setting(postProcessor::PostProcessor)
    # Group by tick, setting_type and pathogen and count the number of infections
    tick_cases = infectionsDF(postProcessor) |>
        x -> groupby(x, [:tick, :setting_type, :pathogen_id]) |>
        x -> combine(x, nrow => :daily_cases)

    all_ticks = DataFrame(tick = 1:tick(simulation(postProcessor)))

    # Get unique settings and pathogens to ensure every tick has an entry for each combination
    unique_settings = unique(tick_cases.setting_type)

    # Create a DataFrame with all possible combinations of ticks, settings and pathogens
    full_combinations = crossjoin(all_ticks,
        crossjoin(DataFrame(setting_type=unique_settings), DataFrame(pathogen_id=map(id, pathogens(simulation(postProcessor))))))

    # Merge with the counted infections and fill missing values with 0
    merged_data = leftjoin(full_combinations, tick_cases, on = [:tick, :setting_type, :pathogen_id]) |>
        x -> transform(x, :daily_cases => ByRow(y -> coalesce(y, 0)) => :daily_cases) |>
        x -> sort!(x, [:pathogen_id, :tick])

    return merged_data
end
