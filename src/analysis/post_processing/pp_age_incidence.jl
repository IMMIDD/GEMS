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

| Name      | Type      | Description                   |
| :-------- | :-------- | :---------------------------- |
| `tick`    | `Int16`   | Simulation tick (time)        |
| `pathogen_id` | `Int8` | Pathogen identifier           |
| `total`   | `Float64` | Total incidence               |
| `a0_10`   | `Float64` |Incidence in age cohort 0-10   |
| `a11_20`  | `Float64` |Incidence in age cohort 11-20  |
| `a21_30`  | `Float64` |Incidence in age cohort 21-30  |
| `a31_40`  | `Float64` |Incidence in age cohort 31-40  |
| `a41_50`  | `Float64` |Incidence in age cohort 41-50  |
| `a51_60`  | `Float64` |Incidence in age cohort 51-60  |
| `a61_70`  | `Float64` |Incidence in age cohort 61-70  |
| `a71_80`  | `Float64` |Incidence in age cohort 71-80  |
| `a81_90`  | `Float64` |Incidence in age cohort 81-90  |
| `a91_100` | `Float64` |Incidence in age cohort 91-100 |
"""
function age_incidence(postProcessor::PostProcessor, timespan::Int64, basesize::Int64)

    sim = simulation(postProcessor)
    betweenage(a, x, y) = count(v -> x <= v <= y, a)
    popfactor = length(individuals(population(sim))) / basesize
    final_tick = tick(sim)

    sim_infs = sim_infectionsDF(postProcessor)
    results = DataFrame[]

    for p in pathogens(sim)
        pid = id(p)
        p_infs = subset(sim_infs, :pathogen_id => ByRow(==(pid)), view=true)

        incidence = groupby(p_infs, :tick) |>
            x -> combine(x, nrow => :total,
                :age_a => (x -> betweenage(x, 0, 10)) => :a0_10,
                :age_a => (x -> betweenage(x, 11, 20)) => :a11_20,
                :age_a => (x -> betweenage(x, 21, 30)) => :a21_30,
                :age_a => (x -> betweenage(x, 31, 40)) => :a31_40,
                :age_a => (x -> betweenage(x, 41, 50)) => :a41_50,
                :age_a => (x -> betweenage(x, 51, 60)) => :a51_60,
                :age_a => (x -> betweenage(x, 61, 70)) => :a61_70,
                :age_a => (x -> betweenage(x, 71, 80)) => :a71_80,
                :age_a => (x -> betweenage(x, 81, 90)) => :a81_90,
                :age_a => (x -> betweenage(x, 91, 100)) => :a91_100
            ) |>
            x -> rightjoin(x, DataFrame(tick = 1:final_tick), on = :tick) |>
            x -> DataFrames.select(x, :tick, :total => ByRow(x -> coalesce(x, 0)) => :total,
                :a0_10 => ByRow(x -> coalesce(x, 0)) => :a0_10,
                :a11_20 => ByRow(x -> coalesce(x, 0)) => :a11_20,
                :a21_30 => ByRow(x -> coalesce(x, 0)) => :a21_30,
                :a31_40 => ByRow(x -> coalesce(x, 0)) => :a31_40,
                :a41_50 => ByRow(x -> coalesce(x, 0)) => :a41_50,
                :a51_60 => ByRow(x -> coalesce(x, 0)) => :a51_60,
                :a61_70 => ByRow(x -> coalesce(x, 0)) => :a61_70,
                :a71_80 => ByRow(x -> coalesce(x, 0)) => :a71_80,
                :a81_90 => ByRow(x -> coalesce(x, 0)) => :a81_90,
                :a91_100 => ByRow(x -> coalesce(x, 0)) => :a91_100)

        incidence[!,:total] = convert.(Float64, incidence[!,:total])
        incidence[!,:a0_10] = convert.(Float64, incidence[!,:a0_10])
        incidence[!,:a11_20] = convert.(Float64, incidence[!,:a11_20])
        incidence[!,:a21_30] = convert.(Float64, incidence[!,:a21_30])
        incidence[!,:a31_40] = convert.(Float64, incidence[!,:a31_40])
        incidence[!,:a41_50] = convert.(Float64, incidence[!,:a41_50])
        incidence[!,:a51_60] = convert.(Float64, incidence[!,:a51_60])
        incidence[!,:a61_70] = convert.(Float64, incidence[!,:a61_70])
        incidence[!,:a71_80] = convert.(Float64, incidence[!,:a71_80])
        incidence[!,:a81_90] = convert.(Float64, incidence[!,:a81_90])
        incidence[!,:a91_100] = convert.(Float64, incidence[!,:a91_100])

        # caculate incidences (start at max tick to not override values needed in another row)
        for i in reverse(1:nrow(incidence))
            incidence[i, "total"] = sum(incidence[maximum([1,i-timespan]):i,"total"]) / popfactor
            incidence[i, "a0_10"] = sum(incidence[maximum([1,i-timespan]):i,"a0_10"]) / popfactor
            incidence[i, "a11_20"] = sum(incidence[maximum([1,i-timespan]):i,"a11_20"]) / popfactor
            incidence[i, "a21_30"] = sum(incidence[maximum([1,i-timespan]):i,"a21_30"]) / popfactor
            incidence[i, "a31_40"] = sum(incidence[maximum([1,i-timespan]):i,"a31_40"]) / popfactor
            incidence[i, "a41_50"] = sum(incidence[maximum([1,i-timespan]):i,"a41_50"]) / popfactor
            incidence[i, "a51_60"] = sum(incidence[maximum([1,i-timespan]):i,"a51_60"]) / popfactor
            incidence[i, "a61_70"] = sum(incidence[maximum([1,i-timespan]):i,"a61_70"]) / popfactor
            incidence[i, "a71_80"] = sum(incidence[maximum([1,i-timespan]):i,"a71_80"]) / popfactor
            incidence[i, "a81_90"] = sum(incidence[maximum([1,i-timespan]):i,"a81_90"]) / popfactor
            incidence[i, "a91_100"] = sum(incidence[maximum([1,i-timespan]):i,"a91_100"]) / popfactor
        end

        incidence.pathogen_id .= pid
        push!(results, incidence)
    end

    return isempty(results) ? DataFrame() : vcat(results...)
end

age_incidence(postProcessor::PostProcessor; timespan::Int64 = 7, basesize::Int64 = 100_000) = age_incidence(postProcessor, timespan, basesize)
