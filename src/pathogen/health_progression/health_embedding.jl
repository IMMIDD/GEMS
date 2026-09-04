###
### HEALTH EMBEDDING
###
### Build-time convenience that lets a progression category carry a `HealthProfile` in its `health`
### field (via flat kwargs or a prebuilt object) and harvests those into a `PerPathogenHealthProgression`
### when the simulation is assembled.
###

"""
    _health_profile_type(::Type{<:ProgressionCategory})

The `HealthProfile` type a progression category routes embedded health params into, or `nothing`
if the tier takes no host health. Overridden per category
(e.g. `_health_profile_type(::Type{Severe}) = SevereHealthProfile`).
"""
_health_profile_type(::Type{<:ProgressionCategory}) = nothing

"""
    _embedded_health_profile(c::ProgressionCategory)

The `HealthProfile` embedded in `c`, or `nothing` if its tier takes no host health.
"""
_embedded_health_profile(c::ProgressionCategory) = _health_profile_type(typeof(c)) === nothing ? nothing : c.health

"""
    _has_embedded_health_profile(p)

`true` if any of pathogen `p`'s progression categories carries an embedded `HealthProfile`.
"""
_has_embedded_health_profile(p) = any(c -> _embedded_health_profile(c) !== nothing, p.progressions)

"""
    _embed_health(::Type{C}, health, care, health_params) where {C<:ProgressionCategory}

Resolves the embedded `HealthProfile` for category `C` from either a prebuilt `health` object
or flat `health_params` (mutually exclusive; `nothing` if neither). Keys are validated against
`_health_profile_type(C)`. `care` is the deprecated spelling of `health`.
"""
function _embed_health(::Type{C}, health::Union{Nothing,HealthProfile},
        care::Union{Nothing,HealthProfile}, health_params) where {C<:ProgressionCategory}
    profile_type = _health_profile_type(C)
    if !isnothing(care)
        isnothing(health) || throw(ArgumentError("provide either `health` or the deprecated `care`, not both"))
        @warn "`care` is deprecated for $C; use `health` instead. It also carries mortality, not just care."
        health = care
    end
    if !isnothing(health)
        isempty(health_params) || throw(ArgumentError("provide either `health` or individual health parameters, not both"))
        return health
    end
    isempty(health_params) && return nothing
    for k in keys(health_params)
        k in fieldnames(profile_type) || throw(ArgumentError("unknown health parameter `$k` for $C"))
    end
    return profile_type(; health_params...)
end

"""
    _baseline_profile(baseline, profile_type)

The baseline `DefaultHealthProgression`'s profile for `profile_type`'s tier, or `nothing` if there is
no baseline or the tier is not one it covers.
"""
function _baseline_profile(baseline, profile_type)
    isnothing(baseline) && return nothing
    profile_type === SevereHealthProfile && return baseline.severe
    profile_type === CriticalHealthProfile && return baseline.critical
    return nothing
end

"""
    _harvest_health_progression(pathogens, baseline = nothing)

Assembles a `PerPathogenHealthProgression` keyed by `(pathogen_id, 1-based slot)` from the care
embedded on every category defining `_health_profile_type`. A category embedding none falls back to
`baseline` (the tier profiles of a `[HealthProgression]` section), and is warned about when there is none.
"""
function _harvest_health_progression(pathogens, baseline = nothing)
    profiles = Dict{NTuple{2,Int8}, HealthProfile}()
    for p in pathogens
        pid = id(p)
        for (k, c) in enumerate(p.progressions)
            profile_type = _health_profile_type(typeof(c))
            isnothing(profile_type) && continue
            profile = _embedded_health_profile(c)
            if isnothing(profile)
                profile = _baseline_profile(baseline, profile_type)
                isnothing(profile) && @warn "Pathogen $(name(p)) ($(id(p))): $(typeof(c)) carries no " *
                    "care; its infections will demand no hospitalization and cause no deaths."
                isnothing(profile) && continue
            end
            profiles[(pid, Int8(k))] = profile
        end
    end
    return PerPathogenHealthProgression(profiles)
end
