export reported_tick_cases

"""
    reported_tick_cases(postProcessor::PostProcessor)

Returns the number of reported positive test cases per tick.
This analysis is based on the `testDF` dataframe.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                                                                  |
| :--------------- | :------ | :--------------------------------------------------------------------------- |
| `tick`           | `Int16` | Simulation tick (time)                                                       |
| `reported_cnt`   | `Int64` | Number of newly reported infections (positive reportable tests) at that tick |
"""
function reported_tick_cases(postProcessor::PostProcessor)

    return (postProcessor |> testsDF |>
        x -> x[x.test_result .& x.reportable, :] |>
        x -> rename!(x, :test_tick => :tick) |>
        x -> (isempty(x) ? DataFrame(tick = Int16[], reported_cnt = Int64[]) : groupby(x, :tick)) |>
        x -> isempty(x) ? x : combine(x, nrow => :reported_cnt)) |>
        x -> leftjoin(DataFrame(tick = 1:tick(postProcessor |> simulation)), x, on = :tick) |>
        x -> transform(x, :reported_cnt => ByRow(x -> coalesce(x, 0)) => :reported_cnt) |>
        x -> sort(x, :tick)

end