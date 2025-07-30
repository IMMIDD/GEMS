export l1_norm, l2_norm, calibrate!

function l1_norm(x::Vector, y::Vector)
    return sum(abs.(x - y)) / length(x)
end

function l2_norm(x::Vector, y::Vector)
    return sqrt(sum((x - y) .^ 2) / length(x))
end

function assign_values_to_parameters!(sim; x, arg)
    # iterate over parameters (k) and values (v)
    for (k, v) in zip(arg, x)
        parts = split(k, '.')
        @eval $(Symbol(parts[end] * "_val")) = $v
        # if parameter involves settings names
        settings_list = [:households :municipalities :households :schoolclasses :schoolyears :schools :schoolcomplexes :offices :departments :workplaces :workplacesites :individuals]
        if Symbol(parts[end]) in settings_list
            t = typeof(getfield(Main, Symbol(parts[end]))(sim)[1].contact_sampling_method)
            new_rate = t(eval(Symbol(parts[end] * "_val")))
            # assing rate to all settings of specified type
            (s -> s.contact_sampling_method = new_rate).(getfield(Main, Symbol(parts[end]))(sim))
        else # when it is only ordinary parameter
            # unpack parameter from its full path
            obj = getfield(Main, Symbol(parts[begin]))
            for f in parts[2:end-1]
                obj = getfield(obj, Symbol(f))
            end
            # assign value to parameter with casting to proper type
            setfield!(obj, Symbol(parts[end]), typeof(getfield(obj, Symbol(parts[end])))(v))
        end
    end
end

function compute_loss(x::AbstractArray, p::Vector)
    sim = p[1]
    ts = p[2]
    loss = p[3]
    target = p[4]
    n = p[5]
    arg = p[6]
    lower_limit = p[7]
    upper_limit = p[8]
    # check constraints
    for (v, ll, ul) in zip(x, lower_limit, upper_limit)
        if !isnothing(ll) && v < ll
            return Inf
        end
        if !isnothing(ul) && v > ul
            return Inf
        end
    end
    assign_values_to_parameters!(sim, x=x, arg=arg)
    # run simulations and compute loss
    score = 0.0
    for _ in 1:n
        sim.seed += 1
        reinitialize!(sim)
        run!(sim)
        res = target(sim)
        score += loss(res, ts)
    end
    score /= n
    # rewind seed
    sim.seed -= n
    reinitialize!(sim)
    return score
end

#callback function to observe training
function plot_loss_callback(state::Optimization.OptimizationState, l::Float64; doplot=false::Bool, loss_history::Vector, pl::Plots.Plot)
    println("Loss:\t", l)
    push!(loss_history, l)
    # plot current learning curve
    if doplot
        plot!(loss_history, label="loss", color=:blue, linestyle=:solid, markershape=:circle, show=true, reuse=true)
        display(pl)
    end
    # should stop when return true
    return false
end

"""
    calibrate!(sim::Simulation; ref_ts::Vector, target::Function, x0::Vector, arg_x0::Vector, lower_limit=nothing::Union{Vector, Nothing}, upper_limit=nothing::Union{Vector, Nothing}, loss=l2_norm::Function, n=1::Int64, alg=CMAEvolutionStrategyOpt(), maxiters=100::Int64, compute_loss=compute_loss::Function, callback=nothing::Union{Function, Nothing}, plot_training=false::Bool, OptimizationFunction_kwargs=Dict()::Dict, OptimizationProblem_kwargs=Dict()::Dict, solve_kwargs=Dict()::Dict)

Runs calibration using Optimization.jl library as backend. Allows customization of the optimization. Sim object is modifed and has optimal parameters after excecution.

# Parameters

- `simulation::Simulation`: Simulation object
- `ref_ts::Vector`: reference time series data (i.e. real data). Should size >= sim.stop_criterion.limit.
- `target::Function`: function that returns target quantity by processing sim object (e.g. `r -> dataframes(ResultData(r))["tick_cases"][!, :exposed_cnt]`)
- `x0::Vector`: initial parameter values
- `arg_x0::Vector`: parameters name (e.g. `["households", "sim.pathogen.infection_rate"]`)
- `lower_limit=nothing::Union{Vector, Nothing}` *(optional)*: Lower strict inequality constraints of parameters
- `upper_limit=nothing::Union{Vector, Nothing}` *(optional)*: Upper strict inequality constraints of parameters
- `loss=l2_norm::Function` *(optional)*: Loss function that processes two vectors (e.g l2 norm)
- `n=1::Int64` *(optional)*: Number of simulations with changing seed per loss computation
- `alg=CMAEvolutionStrategyOpt()` *(optional)*: Optimization algorithm available for Optimization.jl
- `maxiters=100::Int64` *(optional)*: Maximum algorithm iterations
- `compute_loss=compute_loss::Function` *(optional)*: Custom function to run simulations and compute loss
- `callback=nothing::Union{Function, Nothing}` *(optional)*: Callback function with `callback = (state, loss_val) -> false` footprint 
- `plot_training=false::Bool` *(optional)*: If plotting of training curve is expected
- `OptimizationFunction_kwargs=Dict()::Dict` *(optional)*: custom OptimizationFunction kwargs (check Optimization.jl documentation)
- `OptimizationProblem_kwargs=Dict()::Dict` *(optional)*: custom OptimizationProblem kwargs (check Optimization.jl documentation)
- `solve_kwargs=Dict()::Dict` *(optional)*: custom solve kwargs (check Optimization.jl documentation)

# Returns

- `sol::OptimizationSolution`: Optimization.jl object

# Example

score = calibrate!(sim;
                    ref_ts=ts,
                    target=r -> dataframes(ResultData(r))["tick_cases"][!, :exposed_cnt],
                    n=1,
                    x0=[wp_rate, sch_rate],
                    arg_x0=["offices", "schoolclasses"],
                    solve_kwargs = Dict([(:abstol, 1.0)]),
                    maxiters=3,
                    plot_training=true,
                    lower_limit=[0.0, 0.0]
                    )

"""
function calibrate!(sim::Simulation; ref_ts::Vector, target::Function, x0::Vector, arg_x0::Vector, lower_limit::Union{Vector, Nothing}=nothing, upper_limit::Union{Vector, Nothing}=nothing, loss::Function=l2_norm, n::Int64=1, alg=CMAEvolutionStrategyOpt(), maxiters::Int64=100, compute_loss::Function=compute_loss, callback::Union{Function, Nothing}=nothing, plot_training::Bool=false, OptimizationFunction_kwargs=Dict()::Dict, OptimizationProblem_kwargs::Dict=Dict(), solve_kwargs::Dict=Dict())
    limit = sim.stop_criterion.limit + 1
    local_ts = ref_ts[1:limit]
    lower_limit = isnothing(lower_limit) ? [nothing for i = 1:length(x0)] : lower_limit
    upper_limit = isnothing(upper_limit) ? [nothing for i = 1:length(x0)] : upper_limit
    p = [sim, local_ts, loss, target, n, arg_x0, lower_limit, upper_limit]
    f = Optimization.OptimizationFunction(compute_loss, AutoFiniteDiff(); OptimizationFunction_kwargs...)
    prob = Optimization.OptimizationProblem(f, x0, p; OptimizationProblem_kwargs...)
    if isnothing(callback)
        loss_history = []
        callback = (state, l) -> plot_loss_callback(state, l; doplot=plot_training, loss_history=loss_history, pl=plot())
    end
    solve_kwargs = haskey(solve_kwargs, :callback) ? solve_kwargs : merge(solve_kwargs, Dict(:callback => callback))
    solve_kwargs = haskey(solve_kwargs, :maxiters) ? solve_kwargs : merge(solve_kwargs, Dict(:maxiters => maxiters))
    sol = Optimization.solve(prob, alg; solve_kwargs...)
    println(sol.stats)
    assign_values_to_parameters!(sim, x=sol.u, arg=arg_x0)
    reinitialize!(sim)
    return sol
end
