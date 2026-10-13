export PriorImmunity

###
### TYPES
###

# oldest acquisition; leaves room for 16383 run ticks before `tick - acquired_tick` overflows Int16
const MAX_PRIOR_TICKS_AGO = 16384

"""
    PriorImmunity(; pathogen = "", fraction, age_groups = String[], ags = nothing, ticks_ago)

Natural immunity that a `fraction` of the population (per age group and, optionally, within the
region `ags`) acquired `ticks_ago` ticks before the start, a number or a `Distribution` drawn per individual.

# Fields
- `pathogen::String`: Pathogen the immunity is against; empty string = the only pathogen, `ALL_PATHOGENS` = every pathogen (each with its own draw)
- `fraction::Vector{Float64}`: Fraction of each age group (or a single fraction for everyone) that is immune
- `age_groups::Vector{AgeGroup}`: Age groups; empty = no grouping, ages outside all groups get no immunity
- `ags::Union{Int64, Nothing}`: Community identification number of the region; `nothing` = whole population
- `ticks_ago::Union{Float64, Distribution}`: Ticks between acquisition and tick 0, between 1 and `MAX_PRIOR_TICKS_AGO` (16384).
  Values are rounded up; draws beyond the bounds are clamped.

Several entries for the same individual and pathogen overwrite each other; the last one applied wins.

# Example
```julia
prior = PriorImmunity(age_groups = ["-17", "18-64", "65-"], fraction = [0.2, 0.35, 0.5], ticks_ago = Uniform(30, 365))
sim = Simulation(prior_immunity = prior)
```
"""
struct PriorImmunity <: AbstractPriorImmunity
    pathogen::String
    fraction::Vector{Float64}
    age_groups::Vector{AgeGroup}
    ags::Union{Int64, Nothing}
    ticks_ago::Union{Float64, Distribution}

    # untyped vectors, since TOML reads mixed arrays like [0, 0.5] as Vector{Any}
    function PriorImmunity(; pathogen::String = "", fraction::Union{Real, AbstractVector},
            age_groups::AbstractVector = String[], ags::Union{Integer, Nothing} = nothing,
            ticks_ago::Union{Real, Distribution})
        frcs = Float64.(isa(fraction, Real) ? [fraction] : fraction)
        grps = AgeGroup.(String.(age_groups))

        any(f -> !(0.0 <= f <= 1.0), frcs) && throw(ArgumentError("Fractions must be between 0 and 1 (got $frcs)."))
        if isempty(grps)
            length(frcs) != 1 && throw(ArgumentError("Without age groups, exactly one fraction must be provided (got $(length(frcs)))."))
        else
            length(frcs) != length(grps) && throw(ArgumentError("Number of age groups and fractions must be the same (got $(length(grps)) and $(length(frcs)))."))
        end
        isnothing(ags) || AGS(Int64(ags)) # throws if the community identification number is invalid
        isa(ticks_ago, Real) && !(1 <= ticks_ago <= MAX_PRIOR_TICKS_AGO) && throw(ArgumentError("ticks_ago must be between 1 and $MAX_PRIOR_TICKS_AGO (got $ticks_ago)."))

        return new(pathogen, frcs, grps, isnothing(ags) ? nothing : Int64(ags), isa(ticks_ago, Real) ? Float64(ticks_ago) : ticks_ago)
    end
end

Base.show(io::IO, p::PriorImmunity) = write(io,
    "PriorImmunity($(isempty(p.pathogen) ? "" : p.pathogen * ", ")$(join(round.(100 .* p.fraction, digits = 2), "/"))%, $(p.ticks_ago) ticks ago)")

###
### APPLICATION
###

"""
    _apply_prior_immunity!(simulation::Simulation)

Applies every prior immunity entry of `simulation`.
"""
function _apply_prior_immunity!(simulation::Simulation)
    for (i, c) in enumerate(prior_immunity(simulation))
        # own stream per entry, so start-condition and run draws don't depend on prior immunity
        _apply_prior_immunity!(simulation, c, Xoshiro(_mix(UInt64(2), seed(simulation), i)))
    end
end

"""
    _apply_prior_immunity!(simulation::Simulation, c::PriorImmunity, rng::Xoshiro)

Samples the `fraction` of each age group (within `ags`) per target pathogen and records natural immunity acquired `ticks_ago`.
"""
function _apply_prior_immunity!(simulation::Simulation, c::PriorImmunity, rng::Xoshiro)
    pool = isnothing(c.ags) ? individuals(simulation) : individuals_in_ags(simulation, AGS(c.ags))
    groups = isempty(c.age_groups) ? [pool] : [filter(i -> in_group(age(i), g), pool) for g in c.age_groups]
    for p in _target_pathogens(simulation, c), (members, f) in zip(groups, c.fraction)
        for ind in gems_sample(rng, members, round(Int, f * length(members)), replace = false)
            push_immunity!(immunity_registry(simulation, ind), ind, id(p), IMMUNITY_SOURCE_NATURAL,
                _prior_tick(c.ticks_ago, rng), DEFAULT_VACCINE_ID)
        end
    end
end

# every pathogen for ALL_PATHOGENS, otherwise the named (or only) one
_target_pathogens(simulation::Simulation, c::PriorImmunity) =
    c.pathogen == ALL_PATHOGENS ? pathogens(simulation) : (get_pathogen(simulation, c.pathogen),)

# clamped before rounding so huge or infinite draws can't overflow Int
_prior_tick(ticks_ago, rng::Xoshiro) = Int16(-ceil(Int, clamp(_rand_val(ticks_ago, rng), 1.0, Float64(MAX_PRIOR_TICKS_AGO))))
