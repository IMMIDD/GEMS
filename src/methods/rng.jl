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
    gems_rand(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)
    gems_rand(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)

Reproducibility-safe version of `Random.rand`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
If `enforce_sim_rngs` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
function gems_rand(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)
    # throw error if global RNG is used and enforcement is enabled
    enforce_sim_rngs && rng == Random.default_rng() && throw(ArgumentError("Using the global RNG in `gems_rand`."))
    return Random.rand(rng, args...)
end
gems_rand(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS) = gems_rand(rng(sim), args...; enforce_sim_rngs = enforce_sim_rngs)

function gems_rand(args...; kwargs...)
    @warn "Calling `gems_rand` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.rand(args...)
end


"""
    gems_sample(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS, kwargs...)
    gems_sample(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS, kwargs...)
    
Reproducibility-safe version of `StatsBase.sample`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
If `enforce_sim_rngs` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
function gems_sample(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS, kwargs...)
    # throw error if global RNG is used and enforcement is enabled
    enforce_sim_rngs && rng == Random.default_rng() && throw(ArgumentError("Using the global RNG in `gems_sample`."))
    return StatsBase.sample(rng, args...; kwargs...)
end
gems_sample(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS, kwargs...) = gems_sample(rng(sim), args...; enforce_sim_rngs = enforce_sim_rngs, kwargs...)

function gems_sample(args...; kwargs...)
    @warn "Calling `gems_sample` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return StatsBase.sample(args...; kwargs...)
end


"""
    gems_sample!(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS, kwargs...)
    gems_sample!(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS, kwargs...)

Reproducibility-safe version of `StatsBase.sample!`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
If `enforce_sim_rngs` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
function gems_sample!(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS, kwargs...)
    # throw error if global RNG is used and enforcement is enabled
    enforce_sim_rngs && rng == Random.default_rng() && throw(ArgumentError("Using the global RNG in `gems_sample!`."))
    return StatsBase.sample!(rng, args...; kwargs...)
end
gems_sample!(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS, kwargs...) = gems_sample!(rng(sim), args...; enforce_sim_rngs = enforce_sim_rngs, kwargs...)

function gems_sample!(args...; kwargs...)
    @warn "Calling `gems_sample!` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return StatsBase.sample!(args...; kwargs...)
end


"""
    gems_shuffle!(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)
    gems_shuffle!(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)

Reproducibility-safe version of `Random.shuffle!`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
If `enforce_sim_rngs` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
function gems_shuffle!(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)
    # throw error if global RNG is used and enforcement is enabled
    enforce_sim_rngs && rng == Random.default_rng() && throw(ArgumentError("Using the global RNG in `gems_shuffle!`."))
    return Random.shuffle!(rng, args...)
end
gems_shuffle!(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS) = gems_shuffle!(rng(sim), args...; enforce_sim_rngs = enforce_sim_rngs)

function gems_shuffle!(args...)
    @warn "Calling `gems_shuffle!` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.shuffle!(args...)
end


"""
    gems_shuffle(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)
    gems_shuffle(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)

Reproducibility-safe version of `Random.shuffle`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
If `enforce_sim_rngs` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
function gems_shuffle(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)
    enforce_sim_rngs && rng == Random.default_rng() && throw(ArgumentError("Using the global RNG in `gems_shuffle`."))
    return Random.shuffle(rng, args...)
end
gems_shuffle(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS) = gems_shuffle(rng(sim), args...; enforce_sim_rngs = enforce_sim_rngs)

function gems_shuffle(args...)
    @warn "Calling `gems_shuffle` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.shuffle(args...)
end


"""
    gems_randn(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)
    gems_randn(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)

Reproducibility-safe version of `Random.randn`. Always pass a seeded `AbstractRNG` from the simulation object to ensure deterministic results.
If `enforce_sim_rngs` is set to `true`, an error is thrown when the global RNG is used.
Mainly used for debugging purposes.
"""
function gems_randn(rng::AbstractRNG, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS)
    # throw error if global RNG is used and enforcement is enabled
    enforce_sim_rngs && rng == Random.default_rng() && throw(ArgumentError("Using the global RNG in `gems_randn`."))
    return Random.randn(rng, args...)
end
gems_randn(sim::Simulation, args...; enforce_sim_rngs::Bool = ENFORCE_SIM_RNGS) = gems_randn(rng(sim), args...; enforce_sim_rngs = enforce_sim_rngs)

function gems_randn(args...)
    @warn "Calling `gems_randn` without a specific RNG is discouraged. Using the global RNG, which may break simulation reproducibility."
    return Random.randn(args...)
end