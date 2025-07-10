export tick_serotests
"""
    tick_serotests(postProcessor::PostProcessor)

Returns a `Dict` for each seroprevalence `test_type`, keyed by its name and
containing a `DataFrame` with counts per simulation tick.

# Returns

- `Dict{String, DataFrame}`: The key is the `test_type` name.
    The values are `DataFrames` with the following columns:

| Name              | Type      | Description                                                  |
| :---------------- | :-------- | :----------------------------------------------------------- |
| `tick`            | `Int16`   | Simulation tick                                              |
| `true_positives`  | `Int64`   | Test result was positive and person was ever infected        |
| `false_positives` | `Int64`   | Test result was positive but person was never infected       |
| `true_negatives`  | `Int64`   | Test result was negative and person was never infected       |
| `false_negatives` | `Int64`   | Test result was negative but person was ever infected        |
| `positive_tests`  | `Int64`   | Sum of true and false positives                              |
| `negative_tests`  | `Int64`   | Sum of true and false negatives                              |
| `total_tests`     | `Int64`   | Total number of tests                                        |
"""
function tick_serotests(postProcessor::PostProcessor)::Dict
    if in_cache(postProcessor, "tick_serotests")
        return load_cache(postProcessor, "tick_serotests")
    end

    sero = serotestsDF(postProcessor)

    # Step 1: Add classification columns
    sero = transform(sero, [
        [:test_result, :was_infected] => ByRow((r, i) -> r && i) => :true_positive,
        [:test_result, :was_infected] => ByRow((r, i) -> r && !i) => :false_positive,
        [:test_result, :was_infected] => ByRow((r, i) -> !r && !i) => :true_negative,
        [:test_result, :was_infected] => ByRow((r, i) -> !r && i) => :false_negative,
    ]...)

    # Step 2: Aggregate by test_type and tick
    agg = combine(groupby(sero, [:test_type, :test_tick]),
        :true_positive => sum => :true_positives,
        :false_positive => sum => :false_positives,
        :true_negative => sum => :true_negatives,
        :false_negative => sum => :false_negatives
    )

    # Step 3: Compute derived metrics step-by-step
    agg = transform(agg, [
        [:true_positives, :false_positives] => ByRow(+) => :positive_tests,
        [:true_negatives, :false_negatives] => ByRow(+) => :negative_tests,
    ]...)

    agg = transform(agg, [:positive_tests, :negative_tests] => ByRow(+) => :total_tests)

    # Step 4: Convert to Dict{String, DataFrame} with full tick range and rolling average
    tickrange = 1:tick(postProcessor.simulation)
    tick_sero = Dict{String, DataFrame}()

    for (test_type, df) in pairs(groupby(agg, :test_type))
        df = select(df, Not(:test_type))
        df = rename(df, :test_tick => :tick)
        full_df = leftjoin(DataFrame(tick = tickrange), df, on = :tick)
        full_df = coalesce.(full_df, 0)
        full_df = sort!(full_df, :tick)

        tick_sero[test_type.test_type] = full_df
    end

    store_cache(postProcessor, "tick_serotests", tick_sero)
    return tick_sero
end