export evaluate, EvaluationResult

"""
    EvaluationResult

Result of an `evaluate` call over a set of scenarios and criteria.

# Fields
- `summary`: one row per scenario. Each criterion contributes columns based on its type:
    - numeric: aggregated, one column per aggregator (`<criterion>_<aggregator>`)
    - listed in `constants`: kept verbatim under its own name (`<criterion>`)
    - non-numeric and constant within a scenario (label, ...): kept as-is (`<criterion>`)
    - non-numeric and varying: omitted with a warning; read it from `runs`
- `runs`: one row per simulation run (columns `scenario`, `run`, and one per criterion), or
  `nothing` if `evaluate` was called with `keep_runs = false`.
- `rundata`: the retained `ResultData` objects, or `nothing` unless `evaluate` was called with
  `keep_rundata = true`.
- `criteria`: the criterion names in evaluation order.
"""
struct EvaluationResult
    summary::DataFrame
    runs::Union{DataFrame, Nothing}
    rundata::Union{Vector{ResultData}, Nothing}
    criteria::Vector{Symbol}
end

function Base.show(io::IO, r::EvaluationResult)
    write(io, "EvaluationResult ($(nrow(r.summary)) scenarios, $(length(r.criteria)) criteria)")
end

# normalizes criteria/aggregators (NamedTuple or Dict) into ordered (name => function) pairs
_named_pairs(nt::NamedTuple) = [k => nt[k] for k in keys(nt)]
_named_pairs(d::AbstractDict) = [Symbol(k) => v for (k, v) in d]

"""
    evaluate(scenarios, criteria; aggregators=(mean=mean, std=std), constants=(), keep_runs=true, keep_rundata=false, rd_style="LightRD", seed=nothing)

Run a set of `scenarios` and evaluate a set of pluggable `criteria` against each run,
returning an [`EvaluationResult`](@ref).

# Arguments
- `scenarios`: a [`Batch`](@ref) or a `Vector{Batch}` (merged automatically). Each scenario is
  identified by the `label` simarg (`Batch(...; label = "masks")`); runs with the same label
  form one scenario.
- `criteria`: a `NamedTuple` (or `Dict`) of `rd::ResultData -> value` functions. Each becomes
  a column in the output.

# Keyword Arguments
- `aggregators`: a `NamedTuple` (or `Dict`) of `values -> scalar` reducers applied to numeric
  criteria. Default `(mean = mean, std = std)`.
- `constants`: criterion names (a collection of `Symbol`s) to keep verbatim in the summary
  instead of aggregating — for per-scenario attributes like a population size. Default `()`.
- `keep_runs`: keep the per-run table in `runs`. Default `true`. It is always computed
  internally to build the summary; set `false` only to drop it from the result.
- `keep_rundata`: retain the batch's `ResultData` objects in `rundata`. Default `false` —
  criteria are evaluated as each run lands, so only one `ResultData` is held at a time.
- `rd_style`: `ResultData` style used per run. Default `"LightRD"`.
- `seed`: seed for reproducibility. Passing the same value produces the same results.

# Example
```julia
scenarios = [
    Batch(n_runs = 10, pop_size = 100_000, label = "baseline"),
    Batch(n_runs = 10, pop_size = 100_000, label = "isolation",
          setup = sim -> begin
              strat = IStrategy("iso", sim)
              add_measure!(strat, SelfIsolation(14))
              add_symptom_trigger!(sim, SymptomTrigger(strat))
          end)
]

criteria = (
    infections = rd -> sum(total_infections(rd).total_infections),
    scenario = rd -> label(rd)
)

result = evaluate(scenarios, criteria)
result.summary   # one row per scenario
result.runs      # one row per run
```
"""
function evaluate(scenarios, criteria;
    aggregators = (mean = mean, std = std),
    constants = (),
    keep_runs::Bool = true,
    keep_rundata::Bool = false,
    rd_style::String = "LightRD",
    seed::Union{Nothing, Integer} = nothing,
    customlogger::Union{Nothing, CustomLogger} = nothing
)
    batch = scenarios isa Batch ? scenarios : Batch(scenarios)

    crit_pairs = _named_pairs(criteria)
    crit_names = Symbol[name for (name, _) in crit_pairs]

    scenario_col = String[]
    run_col = Int[]
    value_cols = [Vector{Any}() for _ in crit_pairs]
    run_counter = Dict{String, Int}()
    retained = keep_rundata ? ResultData[] : nothing

    # evaluate criteria as each run lands, so only one ResultData is held at a time
    on_run = (rd, _) -> begin
        scen = string(label(rd))
        run_idx = get(run_counter, scen, 0) + 1
        run_counter[scen] = run_idx
        push!(scenario_col, scen)
        push!(run_col, run_idx)

        for (j, (name, f)) in enumerate(crit_pairs)
            val = try
                f(rd)
            catch err
                error("Criterion :$name failed on scenario \"$scen\" (run $run_idx): $err")
            end
            push!(value_cols[j], val)
        end

        keep_rundata && push!(retained, rd)
    end

    # process! runs the batch; keep_rundata=false so it doesn't also hold every ResultData
    process!(batch; keep_rundata = false, rd_style = rd_style, seed = seed,
        customlogger = customlogger, on_run = on_run)

    # per-run table; identity.() narrows each Any-typed column to a concrete eltype where uniform
    runs_df = DataFrame(scenario = scenario_col, run = run_col)
    for (j, name) in enumerate(crit_names)
        runs_df[!, name] = identity.(value_cols[j])
    end

    summary_df = _summarize(runs_df, crit_names, _named_pairs(aggregators), constants)

    return EvaluationResult(summary_df,
        keep_runs ? runs_df : nothing,
        retained,
        crit_names)
end

# aggregates the per-run table into one row per scenario, preserving scenario order
function _summarize(runs_df::DataFrame, crit_names::Vector{Symbol}, agg_pairs::Vector, constants)
    gdf = groupby(runs_df, :scenario)
    transforms = Any[]
    unsummarizable = Symbol[]
    for name in crit_names
        col = runs_df[!, name]
        if name in constants
            # explicitly declared per-scenario attribute: keep verbatim
            push!(transforms, name => first => name)
        elseif eltype(col) <: Number
            # a number is a metric: always aggregate, even if it happens to be constant
            for (aggname, aggf) in agg_pairs
                push!(transforms, name => aggf => Symbol(name, "_", aggname))
            end
        elseif all(sub -> allequal(sub[!, name]), gdf)
            # constant non-numeric attribute (label, region, ...): keep as-is
            push!(transforms, name => first => name)
        else
            # non-numeric and varying: can't reduce, omit rather than report a wrong value
            push!(unsummarizable, name)
        end
    end
    isempty(unsummarizable) ||
        @warn "Criteria vary within scenarios but are not numeric; omitted from summary (see `result.runs`): $(join(unsummarizable, ", "))"
    return isempty(transforms) ? combine(gdf, nrow => :n) : combine(gdf, transforms...)
end
