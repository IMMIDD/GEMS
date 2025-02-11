export detected_infections

"""
    detected_infections(postProcessor::PostProcessor)

A subset of the `infections` dataframe with only the detected cases.
An infection is considered to be _detected_ if the infection has a non-missing `first_detected_tick`.
For the column definitions, look up the `infectionsDF(postProcessor)` documentation.

# Returns

- `DataFrame`: Please look up the column definitions in the `infectionsDF(postProcessor)` documentation.
"""
function detected_infections(postProcessor::PostProcessor)
    return(
        postProcessor |> infectionsDF |>
            # remove undetected transmissions
            x -> x[.!ismissing.(x.first_detected_tick), :]
    )
end