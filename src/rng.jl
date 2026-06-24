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
    gems_rand(rng::Xoshiro, args...)
    gems_rand(sim::Simulation, args...)

Reproducibility-safe version of `Random.rand`. Always pass a seeded `Xoshiro` from the simulation object to ensure deterministic results.
If the global `ENFORCE_SIM_RNGS` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
@inline function gems_rand(rng::Xoshiro, args...)
    # throw error if global RNG is used and enforcement is enabled
    ENFORCE_SIM_RNGS && rng === default_gems_rng() && throw(ArgumentError("Using the global RNG in `gems_rand`."))
    return Random.rand(rng, args...)
end
@inline gems_rand(sim::Simulation, args...) = gems_rand(rng(sim), args...)

function gems_rand(args...; kwargs...)
    @warn "Calling `gems_rand` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.rand(args...)
end


"""
    gems_sample(rng::Xoshiro, args...; kwargs...)
    gems_sample(sim::Simulation, args...; kwargs...)
    
Reproducibility-safe version of `StatsBase.sample`. Always pass a seeded `Xoshiro` from the simulation object to ensure deterministic results.
If the global `ENFORCE_SIM_RNGS` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
@inline function gems_sample(rng::Xoshiro, args...; kwargs...)
    # throw error if global RNG is used and enforcement is enabled
    ENFORCE_SIM_RNGS && rng === default_gems_rng() && throw(ArgumentError("Using the global RNG in `gems_sample`."))
    return StatsBase.sample(rng, args...; kwargs...)
end
@inline gems_sample(sim::Simulation, args...; kwargs...) = gems_sample(rng(sim), args...; kwargs...)

function gems_sample(args...; kwargs...)
    @warn "Calling `gems_sample` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return StatsBase.sample(args...; kwargs...)
end


"""
    gems_sample!(rng::Xoshiro, args...; kwargs...)
    gems_sample!(sim::Simulation, args...; kwargs...)

Reproducibility-safe version of `StatsBase.sample!`. Always pass a seeded `Xoshiro` from the simulation object to ensure deterministic results.
If the global `ENFORCE_SIM_RNGS` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
@inline function gems_sample!(rng::Xoshiro, args...; kwargs...)
    # throw error if global RNG is used and enforcement is enabled
    ENFORCE_SIM_RNGS && rng === default_gems_rng() && throw(ArgumentError("Using the global RNG in `gems_sample!`."))
    return StatsBase.sample!(rng, args...; kwargs...)
end
@inline gems_sample!(sim::Simulation, args...; kwargs...) = gems_sample!(rng(sim), args...; kwargs...)

function gems_sample!(args...; kwargs...)
    @warn "Calling `gems_sample!` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return StatsBase.sample!(args...; kwargs...)
end


"""
    gems_shuffle!(rng::Xoshiro, args...)
    gems_shuffle!(sim::Simulation, args...)

Reproducibility-safe version of `Random.shuffle!`. Always pass a seeded `Xoshiro` from the simulation object to ensure deterministic results.
If the global `ENFORCE_SIM_RNGS` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
@inline function gems_shuffle!(rng::Xoshiro, args...)
    # throw error if global RNG is used and enforcement is enabled
    ENFORCE_SIM_RNGS && rng === default_gems_rng() && throw(ArgumentError("Using the global RNG in `gems_shuffle!`."))
    return Random.shuffle!(rng, args...)
end
@inline gems_shuffle!(sim::Simulation, args...) = gems_shuffle!(rng(sim), args...)

function gems_shuffle!(args...)
    @warn "Calling `gems_shuffle!` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.shuffle!(args...)
end


"""
    gems_shuffle(rng::Xoshiro, args...)
    gems_shuffle(sim::Simulation, args...)

Reproducibility-safe version of `Random.shuffle`. Always pass a seeded `Xoshiro` from the simulation object to ensure deterministic results.
If the global `ENFORCE_SIM_RNGS` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
@inline function gems_shuffle(rng::Xoshiro, args...)
    ENFORCE_SIM_RNGS && rng === default_gems_rng() && throw(ArgumentError("Using the global RNG in `gems_shuffle`."))
    return Random.shuffle(rng, args...)
end
@inline gems_shuffle(sim::Simulation, args...) = gems_shuffle(rng(sim), args...)

function gems_shuffle(args...)
    @warn "Calling `gems_shuffle` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.shuffle(args...)
end


"""
    gems_randn(rng::Xoshiro, args...)
    gems_randn(sim::Simulation, args...)

Reproducibility-safe version of `Random.randn`. Always pass a seeded `Xoshiro` from the simulation object to ensure deterministic results.
If the global `ENFORCE_SIM_RNGS` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
@inline function gems_randn(rng::Xoshiro, args...)
    # throw error if global RNG is used and enforcement is enabled
    ENFORCE_SIM_RNGS && rng === default_gems_rng() && throw(ArgumentError("Using the global RNG in `gems_randn`."))
    return Random.randn(rng, args...)
end
@inline gems_randn(sim::Simulation, args...) = gems_randn(rng(sim), args...)

function gems_randn(args...)
    @warn "Calling `gems_randn` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.randn(args...)
end