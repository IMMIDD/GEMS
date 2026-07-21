export PeriodicImport
export initialize!

"""
    PeriodicImport <: StartCondition

A `StartCondition` that seeds new infections at a fixed `interval` between `start_tick`
and `stop_tick`, modelling steady reimportation. `initialize!` only stages the schedule;
`seed_scheduled!` executes each import at its tick.

# Fields
- `pathogen::String`: Pathogen to seed with (empty string = default pathogen)
- `count::Int`: Individuals infected per firing (mean, if `stochastic_count`)
- `start_tick::Int16`: First tick at which imports occur
- `stop_tick::Int16`: Last tick (inclusive) at which imports may occur
- `interval::Int16`: Tick spacing between successive imports
- `ags::Union{Int64, Nothing}`: Region to seed within; `nothing` = whole population
- `stochastic_count::Bool`: If `true`, draw the per-firing count from `Poisson(count)`

# Example
```julia
# seed 3 individuals every 7 ticks, from tick 30 to 200
condition = PeriodicImport(count = 3, start_tick = 30, stop_tick = 200, interval = 7)
sim = Simulation(start_condition = condition)
```
"""
struct PeriodicImport <: StartCondition
    pathogen::String
    count::Int
    start_tick::Int16
    stop_tick::Int16
    interval::Int16
    ags::Union{Int64, Nothing}
    stochastic_count::Bool

    function PeriodicImport(; pathogen::String = "", count::Int,
            start_tick::Integer, stop_tick::Integer, interval::Integer,
            ags::Union{Integer, Nothing} = nothing, stochastic_count::Bool = false)
        count < 1 && throw(ArgumentError("count must be a positive integer."))
        start_tick < 0 && throw(ArgumentError("start_tick must be >= 0."))
        stop_tick < start_tick && throw(ArgumentError("stop_tick must be >= start_tick."))
        interval < 1 && throw(ArgumentError("interval must be a positive integer."))
        stop_tick > start_tick && interval > stop_tick - start_tick &&
            @warn "PeriodicImport: interval ($interval) exceeds the window ($start_tick-$stop_tick), so only a single import at tick $start_tick will occur."
        return new(pathogen, count, Int16(start_tick), Int16(stop_tick), Int16(interval),
            isnothing(ags) ? nothing : Int64(ags), stochastic_count)
    end
end

Base.show(io::IO, c::PeriodicImport) = write(io,
    "PeriodicImport($(c.count) every $(c.interval) ticks, $(c.start_tick)-$(c.stop_tick))")

"""
    initialize!(simulation::Simulation, condition::PeriodicImport)

Stages the fixed-interval import schedule; seeds nothing here (see `seed_scheduled!`).
"""
function initialize!(simulation::Simulation, condition::PeriodicImport; kwargs...)
    ticks = collect(Int16, condition.start_tick:condition.interval:condition.stop_tick)
    _stage_imports!(simulation, ticks, condition.pathogen, condition.count,
        condition.ags, condition.stochastic_count)
end
