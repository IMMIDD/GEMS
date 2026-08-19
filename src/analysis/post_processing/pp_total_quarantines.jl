export total_quarantines

"""
    total_quarantines(postProcessor::PostProcessor)

Returns the total number of total ticks spent in quarantine.
E.g., if 10 indiviuals were in quarantine for 5 ticks each,
this function will return 50.
"""
function total_quarantines(postProcessor::PostProcessor)
    return(
        (postProcessor |> cumulative_quarantines).quarantined |> sum
    )
end