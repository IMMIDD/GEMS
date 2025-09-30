export total_tests

"""
    total_tests(postProcessor::PostProcessor)

Sums up the total number of tests per test type.

# Returns

- `Dict{String, Int64}`: Dictionary where the key is the `TestType`'s name and the value
    the number of tests that were applied.
"""
function total_tests(postProcessor::PostProcessor)
    # group by testtype
    tt = postProcessor |> testsDF |> 
        x -> groupby(x, :test_type) |>
        x -> combine(x, nrow => :count)

    #result dict
    dict = Dict()

    for row in eachrow(tt)
        dict[row.test_type] = row.count
    end

    return(dict)
end