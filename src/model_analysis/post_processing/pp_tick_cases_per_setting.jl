export tick_cases_per_setting

""" 
    tick_cases_per_setting(postProcessor::PostProcessor)

Returns a `DataFrame` containing information about the infections in different setting types

# Returns

- `DataFrame` with the following columns:

| Name                 | Type      | Description                                                      |
| :------------------- | :-------- | :--------------------------------------------------------------- |
| `tick`               | `Int16`   | Current tick of the simulation                                   |
| `setting_type`       | `String`  | Setting type identifier (name)                                   |
| `daily_cases`        | `Int64`   | Cases for setting and tick                                       |
"""
function tick_cases_per_setting(postProcessor::PostProcessor)
    # Group by tick and setting_type and count the number of infections
    tick_cases = infectionsDF(postProcessor) |>
                    x -> groupby(x, [:tick, :setting_type]) |>
                    x -> combine(x, nrow => :daily_cases)

    all_ticks = DataFrame(tick = 1:tick(simulation(postProcessor)))

    # Get unique settings to ensure every tick has an entry for each setting
    unique_settings = unique(tick_cases.setting_type)
    
    # Create a DataFrame with all possible combinations of ticks and settings
    full_combinations = crossjoin(all_ticks, DataFrame(setting_type=unique_settings))
    
    # Merge with the counted infections and fill missing values with 0
    merged_data = leftjoin(full_combinations, tick_cases, on = [:tick, :setting_type]) |>
                x -> transform(x, :daily_cases => ByRow(y -> coalesce(y, 0)) => :daily_cases) |>
                x -> sort!(x, :tick)

    return merged_data
end