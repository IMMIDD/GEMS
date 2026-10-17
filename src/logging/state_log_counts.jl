###
### STATE LOG COUNTS
### What each thread counted for the state log during a tick, where it already read the
### individuals, so that `log_stepinfo` need not read them again
###

# One thread's counts: the disease update's, plus the changes after it in the infection flush and in tests,
# and the quarantine update's
mutable struct _StateLogCounts
    exposed::Int
    detected::Int
    # severe or hospitalized after the disease update, whose open settings the log counts
    in_care::Vector{Individual}
    quarantined::Int
    quarantined_students::Int
    isolated_students::Int # quarantined students who are infected
    quarantined_workers::Int
    isolated_workers::Int # quarantined workers who are infected
    # open classes and offices of quarantined individuals
    missed_classes::Int
    missed_offices::Int
end

_StateLogCounts() = _StateLogCounts(0, 0, Individual[], 0, 0, 0, 0, 0, 0, 0)

function _reset!(counts::_StateLogCounts)
    counts.exposed = 0
    counts.detected = 0
    empty!(counts.in_care)
    counts.quarantined = 0
    counts.quarantined_students = 0
    counts.isolated_students = 0
    counts.quarantined_workers = 0
    counts.isolated_workers = 0
    counts.missed_classes = 0
    counts.missed_offices = 0
    return counts
end

# Counts an individual from what its last disease update found; everyone it counts stays active.
@inline function _count_for_state_log!(counts::_StateLogCounts, indiv::Individual, s::_UpdateState)
    s.exposed && (counts.exposed += 1)
    s.detected && (counts.detected += 1)
    s.in_care && push!(counts.in_care, indiv)
    return nothing
end

# Counts a quarantined individual. `classes_open` (`offices_open`) is true if no class (office) is closed.
@inline function _count_quarantined!(counts::_StateLogCounts, indiv::Individual, plans::ActivityPlanStore,
        s_classes::Vector{SchoolClass}, offs::Vector{Office}, classes_open::Bool, offices_open::Bool)
    counts.quarantined += 1
    if is_student(indiv, plans)
        counts.quarantined_students += 1
        if is_infected(indiv)
            counts.isolated_students += 1
        end
    end
    if is_working(indiv, plans)
        counts.quarantined_workers += 1
        if is_infected(indiv)
            counts.isolated_workers += 1
        end
    end
    counts.missed_classes += _open_memberships(plans, indiv, s_classes, classes_open)
    counts.missed_offices += _open_memberships(plans, indiv, offs, offices_open)
    return nothing
end
