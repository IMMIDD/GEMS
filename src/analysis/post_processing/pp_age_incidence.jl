export age_incidence

"""
    age_incidence(postProcessor::PostProcessor, timespan::Int64, basesize::Int64)
    age_incidence(postProcessor::PostProcessor; timespan::Int64 = 7, basesize::Int64 = 100_000)

Returns a `DataFrame` containing the infection incidence stratified by (10-year) age groups,
per pathogen.

# Parameters

- `postProcessor::PostProcessor`: Post processor instance
- `timespan::Int64`: Reference time window to calculate incidence
- `basesize::Int64`: Reference population size to calculate incidence

# Returns

- `DataFrame` with the following columns:

| Name          | Type      | Description                    |
| :------------ | :-------- | :----------------------------- |
| `tick`        | `Int16`   | Simulation tick (time)         |
| `pathogen_id` | `Int8`    | Pathogen identifier            |
| `total`       | `Float64` | Total incidence                |
| `a0_10`       | `Float64` | Incidence in age cohort 0-10   |
| `a11_20`      | `Float64` | Incidence in age cohort 11-20  |
| `a21_30`      | `Float64` | Incidence in age cohort 21-30  |
| `a31_40`      | `Float64` | Incidence in age cohort 31-40  |
| `a41_50`      | `Float64` | Incidence in age cohort 41-50  |
| `a51_60`      | `Float64` | Incidence in age cohort 51-60  |
| `a61_70`      | `Float64` | Incidence in age cohort 61-70  |
| `a71_80`      | `Float64` | Incidence in age cohort 71-80  |
| `a81_90`      | `Float64` | Incidence in age cohort 81-90  |
| `a91_100`     | `Float64` | Incidence in age cohort 91-100 |
"""
function age_incidence(postProcessor::PostProcessor, timespan::Int64, basesize::Int64)

    sim = simulation(postProcessor)
    betweenage(a, x, y) = count(v -> x <= v <= y, a)
    popfactor = length(individuals(population(sim))) / basesize
    final_tick = tick(sim)

    # age cohorts as (column, lower bound, upper bound); :total is counted separately via nrow
    age_cohorts = [(:a0_10, 0, 10), (:a11_20, 11, 20), (:a21_30, 21, 30), (:a31_40, 31, 40),
        (:a41_50, 41, 50), (:a51_60, 51, 60), (:a61_70, 61, 70), (:a71_80, 71, 80),
        (:a81_90, 81, 90), (:a91_100, 91, 100)]
    # every numeric column that gets coalesced, converted and rolled
    value_cols = [:total; first.(age_cohorts)]

    sim_infs = sim_infectionsDF(postProcessor)
    results = DataFrame[]

    for p in pathogens(sim)
        pid = id(p)
        p_infs = subset(sim_infs, :pathogen_id => ByRow(==(pid)), view=true)

        cohort_counts = [:age_a => (a -> betweenage(a, lo, hi)) => col for (col, lo, hi) in age_cohorts]
        coalesce_zero = [col => ByRow(x -> coalesce(x, 0)) => col for col in value_cols]

        incidence = groupby(p_infs, :tick) |>
            x -> combine(x, nrow => :total, cohort_counts...) |>
            x -> rightjoin(x, DataFrame(tick = 1:final_tick), on = :tick) |>
            x -> DataFrames.select(x, :tick, coalesce_zero...)

        for col in value_cols
            incidence[!, col] = convert.(Float64, incidence[!, col])
        end

        # caculate incidences (start at max tick to not override values needed in another row)
        for i in reverse(1:nrow(incidence))
            window = maximum([1, i - timespan]):i
            for col in value_cols
                incidence[i, col] = sum(incidence[window, col]) / popfactor
            end
        end

        incidence.pathogen_id .= pid
        push!(results, incidence)
    end

    return isempty(results) ? DataFrame() : vcat(results...)
end

age_incidence(postProcessor::PostProcessor; timespan::Int64 = 7, basesize::Int64 = 100_000) = age_incidence(postProcessor, timespan, basesize)
