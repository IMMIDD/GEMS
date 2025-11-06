export set_global_seed
export gems_rand
export gems_sample
export gems_sample!
export gems_shuffle
export gems_shuffle!
export gems_randn


### RANDOM NUMBER GENERATORS
# Reproducibility-safe random number generation methods for GEMS simulations

"""
    set_global_seed(seed::Int64)
    
Wrapper to set seed of global RNG
"""
function set_global_seed(seed::Int64)
    Random.seed!(seed)
end

"""
    gems_rand(rng::AbstractRNG, args...)

Reproducibility-safe version of `Random.rand`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
"""
function gems_rand(rng::AbstractRNG, args...)
    return Random.rand(rng, args...)
end

function gems_rand(sim::Simulation, args...)
    return Random.rand(rng(sim), args...)
end

function gems_rand(args...)
    @warn "Calling `gems_rand` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.rand(args...)
end


"""
    gems_sample(rng::AbstractRNG, args...; kwargs...)

Reproducibility-safe version of `StatsBase.sample`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
"""
function gems_sample(rng::AbstractRNG, args...; kwargs...)
    return StatsBase.sample(rng, args...; kwargs...)
end

function gems_sample(sim::Simulation, args...; kwargs...)
    return StatsBase.sample(rng(sim), args...; kwargs...)
end

function gems_sample(args...; kwargs...)
    @warn "Calling `gems_sample` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return StatsBase.sample(args...; kwargs...)
end


"""
    gems_sample!(rng::AbstractRNG, args...; kwargs...)

Reproducibility-safe version of `StatsBase.sample!`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
"""
function gems_sample!(rng::AbstractRNG, args...; kwargs...)
    return StatsBase.sample!(rng, args...; kwargs...)
end

function gems_sample!(sim::Simulation, args...; kwargs...)
    return StatsBase.sample!(rng(sim), args...; kwargs...)
end

function gems_sample!(args...; kwargs...)
    @warn "Calling `gems_sample!` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return StatsBase.sample!(args...; kwargs...)
end


"""
    gems_shuffle!(rng::AbstractRNG, args...)

Reproducibility-safe version of `Random.shuffle!`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
"""
function gems_shuffle!(rng::AbstractRNG, args...)
    return Random.shuffle!(rng, args...)
end

function gems_shuffle!(sim::Simulation, args...)
    return Random.shuffle!(rng(sim), args...)
end

function gems_shuffle!(args...)
    @warn "Calling `gems_shuffle!` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.shuffle!(args...)
end


"""
    gems_shuffle(rng::AbstractRNG, args...)

Reproducibility-safe version of `Random.shuffle`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
"""
function gems_shuffle(rng::AbstractRNG, args...)
    return Random.shuffle(rng, args...)
end

function gems_shuffle(sim::Simulation, args...)
    return Random.shuffle(rng(sim), args...)
end

function gems_shuffle(args...)
    @warn "Calling `gems_shuffle` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.shuffle(args...)
end


"""
    gems_randn(rng::AbstractRNG, args...)

Reproducibility-safe version of `Random.randn`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
"""
function gems_randn(rng::AbstractRNG, args...)
    return Random.randn(rng, args...)
end

function gems_randn(sim::Simulation, args...)
    return Random.randn(rng(sim), args...)
end

function gems_randn(args...)
    @warn "Calling `gems_randn` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.randn(args...)
end