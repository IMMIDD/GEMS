export Batch
export add!, simconfigs

"""
    Batch

A container for running and analyzing multiple simulations.
Stores simulation configurations that are executed sequentially by `process!`.
"""
mutable struct Batch
    simconfigs::Vector{NamedTuple}

    @doc """
        Batch(; n_runs=0, simargs...)

    Create a `Batch` with `n_runs` copies of the simulation configuration
    defined by `simargs`. Any keyword arguments accepted by `Simulation()`
    can be passed here.
    """
    function Batch(; n_runs::Integer = 0, simargs...)
        cfgs = [NamedTuple(simargs) for _ in 1:n_runs]
        return new(cfgs)
    end

    @doc """
        Batch(batches::Batch...)

    Merge multiple `Batch` objects into one by concatenating their configs.
    """
    function Batch(batches::Batch...)
        new(vcat([b.simconfigs for b in batches]...))
    end

    @doc """
        Batch(batches::Vector{Batch})

    Merge a vector of `Batch` objects into one.
    """
    Batch(batches::Vector{Batch}) = Batch(batches...)
end

"""
    merge(batches::Batch...)
    merge(batches::Vector{Batch})

Generates a new `Batch` that contains all simulation configs of the input `Batch`es.
"""
Base.merge(batches::Batch...) = Batch(batches...)
Base.merge(batches::Vector{Batch}) = merge(batches...)

###
### GETTER & SETTER
###

"""
    simconfigs(batch::Batch)

Returns the vector of simulation configuration `NamedTuple`s in this `Batch`.
"""
function simconfigs(batch::Batch)
    return batch.simconfigs
end

"""
    add!(cfg::NamedTuple, batch::Batch)

Append a simulation configuration to a `Batch`.
"""
function add!(cfg::NamedTuple, batch::Batch)
    push!(batch.simconfigs, cfg)
end

add!(batch::Batch, cfg::NamedTuple) = add!(cfg, batch)

"""
    Base.append!(batch1::Batch, batch2::Batch)

Append all simulation configs from `batch2` to `batch1`.
"""
function Base.append!(batch1::Batch, batch2::Batch)
    append!(batch1.simconfigs, batch2.simconfigs)
    return batch1
end

###
### PRINTING
###

function Base.show(io::IO, batch::Batch)
    write(io, "Batch ($(length(batch.simconfigs)) configs)")
end
