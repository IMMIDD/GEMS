export total_tests

"""
    total_tests(postProcessor::PostProcessor)

Sums up the total number of tests per test type and pathogen.

# Returns

- `DataFrame` with the following columns:

| Name          | Type     | Description                                 |
| :------------ | :------- | :------------------------------------------ |
| `test_type`   | `String` | Name of the test type                       |
| `pathogen_id` | `Int8`   | Pathogen identifier                         |
| `count`       | `Int64`  | Number of tests of this type for this path  |
"""
function total_tests(postProcessor::PostProcessor)
    return postProcessor |> testsDF |>
        x -> groupby(x, [:test_type, :pathogen_id]) |>
        x -> combine(x, nrow => :count)
end
