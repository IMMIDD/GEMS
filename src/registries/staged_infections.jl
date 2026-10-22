"""
    _PendingInfection

Per-thread transfer struct staged in `infection_buffers` during the threaded contact
phase, then logged and drained into the individual cache / registry by
`flush_pending_infections!`, which assigns the infection id.
"""
struct _PendingInfection
    # the flush commits to it directly; `host_id` keys the dedup without touching it
    host::Individual
    host_id::Int32
    infecter_id::Int32
    source_infection_id::Int32
    setting_id::Int32
    infecter_position::Int32
    setting_type::Char
    tick::Int16
    pathogen_id::Int8
    progression_id::Int8
    type_rank::UInt8
    dp::DiseaseProgression
end

# canonical order of the spread loop nest: setting type, then setting, then infecter within it.
# The smallest key wins its (host, pathogen); exact ties go to whichever is scanned first.
const _DeduplicationKey = Tuple{UInt8, Int32, Int32}
@inline _deduplication_key(p::_PendingInfection)::_DeduplicationKey =
    (p.type_rank, p.setting_id, p.infecter_position)

"""
    _EndedInfection

Per-thread transfer struct staged in `removal_buffers` when an infection ends, then drained
by `flush_ended_infections!`. `index` is the cache slot index (`is_overflow == false`) or the
overflow node index (`is_overflow == true`). `pathogen_id == DEFAULT_PATHOGEN_ID` grants no
immunity (the death path).
"""
struct _EndedInfection
    host::Individual
    index::Int32
    recovery::Int16
    pathogen_id::Int8
    is_overflow::Bool
end
