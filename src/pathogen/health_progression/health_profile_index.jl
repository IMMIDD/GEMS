export HealthProfileIndex

###
### HEALTH PROFILE INDEX
###
### The routing table a health progression policy is handed: from an infection's
### (pathogen_id, progression_id) to the `HealthProfile` its progression category carries.
###

"""
    HealthProfileIndex()
    HealthProfileIndex(entries::Pair...)

Lookup from `(pathogen_id, progression_id)` to the `HealthProfile` embedded on that infection's
progression category. A category carrying none has no entry. Handed to
`calculate_health_progression!` so a policy can draw the care of any infection it reasons about.
"""
struct HealthProfileIndex
    profiles::Dict{NTuple{2,Int8}, HealthProfile}

    HealthProfileIndex() = new(Dict{NTuple{2,Int8}, HealthProfile}())
end

function HealthProfileIndex(entries::Pair...)
    index = HealthProfileIndex()
    for (pathogen, (category, profile)) in entries
        slot = progression_index(pathogen, category)
        slot == 0 && throw(ArgumentError("pathogen $(name(pathogen)) has no $category progression."))
        index[(id(pathogen), slot)] = profile
    end
    return index
end

@inline Base.getindex(index::HealthProfileIndex, key::NTuple{2,Int8}) = index.profiles[key]
@inline Base.setindex!(index::HealthProfileIndex, profile::HealthProfile, key::NTuple{2,Int8}) =
    (index.profiles[key] = profile)
@inline Base.get(index::HealthProfileIndex, key::NTuple{2,Int8}, default) = get(index.profiles, key, default)
@inline Base.haskey(index::HealthProfileIndex, key::NTuple{2,Int8}) = haskey(index.profiles, key)
Base.length(index::HealthProfileIndex) = length(index.profiles)
Base.isempty(index::HealthProfileIndex) = isempty(index.profiles)
Base.keys(index::HealthProfileIndex) = keys(index.profiles)
Base.iterate(index::HealthProfileIndex, state...) = iterate(index.profiles, state...)

function Base.show(io::IO, index::HealthProfileIndex)
    isempty(index) && return print(io, "HealthProfileIndex(empty)")
    res = "HealthProfileIndex($(length(index)) entries)\n"
    for (pathogen_id, progression_id) in sort!(collect(keys(index)))
        res *= "└ pathogen $pathogen_id, progression $progression_id: " *
            "$(typeof(index[(pathogen_id, progression_id)]))\n"
    end
    print(io, res)
end

"""
    _health_profile(index::HealthProfileIndex, infection::InfectionState)

The profile indexed for `infection`, or `nothing` if its category carries none. No tier check is
needed: only categories carrying health have an entry.
"""
@inline _health_profile(index::HealthProfileIndex, infection::InfectionState) =
    get(index, (infection.pathogen_id, infection.progression_id), nothing)
