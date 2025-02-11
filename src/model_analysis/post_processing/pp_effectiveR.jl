export effectiveR

"""
    effectiveR(postProcessor::PostProcessor)

Returns a `DataFrame` containing the effective R value for each tick.

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

| Name          | Type      | Description                                         |
| :------------ | :-------- | :-------------------------------------------------- |
| `tick`        | `Int16`   | Simulation tick (time)                              |
| `effective_R` | `Float64` | Effective R-value                                   |
| `rolling_R`   | `Float64` | Effective R rolling average of the 7 previous ticks |
"""
function effectiveR(postProcessor::PostProcessor)
    windowsize = 7 # for rolling R calculation
    sim = simulation(postProcessor)
    
    # calculate effective R over time from post processor data
    eff_r = sim_infectionsDF(postProcessor) |> 
    # take infectees to calculate R (to also cover individuals who don't infect anybody)
    x -> DataFrames.select(x, [:infection_id, :tick]) |>
    x -> leftjoin(x, 
        # join to find individuals who subsequently been infected by an infectee
        sim_infectionsDF(postProcessor) |>
            x -> groupby(x, :source_infection_id) |>
            x -> combine(x,
                nrow => :infections,
                :setting_type => (st -> length(st[st .== 'h'])) => :in_hh_infections,
                :setting_type => (st -> length(st[st .!= 'h'])) => :out_hh_infections)
    , on = [:infection_id => :source_infection_id]) |>
    # for individuals who didn't infect anybody, set "infections" to 0
    x -> DataFrames.select(x, :infection_id => :id, :tick,
        :infections => ByRow(x -> coalesce(x, 0)) => :infections,
        :in_hh_infections => ByRow(x -> coalesce(x, 0)) => :in_hh_infections,
        :out_hh_infections => ByRow(x -> coalesce(x, 0)) => :out_hh_infections) |>
    # calulate total_infections / spreaders per tick (effective R)
    x -> groupby(x, :tick) |>
    x -> combine(x,
        :infections => sum => :tick_infections,
        :in_hh_infections => sum => :tick_in_hh_infections,
        :out_hh_infections => sum => :tick_out_hh_infections,
        nrow => :spreaders) |>
    x -> transform(x, 
        [:tick_infections, :spreaders] => ByRow(/) => :effective_R,
        [:tick_in_hh_infections, :spreaders] => ByRow(/) => :in_hh_effective_R,
        [:tick_out_hh_infections, :spreaders] => ByRow(/) => :out_hh_effective_R)  |>
    x -> DataFrames.select(x, [:tick, :effective_R, :in_hh_effective_R, :out_hh_effective_R]) |>
    # join with artificial DF of all ticks to also get ticks with 0 infections
    x -> rightjoin(x, DataFrame(tick = 1:tick(sim)), on = :tick) |>
    # remove missing Rs for ticks
    x -> DataFrames.select(x, :tick,
        :effective_R => ByRow(x -> coalesce(x, 0.0)) => :effective_R,
        :in_hh_effective_R => ByRow(x -> coalesce(x, 0.0)) => :in_hh_effective_R,
        :out_hh_effective_R => ByRow(x -> coalesce(x, 0.0)) => :out_hh_effective_R)


        # calculating rolling R with windowsize
        rolling_R = Vector{Float64}(undef, eff_r |> nrow)
        rolling_in_hh_R = Vector{Float64}(undef, eff_r |> nrow)
        rolling_out_hh_R = Vector{Float64}(undef, eff_r |> nrow)

        for i in 1:(eff_r |> nrow)
            rolling_R[i] = mean((eff_r)[max(1, i-windowsize):i, "effective_R"])
            rolling_in_hh_R[i] = mean((eff_r)[max(1, i-windowsize):i, "in_hh_effective_R"])
            rolling_out_hh_R[i] = mean((eff_r)[max(1, i-windowsize):i, "out_hh_effective_R"])
        end

        eff_r.rolling_R = rolling_R
        eff_r.rolling_in_hh_R = rolling_in_hh_R
        eff_r.rolling_out_hh_R = rolling_out_hh_R

    return eff_r
end
