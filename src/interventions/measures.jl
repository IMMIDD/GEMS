export Handover, process_measure, i_measuretypes, s_measuretypes

###
### HANDOVER STRUCT
###

"""
    Handover

The `Handover` struct provides a standard data structure for handling
outputs of the `process_measure()` functions. It is being used
to pass follow-up strategies to focal objects that are being
determined within the `process_measure()` functions. The
`Handover`s organize how follow-up strategies are passed to the
event queue. There is no application for `Handover`s outside
of `process_measure()` functions.

# Fields

- `focal_objects::Union{Vector{<:Individual},Vector{<:Setting}}`:
    List of focal objects (either all `Individual`s or all `Setting`s)
- `follow_up::Union{<:Strategy, Nothing}`: Strategy that shall be
    triggered for all focus objects in the `focal_objects` list

# Examples

The code below defines how a `Test` measure shall be processed.
First, the passed individual `ind` is being tested. The function then
returns a new `Handover` with the focus object (the individual) and
the either positive- or negative-follow-up stategy that are
defined in the `Test` measure. 

```julia
function process_measure(sim::Simulation, ind::Individual, test::Test)
    test_pos = apply_test(ind, test |> type, sim, test |> reportable)
    return Handover(ind, test_pos ? test |> positive_followup : test |> negative_followup)
end
```

The handovers can be instantiated with single focal objects (`Individual`s or `Setting`s)
as well as vectors of focal objects (`Vector{Individual}` or `Vector{Setting}`).
It's also possible to instantiate a Handover with `nothing` as the `follow_up` strategy
which is sometimmes helpful if you don't know whether there will be a 
subsequent strategy or not.

Here are some more examples on how to instantiate `Handover`s:

```julia
i1 = Indiviual(...)
i2 = Indiviual(...)
s = Household(...)
istr = IStrategy("my_istr", sim)
sstr = SStrategy("my_sstr", sim)

h1 = Handover(i1, istr)
h2 = Handover([i1, i2], istr)
h3 = Handover(s, nothing)
h4 = Handover([s], sstr)
```

**Note**: Naturally, A `Handover` must either have all `Individual`s and an `IStrategy` or
 all `Settings`s and an `SStrategy`.
"""
struct Handover

    focal_objects::Union{Vector{<:Individual},Vector{<:Setting}}
    follow_up::Union{<:Strategy, Nothing}

    Handover(s::Setting, follow_up::Union{SStrategy, Nothing}) = new([s], follow_up)
    Handover(s::Vector{<:Setting}, follow_up::Union{SStrategy, Nothing}) = new(s, follow_up)
    Handover(i::Individual, follow_up::Union{IStrategy, Nothing}) = new([i], follow_up)
    Handover(i::Vector{<:Individual}, follow_up::Union{IStrategy, Nothing}) = new(i, follow_up)
end

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
dir = basefolder() * "/src/interventions/measures/"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)