export set_global_seed
export gems_rand
export gems_sample
export gems_sample!
export gems_shuffle
export gems_shuffle!
export gems_randn
export rand_round
export immunity_rng!

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


"""
    _rand_val(val::Union{Distribution, Real}, rng::Xoshiro)::Float64

If the input is a real number, it is returned as is.
If the input is a distribution, a random value is drawn from it.

One method with explicit checks for the common types, so a call on an abstractly typed field
dispatches statically for those.
"""
@inline function _rand_val(val::Union{Distribution, Real}, rng::Xoshiro)::Float64
    val isa Poisson{Float64} && return _draw_val(val, rng)
    val isa Uniform{Float64} && return _draw_val(val, rng)
    val isa LogNormal{Float64} && return _draw_val(val, rng)
    val isa Exponential{Float64} && return _draw_val(val, rng)
    val isa Int && return val
    val isa Float64 && return val
    return _draw_val(val, rng)
end

# kept out of line so `_rand_val` stays small enough to inline
@noinline _draw_val(dist::Distribution, rng::Xoshiro)::Float64 = gems_rand(rng, dist)
@noinline _draw_val(val::Real, ::Xoshiro)::Float64 = val


"""
    rand_round(val::Real, rng::Xoshiro)

If the input is a real number, it is stochastically rounded to an Integer.
"""
function rand_round(val::Real, rng::Xoshiro)
    lower = floor(val)
    frac = val - lower

    return rand(rng) < frac ? Int(lower) + 1 : Int(lower)
end


###
### KEYED IMMUNITY RNG
### Immunity levels are computed on read; the rng a profile gets there is reset from the record first.
###

# a thread's scratch rng and the key it was last reset to
mutable struct _ImmunityRNG
    rng::Xoshiro
    key::UInt64
end

# one per thread, created by that thread on first use; sized in __init__
const _IMMUNITY_RNGS = Union{Nothing, _ImmunityRNG}[]

# folds fields into a key with splitmix64, one at a time
@inline _mix(key::UInt64) = key
@inline function _mix(key::UInt64, field::Integer, rest::Integer...)
    x = (key ⊻ (field % UInt64)) + 0x9e3779b97f4a7c15
    x = (x ⊻ (x >> 30)) * 0xbf58476d1ce4e5b9
    x = (x ⊻ (x >> 27)) * 0x94d049bb133111eb
    return _mix(x ⊻ (x >> 31), rest...)
end

# sets the state from `key`, as `Random.initstate!` does from four words
@inline function _rekey!(rng::Xoshiro, key::UInt64)
    s = ntuple(i -> _mix(key, i), 4)
    rng.s0, rng.s1, rng.s2, rng.s3 = s
    @static if hasfield(Xoshiro, :s4)
        rng.s4 = s[1] + 3s[2] + 5s[3] + 7s[4]
    end
    return rng
end

@inline function _immunity_rng()::_ImmunityRNG
    tid = Threads.threadid()
    r = @inbounds _IMMUNITY_RNGS[tid]
    r === nothing || return r
    return @inbounds _IMMUNITY_RNGS[tid] = _ImmunityRNG(Xoshiro(0), UInt64(0))
end

# this thread's scratch rng, reset to the stream of one host and pathogen
@inline function _keyed_immunity_rng(seed::Int64, host_id::Int32, pathogen_id::Int8)::Xoshiro
    r = _immunity_rng()
    r.key = _mix(UInt64(0), seed, host_id, pathogen_id)
    return _rekey!(r.rng, r.key)
end

"""
    immunity_rng!(rng::Xoshiro, state::ImmunityState, component::Symbol)::Xoshiro

Re-keys the `rng` of `calculate_immunity` to draw anew per acquisition: `:natural` per infection,
`:vaccine` per dose, `:host` back to the stream as passed. Components don't affect each other.
"""
function immunity_rng!(rng::Xoshiro, state::ImmunityState, component::Symbol)::Xoshiro
    r = _immunity_rng()
    # an rng from elsewhere (e.g. a test) is re-keyed from its current state
    base = rng === r.rng ? r.key : _mix(UInt64(0), rng.s0, rng.s1, rng.s2, rng.s3)
    key = component === :host ? base :
        component === :natural ? _mix(base, 1, state.natural_acquired_tick) :
        component === :vaccine ? _mix(base, 2, state.vaccine_acquired_tick, state.dose_number) :
        throw(ArgumentError("unknown immunity component :$component; use :natural, :vaccine or :host"))
    return _rekey!(rng, key)
end
