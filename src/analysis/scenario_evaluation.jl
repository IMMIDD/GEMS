export evaluate, EvaluationResult

"""
    EvaluationResult

Result of an `evaluate` call over a set of scenarios and criteria.

# Fields
- `summary`: one row per scenario. Numeric criteria are aggregated (`<criterion>_<aggregator>`);
  non-numeric criteria are kept verbatim when constant (or named in `constants`), otherwise
  dropped with a warning (read them from `runs`).
- `runs`: one row per simulation run (columns `scenario`, `run`, and one per criterion), or
  `nothing` if `evaluate` was called with `keep_runs = false`.
- `stratified`: the `stratified` summary aggregated per `(scenario, stratified_by...)`, sorted
  by those keys, or `nothing` unless `stratified`/`stratified_by` were given.
- `strata_runs`: the stacked per-(run×stratum) table (`scenario`, `run`, `stratified_by...`,
  metrics), or `nothing`.
- `rundata`: the retained `ResultData` objects, or `nothing` unless `evaluate` was called with
  `keep_rundata = true`.
- `criteria`: the criterion names in evaluation order.
"""
struct EvaluationResult
    summary::DataFrame
    runs::Union{DataFrame, Nothing}
    stratified::Union{DataFrame, Nothing}
    strata_runs::Union{DataFrame, Nothing}
    rundata::Union{Vector{ResultData}, Nothing}
    criteria::Vector{Symbol}
end

function Base.show(io::IO, r::EvaluationResult)
    s = "EvaluationResult ($(nrow(r.summary)) scenarios, $(length(r.criteria)) criteria"
    r.stratified === nothing || (s *= ", $(nrow(r.stratified)) strata rows")
    write(io, s * ")")
end

# normalizes criteria/aggregators (NamedTuple or Dict) into ordered (name => function) pairs
_named_pairs(nt::NamedTuple) = [k => nt[k] for k in keys(nt)]
_named_pairs(d::AbstractDict) = [Symbol(k) => v for (k, v) in d]

# resolve `aggregators` into a lookup `criterion name -> [(aggname => reducer)]`. A flat set
# (aggname => reducer) applies to every criterion; a per-criterion map (criterion => set)
# looks each up, falling back to its `:default` entry or to mean/std.
function _agg_lookup(aggregators, crit_names)
    pairs = _named_pairs(aggregators)
    if all(p -> last(p) isa Function, pairs)   # flat: same reducers for all criteria
        clash = intersect(first.(pairs), crit_names)
        isempty(clash) || throw(ArgumentError(
            "`aggregators` is ambiguous: $(join(clash, ", ")) names both an aggregator and a criterion; " *
            "for a per-criterion set write `$(first(clash)) = (mean = mean,)`, else rename the aggregator."))
        return _ -> pairs
    end
    for (name, set) in pairs
        set isa Union{NamedTuple, AbstractDict} || throw(ArgumentError(
            "per-criterion `aggregators` entry :$name must be a reducer-set like `(mean = mean,)`, not a bare function"))
    end
    unknown = setdiff(first.(pairs), [crit_names; :default])
    isempty(unknown) || throw(ArgumentError("`aggregators` names unknown criteria: $(join(unknown, ", "))"))
    by_name = Dict(name => _named_pairs(set) for (name, set) in pairs)
    default = get(by_name, :default, [:mean => mean, :std => std])
    return name -> get(by_name, name, default)
end

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
- `aggregators`: reducers for numeric criteria. Either a flat `NamedTuple`/`Dict` of
  `aggname => reducer` applied to all, or a per-criterion map `criterion => reducer-set` (with
  an optional `:default`). Default `(mean = mean, std = std)`.
- `constants`: criterion names (a collection of `Symbol`s) to keep verbatim in the summary
  instead of aggregating — for per-scenario attributes like a population size. Each must exist
  and be constant within every scenario, else an `ArgumentError` is thrown. Default `()`.
  `aggregators`/`constants` are shared with the stratified summary (a name can't be aggregated
  in one and kept constant in the other).
- `stratified`: `rd -> DataFrame` returning one row per stratum for that run (the `stratified_by`
  key columns plus metric columns; must not contain `scenario`/`run`). Produces
  `result.stratified` (aggregated per `(scenario, stratified_by...)`) and `result.strata_runs`
  (raw). Holds `O(runs × strata)` rows to the end. Default `nothing`.
- `stratified_by`: the stratum key columns (`Symbol`s), given together with `stratified`.
  Default `()`.
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
    stratified::Union{Nothing, Function} = nothing,
    stratified_by = (),
    keep_runs::Bool = true,
    keep_rundata::Bool = false,
    rd_style::String = "LightRD",
    seed::Union{Nothing, Integer} = nothing,
    customlogger::Union{Nothing, CustomLogger} = nothing
)
    batch = scenarios isa Batch ? scenarios : Batch(scenarios)

    crit_pairs = _named_pairs(criteria)
    crit_names = Symbol[name for (name, _) in crit_pairs]

    stratified_by = collect(Symbol, stratified_by)
    # `stratified` and `stratified_by` come as a pair (a `rd -> DataFrame` and its key columns)
    (stratified === nothing) == isempty(stratified_by) ||
        throw(ArgumentError("`stratified` and `stratified_by` must be given together."))

    # `constants` against `crit_names` upfront only for the scalar path; the stratified path
    # defers it to the first strata frame (a constant may be a strata-only column)
    if stratified === nothing
        unknown = setdiff(constants, crit_names)
        isempty(unknown) || throw(ArgumentError("`constants` names unknown criteria: $(join(unknown, ", "))"))
    end

    agg_lookup = _agg_lookup(aggregators, crit_names)   # validates the aggregators shape and names

    scenario_col = String[]
    run_col = Int[]
    value_cols = [Vector{Any}() for _ in crit_pairs]
    run_counter = Dict{String, Int}()
    retained = keep_rundata ? ResultData[] : nothing
    strata_frames = stratified === nothing ? nothing : DataFrame[]
    strata_cols = Ref{Vector{Symbol}}()   # the first frame's raw schema (before scenario/run)

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

        if stratified !== nothing
            sdf = try
                stratified(rd)
            catch err
                error("`stratified` failed on scenario \"$scen\" (run $run_idx): $err")
            end
            cols = propertynames(sdf)
            if isempty(strata_frames)   # first frame: fail fast (after one run)
                (:scenario in cols || :run in cols) && throw(ArgumentError(
                    "`stratified` frame must not contain reserved columns `scenario`/`run`."))
                miss = setdiff(stratified_by, cols)
                isempty(miss) || throw(ArgumentError("`stratified_by` columns not in `stratified` frame: $(join(miss, ", "))"))
                unk = setdiff(constants, [crit_names; cols])
                isempty(unk) || throw(ArgumentError("`constants` names unknown criteria/strata columns: $(join(unk, ", "))"))
                strata_cols[] = cols
            else
                Set(cols) == Set(strata_cols[]) || throw(ArgumentError(
                    "`stratified` frame on scenario \"$scen\" (run $run_idx) has columns $(cols), expected $(strata_cols[])."))
            end
            nrow(unique(sdf, stratified_by)) == nrow(sdf) || throw(ArgumentError(
                "`stratified` frame on scenario \"$scen\" (run $run_idx) has duplicate `stratified_by` keys."))
            insertcols!(sdf, 1, :scenario => scen, :run => run_idx)
            push!(strata_frames, sdf)
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

    summary_df = _summarize(runs_df, crit_names, agg_lookup, constants)

    stratified_df = nothing
    strata_runs = nothing
    if stratified !== nothing && !isempty(strata_frames)
        strata_runs = reduce(vcat, strata_frames)
        gcols = [:scenario; stratified_by]
        # completeness: a stratum absent from some of a scenario's runs biases its aggregate
        counts = combine(groupby(strata_runs, gcols), nrow => :n)
        ragged = filter(r -> r.n < run_counter[r.scenario], counts)
        if nrow(ragged) > 0
            keys = join((join([string(r[c]) for c in gcols], "/") for r in eachrow(ragged)), ", ")
            @warn "Strata absent from some runs, so their aggregate divides by fewer than the run count (zero-fill absent strata in your `stratified` function if absent means zero): $keys"
        end
        valuecols = setdiff(propertynames(strata_runs), [:scenario; :run; stratified_by])
        stratified_df = _summarize(strata_runs, valuecols, agg_lookup, constants;
            groupcols = gcols, raw_ref = "result.strata_runs")
        sort!(stratified_df, gcols)
    end

    return EvaluationResult(summary_df,
        keep_runs ? runs_df : nothing,
        stratified_df,
        keep_runs ? strata_runs : nothing,
        retained,
        crit_names)
end

# aggregates a per-run table into one row per group, preserving first-appearance order
function _summarize(df::DataFrame, valuecols, agg_lookup, constants; groupcols = [:scenario], raw_ref = "result.runs")
    gdf = groupby(df, groupcols)
    multi_run = any(sub -> nrow(sub) > 1, gdf)
    transforms = Any[]
    unsummarizable = Symbol[]
    for name in valuecols
        col = df[!, name]
        if name in constants
            # declared attribute: keep verbatim, but verify it's actually constant
            all(sub -> allequal(sub[!, name]), gdf) ||
                throw(ArgumentError("Criterion :$name is listed in `constants` but varies within a group."))
            push!(transforms, name => first => name)
        elseif eltype(col) <: Number
            # a number is a metric: always aggregate, even if it happens to be constant
            for (aggname, aggf) in agg_lookup(name)
                push!(transforms, name => aggf => Symbol(name, "_", aggname))
            end
        elseif multi_run && all(sub -> allequal(sub[!, name]), gdf)
            # constant non-numeric (label, ...) confirmed across runs: keep as-is
            push!(transforms, name => first => name)
        else
            # varying, or unverifiable from a single run: drop rather than keep a wrong value
            push!(unsummarizable, name)
        end
    end
    if !isempty(unsummarizable)
        cols = join(unsummarizable, ", ")
        @warn multi_run ?
            "Non-numeric criteria vary within groups; dropped from summary (read from `$raw_ref`): $cols" :
            "Non-numeric criteria unverifiable from a single run; dropped from summary (read from `$raw_ref`, or list in `constants` to keep): $cols"
    end
    return isempty(transforms) ? combine(gdf, nrow => :n) : combine(gdf, transforms...)
end
