export detected_tick_cases

"""
    detected_tick_cases(postProcessor::PostProcessor)

Returns the number of detected cases per tick and pathogen and the number of true new exposures.
This analysis is based on the `tick_test` column of the infections-dataframe
which indicates when an individual with an active infection was first tested positive.
Thus, there might be a delay between `exposure_cnt` and `detected_cnt`.

# Returns

- `DataFrame` with the following columns:

| Name                   | Type    | Description                                                           |
| :--------------------- | :------ | :-------------------------------------------------------------------- |
| `tick`                 | `Int16` | Simulation tick (time)                                                |
| `pathogen_id`          | `Int8`  | Pathogen identifier                                                   |
| `total_reported_cases` | `Int64` | Total number of reported cases at that tick                           |
| `new_detections`       | `Int64` | Number of true new detected cases at that tick (not known before)     |
| `double_reports`       | `Int64` | Number of cases that were reported at that tick but were known before |
| `false_positives`      | `Int64` | Number of false positive reports at that tick                         |
| `exposed_cnt`          | `Int64` | Number of new infections at that tick                                 |
"""
function detected_tick_cases(postProcessor::PostProcessor)

    # return empty dataframe, if no tests were reported
    if sum(postProcessor.testsDF.reportable) <= 0
        return postProcessor |> tick_cases |>
            x -> (x.total_reported_cases .= 0; x.new_detections .= 0; x.double_reports .= 0; x.false_positives .= 0; x) |>
            x -> DataFrames.select(x, :tick, :pathogen_id, :total_reported_cases, :new_detections, :double_reports, :false_positives, :exposed_cnt)
    end

    return postProcessor |> testsDF |>
        x -> DataFrames.select(x, :test_id, :tick, :test_result, :infection_id, :infected, :reportable, :pathogen_id) |>
        x -> x[x.reportable, :] |>
        x -> leftjoin(x,
            x[x.infection_id .> 0, :] |>
                (y -> isempty(y) ? DataFrame(infection_id = [], detection_test_id = [], first_detected_at = []) :
                    groupby(y, :infection_id) |>
                    z-> combine(z,
                        [:tick, :test_id] => ((tick, id) -> id[argmin(tick)]) => :detection_test_id,
                        :tick => minimum => :first_detected_at)),
            on = :infection_id) |>
        x -> transform(x,
            [:test_id, :detection_test_id, :infected] => ByRow((id, first_id, inf) -> (inf && id == first_id)) => :detecting_test) |>
        x -> transform(x,
            [:infected, :detecting_test] => ByRow((i, d) -> i && !d) => :double_report,
            :infected => ByRow(i -> !i) => :false_positive) |>
        x -> groupby(x, [:tick, :pathogen_id]) |>
        x -> combine(x,
            nrow => :total_reported_cases,
            :detecting_test => sum => :new_detections,
            :double_report => sum => :double_reports,
            :false_positive => sum => :false_positives) |>
        x -> rightjoin(x, postProcessor |> tick_cases, on = [:tick, :pathogen_id]) |>
        x -> DataFrames.select(x,
            :tick,
            :pathogen_id,
            :total_reported_cases => ByRow(x -> coalesce(x, 0)) => :total_reported_cases,
            :new_detections => ByRow(x -> coalesce(x, 0)) => :new_detections,
            :double_reports => ByRow(x -> coalesce(x, 0)) => :double_reports,
            :false_positives => ByRow(x -> coalesce(x, 0)) => :false_positives,
            :exposed_cnt) |>
        x -> sort(x, [:pathogen_id, :tick])
end
