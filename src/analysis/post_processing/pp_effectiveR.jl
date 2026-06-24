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

    sim_infs = sim_infectionsDF(postProcessor)

    # calculate effective R over time from post processor data

    # 1. Pre-aggregate secondary infections by source and pathogen
    secondary_infs = combine(groupby(sim_infs, [:source_infection_id, :pathogen_id]),
        nrow => :infections,
        :setting_type => (st -> count(==('h'), st)) => :in_hh_infections,
        :setting_type => (st -> count(!=('h'), st)) => :out_hh_infections
    )

    # take infectees to calculate R (to also cover individuals who don't infect anybody)
    eff_r = DataFrames.select(sim_infs, :infection_id, :tick, :pathogen_id, copycols=true)

    # join to find individuals who subsequently been infected by an infectee
    leftjoin!(eff_r, secondary_infs, on = [:infection_id => :source_infection_id, :pathogen_id])
    rename!(eff_r, :infection_id => :id)

    # for individuals who didn't infect anybody, set "infections" to 0
    transform!(eff_r,
        :infections => (x -> coalesce.(x, 0)) => :infections,
        :in_hh_infections => (x -> coalesce.(x, 0)) => :in_hh_infections,
        :out_hh_infections => (x -> coalesce.(x, 0)) => :out_hh_infections
    )

    # calulate total_infections / spreaders per tick and pathogen (effective R)
    eff_r = combine(groupby(eff_r, [:tick, :pathogen_id]),
        :infections => sum => :tick_infections,
        :in_hh_infections => sum => :tick_in_hh_infections,
        :out_hh_infections => sum => :tick_out_hh_infections,
        nrow => :spreaders
    )

    transform!(eff_r,
        [:tick_infections, :spreaders] => ByRow((i, s) -> i / s) => :effective_R,
        [:tick_in_hh_infections, :spreaders] => ByRow((i, s) -> i / s) => :in_hh_effective_R,
        [:tick_out_hh_infections, :spreaders] => ByRow((i, s) -> i / s) => :out_hh_effective_R
    )
    select!(eff_r, :tick, :pathogen_id, :effective_R, :in_hh_effective_R, :out_hh_effective_R)

    # join with scaffold of all ticks × pathogens to also get ticks with 0 infections
    full_ticks = crossjoin(
        DataFrame(tick = collect(Int16, 1:tick(sim))),
        DataFrame(pathogen_id = collect(map(id, pathogens(sim)))))
    leftjoin!(full_ticks, eff_r, on = [:tick, :pathogen_id])
    eff_r = full_ticks

    # remove missing Rs for ticks
    transform!(eff_r,
        :effective_R => (x -> coalesce.(x, 0.0)) => :effective_R,
        :in_hh_effective_R => (x -> coalesce.(x, 0.0)) => :in_hh_effective_R,
        :out_hh_effective_R => (x -> coalesce.(x, 0.0)) => :out_hh_effective_R
    )

    # calculating rolling R per pathogen with windowsize
    sort!(eff_r, [:pathogen_id, :tick])

    rolling_R = Vector{Float64}(undef, nrow(eff_r))
    rolling_in_hh_R = Vector{Float64}(undef, nrow(eff_r))
    rolling_out_hh_R = Vector{Float64}(undef, nrow(eff_r))

    er_col = eff_r.effective_R
    ih_col = eff_r.in_hh_effective_R
    oh_col = eff_r.out_hh_effective_R
    pid_col = eff_r.pathogen_id

    # track the start index of the current pathogen's rows for the rolling window
    pid_start = 1
    for i in 1:nrow(eff_r)
        if i > 1 && pid_col[i] != pid_col[i-1]
            pid_start = i
        end
        start_idx = max(pid_start, i - windowsize)
        rolling_R[i] = mean(view(er_col, start_idx:i))
        rolling_in_hh_R[i] = mean(view(ih_col, start_idx:i))
        rolling_out_hh_R[i] = mean(view(oh_col, start_idx:i))
    end

    eff_r.rolling_R = rolling_R
    eff_r.rolling_in_hh_R = rolling_in_hh_R
    eff_r.rolling_out_hh_R = rolling_out_hh_R

    return eff_r
end
