export process_measure


# Convenience constructors: wrap a single focal object. Defined here (not on the struct)
# so they can name IStrategy/SStrategy, which don't exist yet at the forward declaration.
Handover(i::Individual, follow_up::Union{IStrategy, Nothing}) = Handover([i], follow_up)
Handover(s::Setting, follow_up::Union{SStrategy, Nothing}) = Handover([s], follow_up)

"""
    focal_objects(h::Handover)

Returns the Vector of focal objects associated with a `Handover` struct. 
"""
focal_objects(h::Handover) = h.focal_objects

"""
    follow_up(h::Handover)

Returns the follow-up strategy  associated with a `Handover` struct.
"""
follow_up(h::Handover) = h.follow_up

"""
    apply_followup!(sim::Simulation, focal, fu)

Triggers the follow-up strategy `fu` for `focal` (a single `Individual`/`Setting` or a
vector of them). No-op if `fu` is `nothing`.
"""
apply_followup!(sim::Simulation, ::Union{Individual, Setting}, ::Nothing) = nothing
apply_followup!(sim::Simulation, ::AbstractVector, ::Nothing) = nothing
apply_followup!(sim::Simulation, i::Individual, fu::IStrategy) = trigger_strategy(fu, i, sim)
apply_followup!(sim::Simulation, s::Setting, fu::SStrategy) = trigger_strategy(fu, s, sim)
function apply_followup!(sim::Simulation, objs::AbstractVector, fu::Strategy)
    for o in objs
        trigger_strategy(fu, o, sim)
    end
end

###
### MEASURES
###

"""
    i_measuretypes()

Returns a list of all `IMeasure` types available.
"""
i_measuretypes() = subtypes(IMeasure)

"""
    s_measuretypes()

Returns a list of all `SMeasure` types available.
"""
s_measuretypes() = subtypes(SMeasure)

"Abstract wrapper function for intervention processing. Requires contrete subtype implementation"
function process_measure(sim::Simulation, ind::Individual, intervention::IMeasure)
    error("process_intervention(...) is not defined for concrete IndividualMeasure $(typeof(intervention))")
end

"Abstract wrapper function for intervention processing. Requires contrete subtype implementation"
function process_measure(sim::Simulation, ind::Individual, intervention::SMeasure)
    error("process_intervention(...) is not defined for concrete SettingMeasure $(typeof(intervention))")
end



###
### INCLUDE MEASURES
###


# include all Julia files from the "measures"-folder
dir = _basefolder() * "/src/interventions/measures/"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)