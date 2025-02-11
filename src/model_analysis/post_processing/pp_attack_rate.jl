export attack_rate

"""
    attack_rate(postProcessor::PostProcessor)

Divides the number of individuals who have been infected one (or multiple)
time(s) by the total number of individuals.
"""
function attack_rate(postProcessor::PostProcessor)
    return(
        ((postProcessor |> infectionsDF).id_b |> unique |> length)
            /
        (postProcessor.populationDF |> nrow)
    )
end