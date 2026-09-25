###
### ChunkedVector
###

"""
    ChunkedVector{T} <: AbstractVector{T}

Append-only vector stored in fixed-size chunks. Growing it allocates one new chunk instead of
reallocating and copying all entries, so it holds at most one partly filled chunk of unused
capacity. Loggers use it for columns that grow to millions of entries.

Entries can also sit in one contiguous `head` before the chunks, where `_compact!` moves them.
"""
mutable struct ChunkedVector{T} <: AbstractVector{T}
    head::Vector{T}
    chunks::Vector{Vector{T}}
    # entries in the chunks, after the head
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
    return ChunkedVector{T}(T[], Vector{T}[], 0, trailing_zeros(chunk_size))
end

chunk_size(v::ChunkedVector) = 1 << v.shift

Base.size(v::ChunkedVector) = (length(v.head) + v.len,)
Base.IndexStyle(::Type{<:ChunkedVector}) = IndexLinear()

@inline function Base.getindex(v::ChunkedVector, i::Int)
    @boundscheck checkbounds(v, i)
    h = length(v.head)
    i <= h && return @inbounds v.head[i]
    j = i - h - 1
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
    for v in vs
        copyto!(out, pos, v.head, 1, length(v.head))
        pos += length(v.head)
        for (k, chunk) in enumerate(v.chunks)
            n = min(chunk_size(v), v.len - (k - 1) * chunk_size(v))
            copyto!(out, pos, chunk, 1, n)
            pos += n
        end
    end
    return out
end

"""
    _compact!(vs::AbstractVector{ChunkedVector{T}})

Moves the entries of all `vs`, in `vcat` order, into the head of `vs[1]` and returns that head;
the others end up empty. Frees each chunk once it is copied, so at most one column's worth of
memory is held twice. Appending afterwards works as before.
"""
function _compact!(vs::AbstractVector{ChunkedVector{T}}) where {T}
    head = vs[1].head
    sizehint!(head, sum(length, vs; init = 0))
    for (k, v) in enumerate(vs)
        k == 1 || append!(head, v.head)
        for c in eachindex(v.chunks)
            n = min(chunk_size(v), v.len - (c - 1) * chunk_size(v))
            append!(head, view(v.chunks[c], 1:n))
            v.chunks[c] = T[]
        end
        empty!(v.chunks)
        v.len = 0
        k == 1 || (v.head = T[])
    end
    return head
end
