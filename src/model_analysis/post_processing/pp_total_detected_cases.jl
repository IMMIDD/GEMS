export total_detected_cases, detection_rate

"""
    total_detected_cases(postProcessor::PostProcessor)

Returns the total number of detected cases.
"""
function total_detected_cases(postProcessor::PostProcessor)
    return count(!ismissing, postProcessor.infectionsDF.first_detected_tick)
end

"""
    detection_rate(postProcessor::PostProcessor)

Returns the fraction of detected cases.
"""
function detection_rate(postProcessor::PostProcessor)
    return(
        (postProcessor |> total_detected_cases)
        /
        (postProcessor |> infectionsDF |> nrow)
    )
end