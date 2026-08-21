###
### CARE EMBEDDING
###
### Build-time convenience that lets a progression category carry a `HealthProfile` in its `care`
### field (via flat kwargs or a prebuilt object) and harvests those into a `DefaultHealthProgression`
### when the simulation is assembled.
###

"""
    _health_profile_type(::Type{<:ProgressionCategory})

The `HealthProfile` type a progression category routes embedded health params into, or `nothing`
if the tier takes no host care. Overridden per category
(e.g. `_health_profile_type(::Type{Severe}) = SevereHealthProfile`).
"""
_health_profile_type(::Type{<:ProgressionCategory}) = nothing

"""
    _embedded_health_profile(c::ProgressionCategory)

The `HealthProfile` embedded in `c`, or `nothing` if its tier takes no host care.
"""
_embedded_health_profile(c::ProgressionCategory) = _health_profile_type(typeof(c)) === nothing ? nothing : c.care

"""
    _has_embedded_health_profile(p)

`true` if any of pathogen `p`'s progression categories carries an embedded `HealthProfile`.
"""
_has_embedded_health_profile(p) = any(c -> _embedded_health_profile(c) !== nothing, p.progressions)

"""
    _embed_care(::Type{C}, care, care_params) where {C<:ProgressionCategory}

Resolves the embedded `HealthProfile` for category `C` from either a prebuilt `care` object
or flat, care-only `care_params` (mutually exclusive; `nothing` if neither). Keys are
validated against `_health_profile_type(C)`.
"""
function _embed_care(::Type{C}, care::Union{Nothing,HealthProfile}, care_params) where {C<:ProgressionCategory}
    profile_type = _health_profile_type(C)
    if !isnothing(care)
        isempty(care_params) || throw(ArgumentError("provide either `care` or individual care parameters, not both"))
        return care
    end
    isempty(care_params) && return nothing
    for k in keys(care_params)
        k in fieldnames(profile_type) || throw(ArgumentError("unknown care parameter `$k` for $C"))
    end
    return profile_type(; care_params...)
end

"""
    _harvest_health_progression(pathogens)

Assembles the global `DefaultHealthProgression` from care embedded on the built-in `Severe` and
`Critical` categories. Care embedded on any other category is left for that category's own
`HealthProgression` to consume. Throws if more than one category per tier carries embedded care.
"""
function _harvest_health_progression(pathogens)
    severe_profile = nothing
    critical_profile = nothing
    for p in pathogens, c in p.progressions
        profile = _embedded_health_profile(c)
        profile === nothing && continue
        if c isa Severe
            isnothing(severe_profile) || throw(ArgumentError("more than one Severe category carries embedded care"))
            severe_profile = profile
        elseif c isa Critical
            isnothing(critical_profile) || throw(ArgumentError("more than one Critical category carries embedded care"))
            critical_profile = profile
        end
    end
    if !isnothing(severe_profile) && !isnothing(critical_profile)
        return DefaultHealthProgression(severe = severe_profile, critical = critical_profile)
    elseif !isnothing(severe_profile)
        return DefaultHealthProgression(severe = severe_profile)
    elseif !isnothing(critical_profile)
        return DefaultHealthProgression(critical = critical_profile)
    end
    return DefaultHealthProgression()
end
