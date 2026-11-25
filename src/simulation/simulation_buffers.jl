###
### SIMULATION BUFFERS
###

# Temporary working memory.
struct _ScratchBuffers
    contact::Vector{Vector{Individual}}
    # one sampler call's draws, for scaled hosts that call a sampler more than once
    draw::Vector{Vector{Individual}}
    # per shard, the attempt that wins each contested (host, pathogen) this tick
    deduplication_winners::Vector{Dict{Tuple{Int32, Int8}, _DeduplicationKey}}
    # a sampled FindMembers' filtered candidates
    member_filter::Vector{Vector{Individual}}
    # a sampled FindMembers' sampled members
    member_sample::Vector{Vector{Individual}}
end

_ScratchBuffers(deduplication_size_hint::Int) = _ScratchBuffers(
    _thread_local_vector(Vector{Individual}),
    _thread_local_vector(Vector{Individual}),
    _shard_local_vector(Dict{Tuple{Int32, Int8}, _DeduplicationKey}, () -> sizehint!(Dict{Tuple{Int32, Int8}, _DeduplicationKey}(), deduplication_size_hint)),
    _thread_local_vector(Vector{Individual}),
    _thread_local_vector(Vector{Individual})
)

# Data one phase hands to a later one.
struct _StagingBuffers
    # pending infections, by producing thread and owning shard
    infections::Matrix{Vector{_PendingInfection}}
    # ended infections, by producing thread and owning shard
    removals::Matrix{Vector{_EndedInfection}}
    # who each thread's part of the disease-update sweep found dead this tick
    newly_dead::Vector{Vector{Individual}}
    # who each thread's part of the disease-update sweep found newly symptomatic this tick
    newly_symptomatic::Vector{Vector{Individual}}
end

_StagingBuffers(size_hint::Int) = _StagingBuffers(
    _thread_local_matrix(Vector{_PendingInfection}, () -> sizehint!(Vector{_PendingInfection}(), size_hint)),
    _thread_local_matrix(Vector{_EndedInfection}, () -> sizehint!(Vector{_EndedInfection}(), size_hint)),
    _thread_local_vector(Vector{Individual}),
    _thread_local_vector(Vector{Individual})
)

###
### THREAD- AND SHARD-LOCAL BUILDERS
###

"""
    _thread_local_vector(T::Type, make = T)

Returns a `Vector{T}` of `make()` results with one entry per thread id, each created on the thread that uses it.
"""
function _thread_local_vector(T::Type, make = T)
    v = Vector{T}(undef, Threads.maxthreadid())
    # objects allocated back to back share cache lines; each thread's own heap pages keep concurrent writes apart
    Threads.@threads :static for _ in 1:Threads.nthreads()
        v[Threads.threadid()] = make()
    end
    # entries of threads outside the default pool
    for i in eachindex(v)
        isassigned(v, i) || (v[i] = make())
    end
    return v
end

"""
    _shard_local_vector(T::Type, make = T)

Returns a `Vector{T}` of `make()` results with one entry per shard, each created on the thread that processes that shard.
"""
function _shard_local_vector(T::Type, make = T)
    v = Vector{T}(undef, Threads.maxthreadid())
    Threads.@threads :static for s in eachindex(v)
        v[s] = make()
    end
    return v
end

"""
    _thread_local_matrix(T::Type, make = T)

Returns a producer × shard `Matrix{T}` of `make()` results, each row created on the producing thread.
"""
function _thread_local_matrix(T::Type, make = T)
    n = Threads.maxthreadid()
    m = Matrix{T}(undef, n, n)
    # see `_thread_local_vector`
    Threads.@threads :static for _ in 1:Threads.nthreads()
        p = Threads.threadid()
        for s in 1:n
            m[p, s] = make()
        end
    end
    for i in eachindex(m)
        isassigned(m, i) || (m[i] = make())
    end
    return m
end

"""
    _shard_local_matrix(T::Type, make = T)

Returns a producer × shard `Matrix{T}` of `make()` results, each row created on the thread that runs that producer's slot.
"""
function _shard_local_matrix(T::Type, make = T)
    n = Threads.maxthreadid()
    m = Matrix{T}(undef, n, n)
    Threads.@threads :static for p in 1:n
        for s in 1:n
            m[p, s] = make()
        end
    end
    return m
end

"""
    _thread_local_rngs(master::Xoshiro)

Returns one `Xoshiro` per thread id, seeded from `master` in thread-id order, each created on the thread that uses it.
"""
function _thread_local_rngs(master::Xoshiro)
    seeds = [gems_rand(master, UInt) for _ in 1:Threads.maxthreadid()]
    v = Vector{Xoshiro}(undef, length(seeds))
    # every draw writes the generator, so neighbours on one cache line would contend (see `_thread_local_vector`)
    Threads.@threads :static for _ in 1:Threads.nthreads()
        t = Threads.threadid()
        v[t] = Xoshiro(seeds[t])
    end
    for i in eachindex(v)
        isassigned(v, i) || (v[i] = Xoshiro(seeds[i]))
    end
    return v
end
