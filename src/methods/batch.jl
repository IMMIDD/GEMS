export run!
export customlogger!

"""
    run!(batch::Batch; stepmod!::Function = x -> x)

Run all simulations within a `Batch`. You can pass a `stepmod!` function
that is being executed for each simulation in each step. But be aware
that it will be the same instance of the `stepmod!` function. So if you
have any internal data collection, this might cause inconsistencies.
"""
function run!(batch::Batch)
    cnt = 0
    for sim in batch.simulations
        printinfo("Running Simulation $(cnt = cnt + 1)/$(batch |> simulations |> length) [$(label(sim))]")
        run!(sim)
    end

    return batch
end

"""
    customlogger!(batch::Batch, cl::CustomLogger)

Adds a `CustomLogger` to each of the `Simulation` objects that are contained in this batch.
**Note:** This function will generate a duplicate of the passed logger for each of the simulation objects
as otherwise, als data from all simulations would  we written to the same logger.
"""
function customlogger!(batch::Batch, cl::CustomLogger)
    for sim in batch.simulations
        customlogger!(sim, duplicate(cl))
    end
end