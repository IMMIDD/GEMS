export detected_tick_cases

"""
    detected_tick_cases(postProcessor::PostProcessor)

Returns the number of detected cases per tick and the number of true new exposures.
This analysis is based on the `tick_test` column of the infections-dataframe 
which indicates when an individual with an active infection was first tested positive.
Thus, there might be a delay between `exposure_cnt` and `detected_cnt`.

# Returns

- `DataFrame` with the following columns:

| Name                   | Type    | Description                                                           |
| :--------------------- | :------ | :-------------------------------------------------------------------- |
| `tick`                 | `Int16` | Simulation tick (time)                                                |
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
            x -> (x.total_reported_cases .= 0; x.new_detections .= 0; x.double_reports .= 0; x.false_positives .= 0; x) |> # add new columns with zeros
            x -> DataFrames.select(x, :tick, :total_reported_cases, :new_detections, :double_reports, :false_positives, :exposed_cnt, )
    end

    return postProcessor |> testsDF |>
        x -> DataFrames.select(x, :test_id, :test_tick, :test_result, :infection_id, :infected, :reportable) |>
        x -> x[x.reportable, :] |> # filter for reportable cases only
        # find out time of first detection per infection and join it with df to find out
        # whether a test should be counted as "true new detected case"
        x -> leftjoin(x,
            x[x.infection_id .> 0, :] |> # filter for true positives
                y -> groupby(y, :infection_id) |> # determine the test-ID of the test that first detected an infection (to filter out double reports)
                y-> combine(y,
                    [:test_tick, :test_id] => ((tick, id) -> id[argmin(tick)]) => :detection_test_id,
                    :test_tick => minimum => :first_detected_at), # determine time of detection
            on = :infection_id) |> 
        # attribute tests for whether they are a true new detection
        x -> transform(x,
            [:test_id, :detection_test_id, :infected] => ByRow((id, first_id, inf) -> (inf && id == first_id)) => :detecting_test) |>
        # attribute tests for being double reports or false positives
        x -> transform(x,
            [:infected, :detecting_test] => ByRow((i, d) -> i && !d) => :double_report,
            :infected => ByRow(i -> !i) => :false_positive) |> 
        # sum up data per tick
        x -> groupby(x, :test_tick) |>
        x -> combine(x,
            nrow => :total_reported_cases,
            :detecting_test => sum => :new_detections,
            :double_report => sum => :double_reports,
            :false_positive => sum => :false_positives) |>
        x -> rename(x, :test_tick => :tick) |>
        # join with infection data to get new cases per tick
        x -> rightjoin(x, postProcessor |> tick_cases, on = :tick) |>
        x -> DataFrames.select(x,
            :tick,
            :total_reported_cases => ByRow(x -> coalesce(x, 0)) => :total_reported_cases,
            :new_detections => ByRow(x -> coalesce(x, 0)) => :new_detections,
            :double_reports => ByRow(x -> coalesce(x, 0)) => :double_reports,
            :false_positives => ByRow(x -> coalesce(x, 0)) => :false_positives,
            :exposed_cnt) |>
        x -> sort(x, :tick)
end