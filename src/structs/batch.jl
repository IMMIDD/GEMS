###  PLACEHOLDER

function SimConstructor(; simargs...)
    return Simulation()
end

#### REMOVE PLACEHODERS

export Batch
export add!, remove!, simulations

"""
    Batch

A batch is a container to run and analyze multiple simulations at once.
It allows running a single simulation multiple times or combining multiple
simulations and scenarios in one analysis.
"""
mutable struct Batch
    simulations::Vector{Simulation}

    
    @doc """
        Batch(;n_runs::Integer = 0, print_infos::Bool = false, simargs...)

    Creates a `Batch` object with a number of `Simulation` objects as specified in `n_runs`.
    The `Simulation` objects are not passed but rather instantiated inside this function.
    Therefore, you can specify any keyworded argument using `simargs...`, that you would
    otherwise pass to the `Simulation()` constructor.

    This function suppresses the console info outputs of the `Simulation()` function.
    If you want to enable them, set the optional `print_info` argument to `True`. 
    """
    function Batch(;n_runs::Integer = 0, print_infos::Bool = false, simargs...)
        prev_print_state = GEMS.PRINT_INFOS
        
        sims = []
        for i in 1:n_runs
            printinfo("Instantiating Simulation $i/$n_runs in Batch")
            GEMS.PRINT_INFOS = print_infos
            SimConstructor(;simargs...)
            GEMS.PRINT_INFOS = prev_print_state
        end

        return new(sims)
    end

    @doc """
        Batch(simulations::Simulation...)

    Creates a `Batch` object from `Simulation` objects.
    **Note**: All `Simulation` objects must be unique.
    You cannot pass the same simulation twice.
    """
    function Batch(simulations::Simulation...)
        b = new([])
        for sim in simulations
            add!(sim, b)
        end
        return b
    end

    @doc """
        Batch(simulations::Vector{Simulation})

    Creates a `Batch` object from a vector of `Simulation` objects.
    **Note**: All `Simulation` objects must be unique.
    You cannot pass the same simulation twice.
    """
    Batch(simulations::Vector{Simulation}) = Batch(simulations...)


    @doc """
        Batch(batches::Batch...)

    Merge multiple `Batch`es into one.
    """
    function Batch(batches::Batch...)
        b = new([])
        for batch in batches
            for sim in simulations(batch)
                add!(sim, b)
            end
        end
        return b
    end

    @doc """
        Batch(batches::Vector{Batch}) 

    Merge multiple `Batch`es into one.
    """
    Batch(batches::Vector{Batch}) = Batch(batches...)
end

"""
    merge(batches::Batch...)
    merge(batches::Vector{Batch})

Generates a new `Batch` that contains all simulations of the input `Batch`es. 
"""
Base.merge(batches::Batch...) = Batch(batches...)
Base.merge(batches::Vector{Batch}) = merge(batches...)

###
### GETTER & SETTER
###

"""
    add!(sim::Simulation, batch::Batch)

Adds a `Simulation` to a `Batch`.
"""
function add!(sim::Simulation, batch::Batch)
    # verify that the added simulation is not identical with any of the previously added
    objectid(sim) in map(objectid, batch.simulations) ? throw("This simulation is already in the batch!") : nothing
    objectid(sim |> population) in map(s -> objectid(population(s)), batch.simulations) ? throw("This simulation uses the same population as another simulation in the batch!") : nothing

    push!(batch.simulations, sim)
end

# alternative with swapped arguments
add!(batch::Batch, sim::Simulation) = add!(sim, batch)

"""
    remove!(sim::Simulation, batch::Batch)

Removes a `Simulation` from a `Batch`.
"""
function remove!(sim::Simulation, batch::Batch)
    setdiff!(batch.simulations, [sim])
end

"""
    simulations(batch::Batch)

Returns the list of `Simulation`s associated with a `Batch`.
"""
function simulations(batch::Batch)
    return batch.simulations
end

"""
    append!(batch1::Batch, batch2::Batch)

Appends all simulations of `batch2` to `batch1`.
"""
function Base.append!(batch1::Batch, batch2::Batch)
    for sim in simulations(batch2)
        add!(sim, batch1)
    end
    return batch1
end

###
### PRINTING
###

function Base.show(io::IO, batch::Batch)
    res = "Batch ($(batch |> simulations |> length))\n"
    for s in simulations(batch)
        res *= "\u2514 $(s |> label)\n"
    end

    write(io, res)
end