###
### InfecterIndex
###

"""
A single infecter-infectee link, buffered per thread until the next merge.
"""
struct _PendingLink
    infecter::Int32
    infectee::Int32
    infection_id::Int32
    tick::Int16
    infectiousness_onset::Int16
    recovery::Int16
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

It also keeps each individual's newest infection and its ticks, so tracing can use infections
that have already ended.

The index is an implementation detail of the `InfectionLogger` and is built lazily on the
first `get_infections_between` call.
"""
mutable struct InfecterIndex
    # smallest id `head` covers; slot of an id is `id - offset + 1`, as in Population
    offset::Int32

    # infecter slot -> newest entry index, 0 = none
    head::Vector{Int32}

    # entry payload
    infectee::Vector{Int32}
    tick::Vector{Int16}
    prev::Vector{Int32}

    # infection id -> infecter, 0 = seed or not yet merged
    infecter_of::Vector{Int32}

    # individual slot -> id of their newest infection, 0 = none
    last_infection::Vector{Int32}

    # infection id -> its ticks, kept for infections that ended
    exposure_of::Vector{Int16}
    infectiousness_onset_of::Vector{Int16}
    recovery_of::Vector{Int16}

    # per-thread staging, drained by _merge_staged!
    staging::Vector{Vector{_PendingLink}}

    function InfecterIndex(minid::Int32 = Int32(1), maxid::Int32 = Int32(0))
        slots = maxid >= minid ? Int(maxid) - Int(minid) + 1 : 0
        return new(
            minid,
            zeros(Int32, slots),
            Vector{Int32}(),
            Vector{Int16}(),
            Vector{Int32}(),
            Vector{Int32}(),
            zeros(Int32, slots),
            Vector{Int16}(),
            Vector{Int16}(),
            Vector{Int16}(),
            [Vector{_PendingLink}() for _ in 1:Threads.maxthreadid()]
        )
    end
end

"""
    _id_range(id_a::AbstractVector{<:AbstractVector{Int32}}, id_b::AbstractVector{<:AbstractVector{Int32}})

Smallest and largest individual id present in the sharded infecter and infectee columns,
ignoring seed infections' infecters (`id < 1`). Returns an empty range when there are none.
"""
function _id_range(id_a::AbstractVector{<:AbstractVector{Int32}}, id_b::AbstractVector{<:AbstractVector{Int32}})
    lo = typemax(Int32)
    hi = Int32(0)
    for col in (id_a, id_b), shard in col
        for a in shard
            a < 1 && continue
            a < lo && (lo = a)
            a > hi && (hi = a)
        end
    end
    return hi > 0 ? (lo, hi) : (Int32(1), Int32(0))
end

"""
    InfecterIndex(infection_ids, id_a, id_b, ticks, onsets, recoveries; minid, maxid)

Backfills an index from an `InfectionLogger`'s sharded columns. `minid`/`maxid` size
`head` in one allocation; when unset (`maxid = 0`) they are taken from the ids present in the data.
"""
function InfecterIndex(infection_ids::AbstractVector{<:AbstractVector{Int32}}, id_a::AbstractVector{<:AbstractVector{Int32}},
        id_b::AbstractVector{<:AbstractVector{Int32}}, ticks::AbstractVector{<:AbstractVector{Int16}},
        onsets::AbstractVector{<:AbstractVector{Int16}}, recoveries::AbstractVector{<:AbstractVector{Int16}};
        minid::Int32 = Int32(1), maxid::Int32 = Int32(0))

    maxid < minid && ((minid, maxid) = _id_range(id_a, id_b))
    index = InfecterIndex(minid, maxid)

    # each shard is in tick order, which is what _link_merged! expects
    buffers = map(eachindex(id_a)) do s
        buf = Vector{_PendingLink}(undef, length(id_a[s]))
        @inbounds for i in eachindex(buf)
            buf[i] = _PendingLink(id_a[s][i], id_b[s][i], infection_ids[s][i], ticks[s][i], onsets[s][i], recoveries[s][i])
        end
        return buf
    end
    _link_merged!(index, buffers)

    return index
end

"""
    register!(index::InfecterIndex, infecter::Int32, infectee::Int32, tick::Int16, infection_id::Int32, infectiousness_onset::Int16, recovery::Int16)

Stages an infection for inclusion in the index. Called from `log!` while infections are
logged concurrently, so this only appends to a thread-local buffer.
"""
@inline function register!(index::InfecterIndex, infecter::Int32, infectee::Int32, tick::Int16, infection_id::Int32,
        infectiousness_onset::Int16, recovery::Int16)
    push!(index.staging[Threads.threadid()], _PendingLink(infecter, infectee, infection_id, tick, infectiousness_onset, recovery))
    return nothing
end

"""
    _slot(index::InfecterIndex, id::Int32)

Slot of an id in `head`. Callers bounds-check, as `get_individual_by_id` does.
"""
@inline _slot(index::InfecterIndex, id::Int32) = Int(id) - Int(index.offset) + 1

"""
    _link!(index::InfecterIndex, link::_PendingLink)

Records the infection's ticks as its infectee's newest infection. Unless it is a seed, also
appends an entry, splices it to the front of its infecter's chain and records the infecter
of its infection id.
"""
@inline function _link!(index::InfecterIndex, link::_PendingLink)
    k = Int(link.infection_id)
    if k > length(index.infecter_of)
        n = k - length(index.infecter_of)
        append!(index.infecter_of, zeros(Int32, n))
        append!(index.exposure_of, zeros(Int16, n))
        append!(index.infectiousness_onset_of, zeros(Int16, n))
        append!(index.recovery_of, zeros(Int16, n))
    end
    @inbounds index.exposure_of[k] = link.tick
    @inbounds index.infectiousness_onset_of[k] = link.infectiousness_onset
    @inbounds index.recovery_of[k] = link.recovery

    # a logger without a declared id range grows with the infectees it sees
    b = _slot(index, link.infectee)
    b < 1 && throw(ArgumentError("infectee id $(link.infectee) is below the index range starting at $(index.offset)"))
    b > length(index.last_infection) && append!(index.last_infection, zeros(Int32, b - length(index.last_infection)))
    @inbounds index.last_infection[b] = link.infection_id

    a = link.infecter
    a < 1 && return nothing

    slot = _slot(index, a)
    if slot < 1 || slot > length(index.head)
        throw(ArgumentError("infecter id $a is outside the index range " *
            "$(index.offset)..$(index.offset + length(index.head) - 1). The range comes " *
            "from the population's minid/maxid; a logger built without one covers only " *
            "the ids it was backfilled from."))
    end

    push!(index.infectee, link.infectee)
    push!(index.tick, link.tick)
    @inbounds push!(index.prev, index.head[slot])
    @inbounds index.head[slot] = Int32(length(index.infectee))
    @inbounds index.infecter_of[k] = a
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

Returns the ids of all individuals `infecter` infected in `[start_tick, end_tick]` and the
ticks of those infections, in chronological order. Walks the infecter's chain newest first
and stops once it passes the start of the window.
"""
function _walk_infections_between(index::InfecterIndex, infecter::Int32, start_tick::Int16, end_tick::Int16)
    result = Vector{Int32}()
    ticks = Vector{Int16}()
    infecter < 1 && return result, ticks

    slot = _slot(index, infecter)
    (slot < 1 || slot > length(index.head)) && return result, ticks

    @inbounds e = index.head[slot]
    @inbounds while e != 0
        t = index.tick[e]
        t < start_tick && break
        if t <= end_tick
            push!(result, index.infectee[e])
            push!(ticks, t)
        end
        e = index.prev[e]
    end

    reverse!(result)
    reverse!(ticks)
    return result, ticks
end

"""
    _infecter_of(index::InfecterIndex, infection_id::Int32)

Returns the infecter of the infection `infection_id`, or `0` for seeds and unknown ids.
"""
function _infecter_of(index::InfecterIndex, infection_id::Int32)
    1 <= infection_id <= length(index.infecter_of) || return Int32(0)
    return @inbounds index.infecter_of[infection_id]
end

"""
    _last_infection(index::InfecterIndex, id::Int32)

Returns the newest infection of individual `id` as `(infection_id, infecter, exposure, infectiousness_onset, recovery)`,
with `infecter` 0 for a seed, or `nothing` if they were never infected.
"""
function _last_infection(index::InfecterIndex, id::Int32)
    slot = _slot(index, id)
    1 <= slot <= length(index.last_infection) || return nothing
    k = @inbounds index.last_infection[slot]
    k == 0 && return nothing
    return @inbounds (infection_id = k, infecter = index.infecter_of[k], exposure = index.exposure_of[k],
        infectiousness_onset = index.infectiousness_onset_of[k], recovery = index.recovery_of[k])
end
