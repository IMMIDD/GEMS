###
### STATE LOG COUNTS
### What each thread counted for the state log during a tick, where it already read the
### individuals, so that `log_stepinfo` need not read them again
###

# One thread's counts: the disease update's, plus the changes after it in the infection flush and in tests
mutable struct _StateLogCounts
    exposed::Int
    detected::Int
    # severe or hospitalized after the disease update, whose open settings the log counts
    in_care::Vector{Individual}
end

_StateLogCounts() = _StateLogCounts(0, 0, Individual[])

function _reset!(counts::_StateLogCounts)
    counts.exposed = 0
    counts.detected = 0
    empty!(counts.in_care)
    return counts
end

# Counts an individual just updated by the disease update; everyone it counts stays active.
@inline function _count_for_state_log!(counts::_StateLogCounts, indiv::Individual)
    is_exposed(indiv) && (counts.exposed += 1)
    is_detected(indiv) && (counts.detected += 1)
    (is_severe(indiv) || is_hospitalized(indiv)) && push!(counts.in_care, indiv)
    return nothing
end
