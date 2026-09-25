export effectiveR

"""
    effectiveR(postProcessor::PostProcessor)

Returns a `DataFrame` containing the effective R value for each tick, per pathogen.

For each infectee, this method looks ahead for secondary infections this individual might cause
during the total span of the simulation.
These infections are then counted towards the R-value of the initial infection.
If individual A, for example, is infected at time 42 and causes four secondary infections
during the next 14 ticks, these four infections are counted towards the R-value of time 42.

Note: This only works in scenarios without re-infection as the current implementation
just evaluates the total infections caused by each individual in general.
If an individual was infected multiple times, secondary infections will inflate the statistic.

# Returns

- `Dataframe` with the following columns:

| Name                 | Type      | Description                                                                      |
| :------------------- | :-------- | :------------------------------------------------------------------------------- |
| `tick`               | `Int16`   | Simulation tick (time)                                                           |
| `pathogen_id`        | `Int8`    | Pathogen identifier                                                              |
| `effective_R`        | `Float64` | Effective R-value                                                                |
| `in_hh_effective_R`  | `Float64` | Effective R-value for household infections                                       |
| `out_hh_effective_R` | `Float64` | Effective R-value for non-household infections                                   |
| `rolling_R`          | `Float64` | Effective R rolling average of the 7 previous ticks                              |
| `rolling_in_hh_R`    | `Float64` | Effective R rolling average for household infections of the 7 previous ticks     |
| `rolling_out_hh_R`   | `Float64` | Effective R rolling average for non-household infections of the 7 previous ticks |
"""
function effectiveR(postProcessor::PostProcessor)
    windowsize = 7 # for rolling R calculation
    sim = simulation(postProcessor)

    infs = infectionsDF(postProcessor)
    pathogen_ids = collect(map(id, pathogens(sim)))
    nticks = Int(tick(sim))

    # secondary infections per infection, summed per (pathogen, tick) of the spreader
    infections, in_hh, out_hh, spreaders = _effective_r_counts(infs.infection_id, infs.source_infection_id,
        infs.pathogen_id, infs.tick, infs.setting_type, infs.id_a, pathogen_ids, nticks)

    # one row per pathogen and tick, sorted by pathogen id, then tick; 0 where nobody spread
    porder = sortperm(pathogen_ids)
    n = length(pathogen_ids) * nticks
    tick_col = Vector{Int16}(undef, n)
    pid_col = Vector{eltype(pathogen_ids)}(undef, n)
    er_col = zeros(Float64, n)
    ih_col = zeros(Float64, n)
    oh_col = zeros(Float64, n)
    row = 0
    for p in porder, t in 1:nticks
        row += 1
        tick_col[row] = Int16(t)
        pid_col[row] = pathogen_ids[p]
        s = spreaders[p, t]
        if s > 0
            er_col[row] = infections[p, t] / s
            ih_col[row] = in_hh[p, t] / s
            oh_col[row] = out_hh[p, t] / s
        end
    end

    eff_r = DataFrame(tick = tick_col, pathogen_id = pid_col,
        effective_R = er_col, in_hh_effective_R = ih_col, out_hh_effective_R = oh_col)

    # calculating rolling R per pathogen with windowsize
    eff_r.rolling_R = _rolling_mean(er_col, pid_col, windowsize)
    eff_r.rolling_in_hh_R = _rolling_mean(ih_col, pid_col, windowsize)
    eff_r.rolling_out_hh_R = _rolling_mean(oh_col, pid_col, windowsize)

    return eff_r
end

# Per (pathogen index, tick): secondary infections (all, household, non-household) caused by the infections
# of that tick, and how many infections that tick had. Infection ids are dense, so sources are found by index.
# Seeds (`id_a <= 0`) count neither as infections nor as sources.
function _effective_r_counts(inf_ids::AbstractVector, source_ids::AbstractVector, pids::AbstractVector,
        ticks::AbstractVector, setting_types::AbstractVector, id_a::AbstractVector, pathogen_ids::Vector, nticks::Int)
    nrows = length(inf_ids)
    max_id = nrows == 0 ? 0 : Int(maximum(inf_ids))
    # Int32 rather than Int: three arrays the length of all infections
    row_of = zeros(Int32, max_id)
    for r in 1:nrows
        id_a[r] > 0 && (row_of[inf_ids[r]] = Int32(r))
    end

    # secondaries per source row, only counting sources of the same pathogen
    total = zeros(Int32, nrows)
    hh = zeros(Int32, nrows)
    for r in 1:nrows
        id_a[r] > 0 || continue
        sid = source_ids[r]
        (ismissing(sid) || sid < 1 || sid > max_id) && continue
        src = row_of[sid]
        (src == 0 || pids[src] != pids[r]) && continue
        total[src] += 1
        setting_types[r] == 'h' && (hh[src] += 1)
    end

    npathogens = length(pathogen_ids)
    infections = zeros(Int, npathogens, nticks)
    in_hh = zeros(Int, npathogens, nticks)
    out_hh = zeros(Int, npathogens, nticks)
    spreaders = zeros(Int, npathogens, nticks)
    for r in 1:nrows
        id_a[r] > 0 || continue
        t = Int(ticks[r])
        1 <= t <= nticks || continue
        p = findfirst(==(pids[r]), pathogen_ids)
        p === nothing && continue
        infections[p, t] += total[r]
        in_hh[p, t] += hh[r]
        out_hh[p, t] += total[r] - hh[r]
        spreaders[p, t] += 1
    end
    return infections, in_hh, out_hh, spreaders
end

# mean over the current and `windowsize` previous values, restarting where the pathogen changes
function _rolling_mean(values::Vector{Float64}, pid_col::AbstractVector, windowsize::Int)
    rolling = Vector{Float64}(undef, length(values))
    pid_start = 1
    for i in eachindex(values)
        if i > 1 && pid_col[i] != pid_col[i-1]
            pid_start = i
        end
        start_idx = max(pid_start, i - windowsize)
        rolling[i] = mean(view(values, start_idx:i))
    end
    return rolling
end
