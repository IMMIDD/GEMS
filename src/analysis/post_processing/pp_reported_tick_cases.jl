export reported_tick_cases

"""
    reported_tick_cases(postProcessor::PostProcessor)

Returns the number of reported positive test cases per tick and pathogen.
This analysis is based on the `testDF` dataframe.

# Returns

- `DataFrame` with the following columns:

| Name             | Type    | Description                                                                  |
| :--------------- | :------ | :--------------------------------------------------------------------------- |
| `tick`           | `Int16` | Simulation tick (time)                                                       |
| `pathogen_id`    | `Int8`  | Pathogen identifier                                                          |
| `reported_cnt`   | `Int64` | Number of newly reported infections (positive reportable tests) at that tick |
"""
function reported_tick_cases(postProcessor::PostProcessor)
    sim_tick = tick(postProcessor |> simulation)
    tests = postProcessor |> testsDF |>
        x -> subset(x, :test_result => ByRow(identity), :reportable => ByRow(identity), view=true)

    base = crossjoin(
        DataFrame(tick = collect(Int16, 1:sim_tick)),
        DataFrame(pathogen_id = collect(map(id, pathogens(simulation(postProcessor))))))

    counts = if isempty(tests)
        DataFrame(tick = Int16[], pathogen_id = Int8[], reported_cnt = Int64[])
    else
        x -> groupby(x, [:tick, :pathogen_id]) |>
        x -> combine(x, nrow => :reported_cnt)
    end

    return leftjoin!(base, counts, on = [:tick, :pathogen_id]) |>
        x -> transform!(x, :reported_cnt => ByRow(x -> coalesce(x, 0)) => :reported_cnt) |>
        x -> sort!(x, [:pathogen_id, :tick])
end
