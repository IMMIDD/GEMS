export tick_tests

"""
    tick_tests(postProcessor::PostProcessor)

Returns a Dict for each employed test_type containing their name as a key and
a `DataFrame` containing the count of individuals that got tested (positive/negative)
as well as the people reported positive for the first time per tick.

# Returns

- `Dict{String, DataFrame}`: The key is the `TestType`'s name.
    The values are `DataFrames` with the following columns:

| Name                    | Type      | Description                                           |
| :---------------------- | :-------- | :---------------------------------------------------- |
| `tick`                  | `Int16`   | Simulation tick (time)                                |
| `reported_cases`        | `Int16`   | Number cases tested positive for the first time       |
| `positive_tests`        | `Int64`   | Number of positive tests                              |
| `negative_tests`        | `Int64`   | Number of negative tests                              |
| `total_tests`           | `Int64`   | Number of tests performed                             |
| `positive_rate`         | `Float64` | Fraction of positive tests                            |
| `rolling_positive_rate` | `Float64` | Positive rate rolling average of the 7 previous ticks |
"""
function tick_tests(postProcessor::PostProcessor)::Dict

    # load cached DF if available
    if in_cache(postProcessor, "tick_tests")
        return(load_cache(postProcessor, "tick_tests"))
    end

    windowsize = 7
  
    detected_cases = postProcessor |> infectionsDF |>
        x -> filter(row -> !ismissing(row.first_detected_tick), x) |>
        x -> groupby(x, [:test_type, :first_detected_tick]) |>
        x -> combine(x, nrow => :reported_cases)

    tick_tests = postProcessor |> testsDF |> 
        x -> groupby(x, [:test_type, :test_tick]) |>
        x -> combine(x, [:test_result] => (x -> (positive_tests=count(x .== true), negative_tests=count(x .==false))) => AsTable ) |>
        x -> transform(x, [:positive_tests, :negative_tests] => (+) => :total_tests, copycols = false) |>
        x -> transform(x, [:positive_tests, :total_tests] => ByRow((p, t) -> p / t) => :positive_rate, copycols = false) |>
        x -> leftjoin(x, detected_cases, on = [:test_type, :test_tick => :first_detected_tick])|>
        x -> groupby(x, :test_type) |>
        x -> Dict(key.test_type => DataFrame(group)|>
        x -> DataFrames.select(x, Not(:test_type)) |>
        x -> leftjoin(DataFrame(tick = 1:tick(postProcessor |> simulation)), x, on = [:tick => :test_tick])|>
        x -> coalesce.(x,0)|>
        x -> sort!(x, :tick) for (key, group) in pairs(x))
    
    # calculating rolling positive rate with windowsize
    for (key, df) in pairs(tick_tests)
        rolling_pr = Vector{Float64}(undef, df |> nrow)
        for i in 1:(df |> nrow)
            rolling_pr[i] = mean((df)[max(1, i-windowsize):i, "positive_rate"])
        end
        df.rolling_positive_rate = rolling_pr        
    end

    # cache dataframe
    store_cache(postProcessor, "tick_tests", tick_tests)

    return tick_tests
end