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
    pathogen_ids = _sorted_pathogen_ids(postProcessor)
    infs = infectionsDF(postProcessor)
    counts = _detected_per_pathogen(infs.pathogen_id, infs.first_detected_tick, pathogen_ids)
    detected = counts .> 0
    return DataFrame(pathogen_id = pathogen_ids[detected], detected_cases = counts[detected])
end

# detected infections per pathogen, i.e. those with a detection tick
function _detected_per_pathogen(pids::AbstractVector, detection_ticks::AbstractVector, pathogen_ids::Vector)
    counts = zeros(Int, length(pathogen_ids))
    for (p, t) in zip(pids, detection_ticks)
        ismissing(t) && continue
        i = findfirst(==(p), pathogen_ids)
        i === nothing || (counts[i] += 1)
    end
    return counts
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
    pathogen_ids = _sorted_pathogen_ids(postProcessor)
    counts = _rows_per_pathogen(infs.pathogen_id, pathogen_ids)
    infected = counts .> 0
    total_per_pid = DataFrame(pathogen_id = pathogen_ids[infected], total = counts[infected])
    res = innerjoin(detected, total_per_pid, on = :pathogen_id)
    return transform!(res,
        [:detected_cases, :total] => ByRow((d, t) -> d / t) => :detection_rate) |>
        df -> DataFrames.select(df, :pathogen_id, :detection_rate)
end
