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
    popfactor = length(individuals(population(sim))) / basesize
    final_tick = Int(tick(sim))

    # age cohorts as (column, lower bound, upper bound); :total counts every infection
    age_cohorts = [(:a0_10, 0, 10), (:a11_20, 11, 20), (:a21_30, 21, 30), (:a31_40, 31, 40),
        (:a41_50, 41, 50), (:a51_60, 51, 60), (:a61_70, 61, 70), (:a71_80, 71, 80),
        (:a81_90, 81, 90), (:a91_100, 91, 100)]
    # every numeric column that gets counted and rolled
    value_cols = [:total; first.(age_cohorts)]

    infs = infectionsDF(postProcessor)
    results = DataFrame[]

    for p in pathogens(sim)
        pid = id(p)
        counts = _age_incidence_counts(infs.tick, infs.id_a, infs.pathogen_id, infs.age_b, pid, final_tick, age_cohorts)

        # one row per tick, in tick order
        incidence = DataFrame(tick = 1:final_tick)
        for (c, col) in enumerate(value_cols)
            incidence[!, col] = convert(Vector{Float64}, counts[:, c])
        end

        # caculate incidences (start at max tick to not override values needed in another row)
        for i in reverse(1:nrow(incidence))
            window = max(1, i - timespan + 1):i
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

# Infections of pathogen `pid` per tick in `1:final_tick`: all of them in the first column, then per age
# cohort of the infectee. Seeds, which have no infecter (`id_a <= 0`), are left out.
function _age_incidence_counts(ticks::AbstractVector, id_a::AbstractVector, pids::AbstractVector,
        ages::AbstractVector, pid::Integer, final_tick::Int, cohorts::Vector)
    counts = zeros(Int, final_tick, 1 + length(cohorts))
    for r in eachindex(ticks)
        (id_a[r] > 0 && pids[r] == pid) || continue
        t = Int(ticks[r])
        1 <= t <= final_tick || continue
        counts[t, 1] += 1
        a = ages[r]
        for (c, (_, lo, hi)) in enumerate(cohorts)
            lo <= a <= hi && (counts[t, c + 1] += 1)
        end
    end
    return counts
end
