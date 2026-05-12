export total_detected_cases, detection_rate

"""
    total_detected_cases(postProcessor::PostProcessor)

Returns a `DataFrame` with the total number of detected cases per pathogen.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                              |
| :--------------- | :------ | :--------------------------------------- |
| `pathogen_id`    | `Int8`  | Pathogen identifier                      |
| `detected_cases` | `Int64` | Total number of detected cases           |
"""
function total_detected_cases(postProcessor::PostProcessor)
    return postProcessor.infectionsDF |>
        df -> subset(df, :first_detected_tick => ByRow(!ismissing), view=true) |>
        df -> groupby(df, :pathogen_id) |>
        df -> combine(df, nrow => :detected_cases)
end

"""
    detection_rate(postProcessor::PostProcessor)

Returns a `DataFrame` with the fraction of detected cases per pathogen.

# Returns

- `DataFrame` with the following columns:

| Name             | Type      | Description                              |
| :--------------- | :-------- | :--------------------------------------- |
| `pathogen_id`    | `Int8`    | Pathogen identifier                      |
| `detection_rate` | `Float64` | Fraction of detected infections          |
"""
function detection_rate(postProcessor::PostProcessor)
    infs = infectionsDF(postProcessor)
    detected = total_detected_cases(postProcessor)
    total_per_pid = combine(groupby(infs, :pathogen_id), nrow => :total)
    res = innerjoin(detected, total_per_pid, on = :pathogen_id)
    return transform!(res,
        [:detected_cases, :total] => ByRow((d, t) -> d / t) => :detection_rate) |>
        df -> DataFrames.select(df, :pathogen_id, :detection_rate)
end
