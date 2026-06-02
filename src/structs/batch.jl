export Batch
export add!, simconfigs, simsetups

"""
    Batch

A container for running and analyzing multiple simulations.
Stores simulation configurations that are executed sequentially by `process!`.
"""
mutable struct Batch
    simconfigs::Vector{NamedTuple}
    setups::Vector{Union{Nothing, Function}}

    @doc """
        Batch(; n_runs=0, setup=nothing, simargs...)

    Create a `Batch` with `n_runs` copies of the simulation configuration
    defined by `simargs`. Any keyword arguments accepted by `Simulation()`
    can be passed here.

    Pass `setup = sim -> ...` to attach interventions, strategies, or triggers
    to each simulation after construction but before it runs.
    """
    function Batch(; n_runs::Integer = 0, setup::Union{Nothing, Function} = nothing, simargs...)
        cfgs = [NamedTuple(simargs) for _ in 1:n_runs]
        setups = Vector{Union{Nothing, Function}}(fill(setup, n_runs))
        return new(cfgs, setups)
    end

    @doc """
        Batch(batches::Batch...)

    Merge multiple `Batch` objects into one by concatenating their configs and setups.
    """
    function Batch(batches::Batch...)
        new(
            vcat([b.simconfigs for b in batches]...),
            vcat([b.setups for b in batches]...)
        )
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
    simsetups(batch::Batch)

Returns the vector of per-run setup functions in this `Batch`.
"""
function simsetups(batch::Batch)
    return batch.setups
end

"""
    add!(batch::Batch, cfg::NamedTuple; setup=nothing)

Append a simulation configuration to a `Batch`. Pass `setup = sim -> ...` to
attach a setup function to this specific run.
"""
function add!(batch::Batch, cfg::NamedTuple; setup::Union{Nothing, Function} = nothing)
    push!(batch.simconfigs, cfg)
    push!(batch.setups, setup)
end

add!(cfg::NamedTuple, batch::Batch; kwargs...) = add!(batch, cfg; kwargs...)

"""
    Base.append!(batch1::Batch, batch2::Batch)

Append all simulation configs and setups from `batch2` to `batch1`.
"""
function Base.append!(batch1::Batch, batch2::Batch)
    append!(batch1.simconfigs, batch2.simconfigs)
    append!(batch1.setups, batch2.setups)
    return batch1
end

###
### PRINTING
###

function Base.show(io::IO, batch::Batch)
    write(io, "Batch ($(length(batch.simconfigs)) configs)")
end
