###
### UPDATE STATES
### What the disease update needs to know about an individual without reading it: when its next
### update can change anything, and what the last one found
###

# One individual's update state, kept densely by population index next to `active_individuals`.
struct _UpdateState
    # the first tick an update can change anything; before it the update is skipped
    next_update::Int16
    # what the last update found, used without reading the individual: infectious for the
    # transmission phase, the rest for the state log (in care: severe or hospitalized)
    infectious::Bool
    exposed::Bool
    detected::Bool
    in_care::Bool
end

# due at the next update, which overwrites the rest
_UpdateState() = _UpdateState(Int16(0), false, false, false, false)

# what an update that finds `indiv` as it is now records
_UpdateState(next_update::Int16, indiv::Individual) = _UpdateState(next_update, infectious(indiv),
    is_exposed(indiv), is_detected(indiv), is_severe(indiv) || is_hospitalized(indiv))
