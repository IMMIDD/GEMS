export tick_pooltests

"""
     tick_pooltests(postProcessor::PostProcessor)

Returns a Dict for each employed test_type containing their name as a key and
a `DataFrame` containing the number of applied pool tests (positive/negative/total) per tick.

# Returns

- `Dict{String, DataFrame}`: The key is the `TestType`'s name.
    The values are `DataFrames` with the following columns:

| Name             | Type    | Description                                      |
| :--------------- | :------ | :------------------------------------------------|
| `tick`           | `Int16` | Simulation tick (time)                           |
| `positive_tests` | `Int64` | Number of positive tests                         |
| `negative_tests` | `Int64` | Number of negative tests                         |
| `total_tests`    | `Int64` | Number of tests performed                        |
"""
function tick_pooltests(postProcessor::PostProcessor)::Dict

    # load cached DF if available
    if in_cache(postProcessor, "tick_pooltests")
        return(load_cache(postProcessor, "tick_pooltests"))
    end

    tick_tests = postProcessor |> pooltestsDF |> 
        x -> groupby(x, [:test_type, :test_tick]) |>
        x -> combine(x, [:test_result] => (x -> (positive_tests=count(x .== true), negative_tests=count(x .==false))) => AsTable ) |>
        x -> transform(x, [:positive_tests, :negative_tests] => (+) => :total_tests)|>
        x -> groupby(x, :test_type) |>
        x -> Dict(key.test_type => DataFrame(group)|>
        x -> DataFrames.select(x, Not(:test_type)) |>
        x -> leftjoin(DataFrame(tick = 1:tick(postProcessor |> simulation)), x, on = [:tick => :test_tick])|>
        x -> coalesce.(x,0)|>
        x -> sort!(x, :tick) for (key, group) in pairs(x))
    
    # cache dataframe
    store_cache(postProcessor, "tick_pooltests", tick_tests)

    return tick_tests
end