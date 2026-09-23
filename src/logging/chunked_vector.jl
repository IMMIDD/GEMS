###
### ChunkedVector
###

"""
    ChunkedVector{T} <: AbstractVector{T}

Append-only vector stored in fixed-size chunks. Growing it allocates one new chunk instead of
reallocating and copying all entries, so it holds at most one partly filled chunk of unused
capacity. Loggers use it for columns that grow to millions of entries.
"""
mutable struct ChunkedVector{T} <: AbstractVector{T}
    chunks::Vector{Vector{T}}
    len::Int
    # chunks hold 2^shift entries, so an index splits into chunk and position by bit operations
    shift::Int
end

"""
    ChunkedVector{T}(; chunk_size::Int = 2^14)

Creates an empty `ChunkedVector`. `chunk_size` must be a power of two.
"""
function ChunkedVector{T}(; chunk_size::Int = 2^14) where {T}
    ispow2(chunk_size) || throw(ArgumentError("chunk_size must be a power of two, got $chunk_size"))
    return ChunkedVector{T}(Vector{T}[], 0, trailing_zeros(chunk_size))
end

chunk_size(v::ChunkedVector) = 1 << v.shift

Base.size(v::ChunkedVector) = (v.len,)
Base.IndexStyle(::Type{<:ChunkedVector}) = IndexLinear()

@inline function Base.getindex(v::ChunkedVector, i::Int)
    @boundscheck checkbounds(v, i)
    j = i - 1
    return @inbounds v.chunks[(j >> v.shift) + 1][(j & (chunk_size(v) - 1)) + 1]
end

@inline function Base.push!(v::ChunkedVector{T}, x) where {T}
    pos = v.len & (chunk_size(v) - 1)
    # a full last chunk (or none yet) gets a new one
    pos == 0 && push!(v.chunks, Vector{T}(undef, chunk_size(v)))
    @inbounds v.chunks[end][pos + 1] = x
    v.len += 1
    return v
end

# copies chunk by chunk rather than entry by entry
function Base.vcat(vs::ChunkedVector{T}...) where {T}
    out = Vector{T}(undef, sum(length, vs; init = 0))
    pos = 1
    for v in vs, (k, chunk) in enumerate(v.chunks)
        n = min(chunk_size(v), v.len - (k - 1) * chunk_size(v))
        copyto!(out, pos, chunk, 1, n)
        pos += n
    end
    return out
end
