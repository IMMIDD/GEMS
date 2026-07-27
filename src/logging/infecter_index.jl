###
### InfecterIndex
###

"""
A single infecter-infectee link, buffered per thread until the next merge.
"""
struct _PendingLink
    infecter::Int32
    infectee::Int32
    tick::Int16
end

"""
    InfecterIndex

Inverted index over the `InfectionLogger`, answering "who did individual X infect?"
in time proportional to the number of matches instead of a full scan of the tick window.

For every infecter, the infections they caused form a singly-linked list through `prev`,
whose newest element is `head[infecter]` (`0` marks an empty chain). New links are staged
in per-thread buffers while infections are logged concurrently and are spliced into the
chains during the next (serial) merge, so `head` is never written from multiple threads.

Chains are kept ordered by tick, newest first, which lets a query stop as soon as it walks
past the start of its window.

The index is an implementation detail of the `InfectionLogger` and is built lazily on the
first `get_infections_between` call.
"""
mutable struct InfecterIndex
    # infecter id -> newest entry index, 0 = none
    head::Vector{Int32}

    # entry payload
    infectee::Vector{Int32}
    tick::Vector{Int16}
    prev::Vector{Int32}

    # per-thread staging, drained by _merge_staged!
    staging::Vector{Vector{_PendingLink}}

    function InfecterIndex()
        return new(
            Vector{Int32}(),
            Vector{Int32}(),
            Vector{Int16}(),
            Vector{Int32}(),
            [Vector{_PendingLink}() for _ in 1:Threads.maxthreadid()]
        )
    end
end

"""
    InfecterIndex(id_a::Vector{Vector{Int32}}, id_b::Vector{Vector{Int32}}, ticks::Vector{Vector{Int16}})

Builds an index over infections already recorded in an `InfectionLogger`'s sharded
columns. Used to backfill everything logged before the index existed.
"""
function InfecterIndex(id_a::Vector{Vector{Int32}}, id_b::Vector{Vector{Int32}}, ticks::Vector{Vector{Int16}})
    index = InfecterIndex()

    # size head once from the largest infecter id, so linking never has to grow it
    max_id = Int32(0)
    for shard in id_a
        for a in shard
            a > max_id && (max_id = a)
        end
    end
    max_id > 0 && _grow_head!(index, max_id)

    # each shard is in tick order, which is exactly what _link_merged! expects
    buffers = map(eachindex(id_a)) do s
        buf = Vector{_PendingLink}(undef, length(id_a[s]))
        @inbounds for i in eachindex(buf)
            buf[i] = _PendingLink(id_a[s][i], id_b[s][i], ticks[s][i])
        end
        return buf
    end
    _link_merged!(index, buffers)

    return index
end

"""
    register!(index::InfecterIndex, infecter::Int32, infectee::Int32, tick::Int16)

Stages an infection for inclusion in the index. Called from `log!` while infections are
logged concurrently, so this only appends to a thread-local buffer. Seed infections
(`infecter < 1`) are dropped, as they have no infecter to be traced back to.
"""
@inline function register!(index::InfecterIndex, infecter::Int32, infectee::Int32, tick::Int16)
    infecter < 1 && return nothing
    push!(index.staging[Threads.threadid()], _PendingLink(infecter, infectee, tick))
    return nothing
end

"""
    _grow_head!(index::InfecterIndex, needed::Integer)

Grows the `head` array to `needed` slots, zeroing the new tail. `head` is indexed by
individual id, so it converges on the population size after the first few infections and
this is called rarely.
"""
function _grow_head!(index::InfecterIndex, needed::Integer)
    old_len = length(index.head)
    resize!(index.head, needed)
    fill!(view(index.head, (old_len + 1):Int(needed)), Int32(0))
    return nothing
end

"""
    _link!(index::InfecterIndex, link::_PendingLink)

Appends an entry and splices it to the front of its infecter's chain.
"""
@inline function _link!(index::InfecterIndex, link::_PendingLink)
    a = link.infecter
    a < 1 && return nothing
    a > length(index.head) && _grow_head!(index, a)

    push!(index.infectee, link.infectee)
    push!(index.tick, link.tick)
    @inbounds push!(index.prev, index.head[a])
    @inbounds index.head[a] = Int32(length(index.infectee))
    return nothing
end

"""
    _link_merged!(index::InfecterIndex, buffers::Vector{Vector{_PendingLink}})

Links every staged infection, keeping the chains tick-ordered. Each buffer is already in
tick order, so this is a k-way merge rather than a sort: it repeatedly takes the smallest
tick still at a buffer's cursor and drains that tick's run from every buffer. Not thread-safe; 
only called from the serial merge and from the backfill.
"""
function _link_merged!(index::InfecterIndex, buffers::Vector{Vector{_PendingLink}})
    cursors = ones(Int, length(buffers))

    while true
        # smallest tick still staged anywhere; only the cursor heads can hold it
        t = typemax(Int16)
        remaining = false
        for s in eachindex(buffers)
            c = cursors[s]
            @inbounds if c <= length(buffers[s])
                remaining = true
                buffers[s][c].tick < t && (t = buffers[s][c].tick)
            end
        end
        remaining || break

        for s in eachindex(buffers)
            buf = buffers[s]
            c = cursors[s]
            @inbounds while c <= length(buf) && buf[c].tick == t
                _link!(index, buf[c])
                c += 1
            end
            cursors[s] = c
        end
    end

    return nothing
end

"""
    _merge_staged!(index::InfecterIndex)

Drains every thread's staging buffer into the chains. Must be called from a serial phase.
"""
function _merge_staged!(index::InfecterIndex)
    any(!isempty, index.staging) || return nothing

    _link_merged!(index, index.staging)
    foreach(empty!, index.staging)
    return nothing
end

"""
    _walk_infections_between(index::InfecterIndex, infecter::Int32, start_tick::Int16, end_tick::Int16)

Returns the ids of all individuals `infecter` infected in `[start_tick, end_tick]`, in
chronological order. Walks the infecter's chain newest first and stops once it passes the
start of the window.
"""
function _walk_infections_between(index::InfecterIndex, infecter::Int32, start_tick::Int16, end_tick::Int16)
    result = Vector{Int32}()
    (infecter < 1 || infecter > length(index.head)) && return result

    @inbounds e = index.head[infecter]
    @inbounds while e != 0
        t = index.tick[e]
        t < start_tick && break
        t <= end_tick && push!(result, index.infectee[e])
        e = index.prev[e]
    end

    reverse!(result)
    return result
end
