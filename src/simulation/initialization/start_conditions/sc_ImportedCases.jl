export ImportedCases
export initialize!

###
### TYPES
###

# User-supplied callbacks, one per dimension of an import schedule. The aliases keep the
# ImportedCases fields concrete.
const ImportSchedule = FunctionWrapper{Vector{Int16}, Tuple{Simulation}}
const ImportCount = FunctionWrapper{Int, Tuple{Simulation, Int16}}
const ImportRegion = FunctionWrapper{Int64, Tuple{Simulation, Int16}}

"""
    _ImportWindow

Normalized window form of the `ImportedCases` `ticks` argument: the first import happens
`offset` ticks after `start_tick`, each following import `interval` ticks after the previous
one, up to and including `stop_tick`. Both gaps are resolved per import through `_rand_val`,
so a `Real` gives fixed spacing and a `Distribution` gives stochastic spacing.
"""
struct _ImportWindow
    start_tick::Int16
    stop_tick::Int16
    interval::Union{Float64, Distribution}
    offset::Union{Float64, Distribution}
end

"""
    ImportedCases <: StartCondition

A `StartCondition` that seeds infections at scheduled ticks during the run, modelling
importation of cases. `initialize!` only stages the schedule; `seed_scheduled!` executes
each import at its tick.

The three dimensions of an import schedule are independent, and each accepts several forms:

# Fields
- `pathogen::String`: Pathogen to seed with; empty string = the only pathogen, `ALL_PATHOGENS` = every pathogen
- `ticks`: *when* imports happen
    - `Integer`: a single import at that tick
    - `AbstractVector{<:Integer}`: exactly these ticks (ranges included); a repeated tick
      schedules several imports on it
    - `Function`: `f(sim)` returning the ticks, resolved during `initialize!`
    - `NamedTuple`: window form `(start_tick =, stop_tick =, interval =, offset =)`, where
      `interval` (gap between imports) and `offset` (gap from `start_tick` to the first
      import, default `0`) are each a number or a `Distribution`
- `count`: *how many* individuals each import infects. An import sized below 1 is skipped,
  so a `0` entry keeps a per-import vector aligned with its ticks without seeding anything.
    - `Integer`: the same number every time
    - `AbstractVector{<:Integer}`: one entry per import
    - `Distribution`: drawn per import
    - `Function`: `f(sim, tick)` returning an integer
- `ags`: *where* the imports land; `nothing` seeds from the whole population
    - `Integer`: the same region every time
    - `AbstractVector{<:Integer}`: one region per import
    - `Function`: `f(sim, tick)` returning a community identification number

A vector `ags` has no way of saying "whole population" for individual entries. Combine
several `ImportedCases` in a `MultiStartCondition` for mixed regional/nationwide schedules.

Each form is normalized by `_ticks_spec`/`_count_spec`/`_region_spec` at construction and
evaluated by `_resolve_ticks`/`_resolve_count`/`_resolve_region` during `initialize!`. Both
halves of a dimension live in the same section below, so a new form is added in one place.

# Example
```julia
# 3 individuals every 7 ticks, from tick 30 to 200
condition = ImportedCases(count = 3, ticks = 30:7:200)

# the same, written as a window (the form config files use)
condition = ImportedCases(count = 3, ticks = (start_tick = 30, stop_tick = 200, interval = 7))

# a Poisson import process: on average one import every 10 ticks, 2 individuals each
condition = ImportedCases(count = 2,
    ticks = (start_tick = 30, stop_tick = 200, interval = Exponential(10), offset = Exponential(10)))

# two regions on the same tick, with per-import counts
condition = ImportedCases(ticks = [10, 10, 20], count = [5, 3, 1],
    ags = [13003000, 13076033, 13003000])

sim = Simulation(start_condition = condition)
```
"""
struct ImportedCases <: StartCondition
    pathogen::String
    ticks::Union{Vector{Int16}, ImportSchedule, _ImportWindow}
    count::Union{Int, Vector{Int}, Distribution, ImportCount}
    ags::Union{Int64, Vector{Int64}, ImportRegion, Nothing}

    function ImportedCases(; pathogen::String = "", ticks, count, ags = nothing)
        tcks = _ticks_spec(ticks)
        cnt = _count_spec(count)
        rgn = _region_spec(ags)

        # vector lengths can only be cross-checked when the schedule is known upfront;
        # the other tick forms are checked in initialize!
        if isa(tcks, Vector{Int16})
            _check_length(cnt, length(tcks), "count")
            _check_length(rgn, length(tcks), "ags")
        end

        return new(pathogen, tcks, cnt, rgn)
    end
end

###
### DISPLAY
###

Base.show(io::IO, c::ImportedCases) = write(io,
    "ImportedCases($(_label(c.count)) per import, $(_label(c.ticks)))")

# compact display for whichever form a field holds; the fallback keeps a form that predates
# its own label printable instead of throwing
_label(x) = string(x)
_label(t::Vector{Int16}) = "$(length(t)) tick$(length(t) == 1 ? "" : "s")"
_label(c::Vector{Int}) = "$(sum(c)) in total"
_label(w::_ImportWindow) = "ticks $(w.start_tick)-$(w.stop_tick)"
_label(::FunctionWrapper) = "custom"

"""
    pathogen(importedCases::ImportedCases)

Returns the pathogen used to seed the imported cases.
"""
function pathogen(importedCases::ImportedCases)
    return importedCases.pathogen
end

###
### INITIALIZATION
###

"""
    initialize!(simulation::Simulation, condition::ImportedCases)

Resolves the import schedule and stages one `InfectionSeed` per import in
`simulation.seeding_schedule`; seeds nothing here (see `seed_scheduled!`).
"""
function initialize!(simulation::Simulation, condition::ImportedCases; kwargs...)
    r = rng(simulation)
    ticks = _resolve_ticks(simulation, condition.ticks, r)

    if isempty(ticks)
        @warn "ImportedCases: the resolved schedule is empty, so no cases will be imported."
        return nothing
    end

    _check_length(condition.count, length(ticks), "count")
    _check_length(condition.ags, length(ticks), "ags")

    for (i, t) in enumerate(ticks)
        c = _resolve_count(simulation, condition.count, i, t, r)
        c < 1 && continue
        a = _resolve_region(simulation, condition.ags, i, t)
        bucket = get!(() -> InfectionSeed[], simulation.seeding_schedule, t)
        push!(bucket, InfectionSeed(condition.pathogen, c, a))
    end

    return nothing
end

###
### WHEN: TICKS
###

const _WINDOW_KEYS = (:start_tick, :stop_tick, :interval, :offset)

# fixed gaps are stored as Float64, distributions as-is (both go through _rand_val later)
_gap(g::Real) = Float64(g)
_gap(g::Distribution) = g

"""
    _import_window(spec)

Builds an `_ImportWindow` from a `NamedTuple` (Julia API) or a `Dict` (config file). Both
`Symbol` and `String` keys are accepted.
"""
function _import_window(spec)
    params = Dict{Symbol, Any}(Symbol(k) => v for (k, v) in pairs(spec))

    unknown = setdiff(keys(params), _WINDOW_KEYS)
    !isempty(unknown) && throw(ArgumentError("Unknown key(s) in the 'ticks' window: $(join(unknown, ", ")). Valid keys are $(join(_WINDOW_KEYS, ", "))."))
    for k in (:start_tick, :stop_tick, :interval)
        !haskey(params, k) && throw(ArgumentError("The 'ticks' window is missing the '$k' key."))
    end

    start_tick = params[:start_tick]
    stop_tick = params[:stop_tick]
    interval = params[:interval]
    offset = get(params, :offset, 0)

    (!isa(start_tick, Integer) || !isa(stop_tick, Integer)) &&
        throw(ArgumentError("start_tick and stop_tick must be integers."))
    !isa(interval, Union{Real, Distribution}) &&
        throw(ArgumentError("interval must be a number or a Distribution."))
    !isa(offset, Union{Real, Distribution}) &&
        throw(ArgumentError("offset must be a number or a Distribution."))

    start_tick < 0 && throw(ArgumentError("start_tick must be >= 0."))
    stop_tick < start_tick && throw(ArgumentError("stop_tick must be >= start_tick."))
    stop_tick > typemax(Int16) && throw(ArgumentError("stop_tick must not exceed $(typemax(Int16))."))
    mean(interval) <= 0 && throw(ArgumentError("interval must be positive."))
    mean(offset) < 0 && throw(ArgumentError("offset must be >= 0."))

    # a fixed interval wider than the window only ever fires once (usually a typo)
    isa(interval, Real) && stop_tick > start_tick && interval > stop_tick - start_tick &&
        @warn "ImportedCases: interval ($interval) exceeds the window ($start_tick-$stop_tick), so only a single import will occur."

    return _ImportWindow(Int16(start_tick), Int16(stop_tick), _gap(interval), _gap(offset))
end

"""
    _ticks_spec(ticks)

Normalizes the `ticks` argument into one of the three forms `ImportedCases` stores: an
explicit `Vector{Int16}`, an `ImportSchedule` callback, or an `_ImportWindow`. Anything that
is none of the documented forms throws here rather than at `initialize!`.
"""
function _ticks_spec(t::Integer)
    (t < 0 || t > typemax(Int16)) && throw(ArgumentError("ticks must be between 0 and $(typemax(Int16))."))
    return Int16[t]
end

function _ticks_spec(t::AbstractVector{<:Integer})
    isempty(t) && throw(ArgumentError("At least one tick must be provided."))
    any(x -> x < 0 || x > typemax(Int16), t) &&
        throw(ArgumentError("ticks must be between 0 and $(typemax(Int16))."))
    return Vector{Int16}(t)
end

_ticks_spec(t::Function) = ImportSchedule(t)
_ticks_spec(t::Union{NamedTuple, AbstractDict}) = _import_window(t)
_ticks_spec(t::Union{ImportSchedule, _ImportWindow}) = t # already normalized
_ticks_spec(t) = throw(ArgumentError("ticks must be an integer, a vector of integers, a function of the simulation, or a window NamedTuple; got $(typeof(t))."))

"""
    _resolve_ticks(simulation, ticks, rng)

Returns the tick of every import in the schedule. Explicit ticks are handed back unchanged,
a callback is invoked with the simulation, and a window accumulates its gaps from `rng`.
Runs once per `initialize!`, so a stochastic schedule is redrawn by `reinitialize!`.
"""
_resolve_ticks(::Simulation, t::Vector{Int16}, ::Xoshiro) = t

function _resolve_ticks(simulation::Simulation, f::ImportSchedule, ::Xoshiro)
    ticks = f(simulation)
    any(<(0), ticks) && throw(ArgumentError("The ticks function returned negative ticks."))
    return ticks
end

function _resolve_ticks(::Simulation, w::_ImportWindow, r::Xoshiro)
    ticks = Int16[]
    t = Int(w.start_tick) + ceil(Int, _rand_val(w.offset, r))
    while t <= Int(w.stop_tick)
        push!(ticks, Int16(t))
        # max(1, ...) keeps ticks strictly increasing and terminates the loop
        t += max(1, ceil(Int, _rand_val(w.interval, r)))
    end
    return ticks
end

###
### HOW MANY: COUNT
###

"""
    _count_spec(count)

Normalizes the `count` argument into an `Int` used for every import, a per-import
`Vector{Int}`, a `Distribution` to draw each import's size from, or an `ImportCount`
callback. A scalar `0` is rejected because it would make the whole condition a no-op, while
a `0` inside a vector is allowed and skips just that import.
"""
function _count_spec(c::Integer)
    c < 1 && throw(ArgumentError("count must be a positive integer."))
    return Int(c)
end

function _count_spec(c::AbstractVector{<:Integer})
    isempty(c) && throw(ArgumentError("At least one count must be provided."))
    # 0 skips its import, matching how distributions and functions are handled
    any(<(0), c) && throw(ArgumentError("count must not be negative."))
    return Vector{Int}(c)
end

function _count_spec(c::Distribution)
    mean(c) <= 0 && throw(ArgumentError("The count distribution must have a positive mean."))
    return c
end

_count_spec(c::Function) = ImportCount(c)
_count_spec(c::ImportCount) = c # already normalized
_count_spec(c) = throw(ArgumentError("count must be an integer, a vector of integers, a Distribution, or a function of the simulation and tick; got $(typeof(c))."))

"""
    _resolve_count(simulation, count, i, tick, rng)

Returns how many individuals the `i`-th import, scheduled for `tick`, infects. `i` indexes
the per-import vector form; `tick` is what a callback sizes against (seasonality, say).
A result below 1 is skipped by `initialize!` and stages no `InfectionSeed`.
"""
_resolve_count(::Simulation, c::Int, ::Int, ::Int16, ::Xoshiro) = c
_resolve_count(::Simulation, c::Vector{Int}, i::Int, ::Int16, ::Xoshiro) = c[i]
_resolve_count(::Simulation, c::Distribution, ::Int, ::Int16, r::Xoshiro) = round(Int, _rand_val(c, r))
_resolve_count(simulation::Simulation, f::ImportCount, ::Int, t::Int16, ::Xoshiro) = f(simulation, t)

###
### WHERE: REGION
###

"""
    _region_spec(ags)

Normalizes the `ags` argument into `nothing` (seed from the whole population), an `Int64`
region used for every import, a per-import `Vector{Int64}`, or an `ImportRegion` callback.
Every community identification number given upfront is validated through `AGS` here; one
produced by a callback can only be checked when it is resolved.
"""
_region_spec(::Nothing) = nothing

function _region_spec(a::Integer)
    AGS(Int64(a)) # throws if the community identification number is invalid
    return Int64(a)
end

function _region_spec(a::AbstractVector{<:Integer})
    isempty(a) && throw(ArgumentError("At least one ags must be provided."))
    AGS.(Int64.(a))
    return Vector{Int64}(a)
end

_region_spec(a::Function) = ImportRegion(a)
_region_spec(a::ImportRegion) = a # already normalized
_region_spec(a) = throw(ArgumentError("ags must be an integer, a vector of integers, a function of the simulation and tick, or nothing; got $(typeof(a))."))

"""
    _resolve_region(simulation, ags, i, tick)

Returns the community identification number the `i`-th import, scheduled for `tick`, seeds
into, or `nothing` to draw from the whole population. Takes no `rng`: unlike ticks and
counts, a region is never drawn, only looked up or computed.
"""
_resolve_region(::Simulation, ::Nothing, ::Int, ::Int16) = nothing
_resolve_region(::Simulation, a::Int64, ::Int, ::Int16) = a
_resolve_region(::Simulation, a::Vector{Int64}, i::Int, ::Int16) = a[i]

function _resolve_region(simulation::Simulation, f::ImportRegion, ::Int, t::Int16)
    a = f(simulation, t)
    AGS(a) # throws if the community identification number is invalid
    return a
end

###
### SHARED
###

# only vector specs are length-bound to the schedule
_check_length(::Any, ::Int, ::String) = nothing
function _check_length(spec::Vector, imports::Int, name::String)
    length(spec) != imports &&
        throw(ArgumentError("$name has $(length(spec)) entries but the schedule has $imports imports. Provide one entry per import or a single value for all of them."))
    return nothing
end
