export NoneInfected, evaluate


"""
    NoneInfected <: StopCriterion

A `StopCriterion` that stops the simulation once no individual is infected.
"""
struct NoneInfected <: StopCriterion
end


### NECESSARY INTERFACE

"""
    evaluate(simulation, criterion)

Returns true if none of the individuals are infected.
"""
function evaluate(simulation::Simulation, criterion::NoneInfected)
    valid = true
    Threads.@threads for i in (simulation |> population |> individuals)
        if infected(i)
            return valid = false
        end
    end
    return valid
end