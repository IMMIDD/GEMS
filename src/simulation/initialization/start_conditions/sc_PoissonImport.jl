export PoissonImport
export initialize!

"""
    PoissonImport <: StartCondition

A `StartCondition` that seeds new infections at stochastic ticks between `start_tick` and
`stop_tick`, with import ticks drawn as a Poisson process (mean `rate` events per tick)
using `rng(simulation)`. `initialize!` only draws and stages the schedule; `seed_scheduled!`
executes each import at its tick.

Ticks are discrete, so at most one import occurs per tick; keep `rate` `<= 1` and raise
`count` to seed more individuals per firing.

# Fields
- `pathogen::String`: Pathogen to seed with (empty string = default pathogen)
- `count::Int`: Individuals infected per firing (mean, if `stochastic_count`)
- `start_tick::Int16`: First tick from which imports may occur
- `stop_tick::Int16`: Last tick (inclusive) up to which imports may occur
- `rate::Float64`: Mean number of import events per tick
- `ags::Union{Int64, Nothing}`: Region to seed within; `nothing` = whole population
- `stochastic_count::Bool`: If `true`, draw the per-firing count from `Poisson(count)`

# Example
```julia
# on average one import (of 2 individuals) every 10 ticks, between ticks 30 and 200
condition = PoissonImport(count = 2, start_tick = 30, stop_tick = 200, rate = 0.1)
sim = Simulation(start_condition = condition)
```
"""
struct PoissonImport <: StartCondition
    pathogen::String
    count::Int
    start_tick::Int16
    stop_tick::Int16
    rate::Float64
    ags::Union{Int64, Nothing}
    stochastic_count::Bool

    function PoissonImport(; pathogen::String = "", count::Int,
            start_tick::Integer, stop_tick::Integer, rate::Real,
            ags::Union{Integer, Nothing} = nothing, stochastic_count::Bool = false)
        count < 1 && throw(ArgumentError("count must be a positive integer."))
        start_tick < 0 && throw(ArgumentError("start_tick must be >= 0."))
        stop_tick < start_tick && throw(ArgumentError("stop_tick must be >= start_tick."))
        rate <= 0 && throw(ArgumentError("rate must be a positive number."))
        return new(pathogen, count, Int16(start_tick), Int16(stop_tick), Float64(rate),
            isnothing(ags) ? nothing : Int64(ags), stochastic_count)
    end
end

Base.show(io::IO, c::PoissonImport) = write(io,
    "PoissonImport($(c.count) at rate $(c.rate)/tick, $(c.start_tick)-$(c.stop_tick))")

"""
    initialize!(simulation::Simulation, condition::PoissonImport)

Draws stochastic import ticks (Poisson process, mean `rate` events per tick) via
`rng(simulation)` and stages them; seeds nothing here (see `seed_scheduled!`).
"""
function initialize!(simulation::Simulation, condition::PoissonImport; kwargs...)
    r = rng(simulation)
    ticks = Int16[]
    # exponential inter-arrival gaps, ceil'd onto the tick grid (imports >= 1 tick apart)
    t = Int(condition.start_tick)
    while true
        t += ceil(Int, gems_rand(r, Exponential(1 / condition.rate)))
        t > Int(condition.stop_tick) && break
        push!(ticks, Int16(t))
    end
    _stage_imports!(simulation, ticks, condition.pathogen, condition.count,
        condition.ags, condition.stochastic_count)
end
