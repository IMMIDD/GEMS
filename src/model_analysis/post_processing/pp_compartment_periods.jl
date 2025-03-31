export compartment_periods, aggregated_compartment_periods

""" 
    compartment_periods(postProcessor::PostProcessor)

Calculates the durations of the disease compartments of all infections and
returns a `DataFrame` containing all additional infectee-related information.

# Returns

- `DataFrame` with the following columns:

| Name              | Type    | Description                                     |
| :---------------- | :------ | :---------------------------------------------- |
| `infection_id`    | `Int32` | Infectee id                                     |
| `total`           | `Int16` | Total duration of infection in ticks            |
| `exposed`         | `Int16` | Duration of the exposed period in ticks         |
| `infectious`      | `Int16` | Duration of the infectious period in ticks      |
| `pre_symptomatic` | `Int16` | Duration of the pre-symptomatic period in ticks |
| `asymptomatic`    | `Int16` | Duration of the asymptomatic period in ticks    |
| `symptomatic`     | `Int16` | Duration of the symptomatic period in ticks     |

"""
function compartment_periods(postProcessor::PostProcessor)

    # return infectionsDF(postProcessor) |>
    #     x -> transform(x,
    #         # calculate duration of exposed period
    #         [:infectious_tick, :tick] => ByRow(-) => :exposed,
    #         # calculate total duration of infectiousness
    #         [:removed_tick, :infectious_tick] => ByRow(-) => :infectious,
    #         # calculate duration of preinfectious period (if individual develops symptoms)
    #         AsTable([:symptoms_tick, :infectious_tick]) => ByRow(x -> maximum([0, x.symptoms_tick - x.infectious_tick])) => :pre_symptomatic,
    #         # calculate duration of asymptomatic period
    #         AsTable([:symptoms_tick, :removed_tick, :symptom_category]) => ByRow(x -> x.symptom_category == GEMS.SYMPTOM_CATEGORY_ASYMPTOMATIC ? x.removed_tick - x.symptoms_tick : 0) => :asymptomatic,
    #         # calculate duration of symptomatic period
    #         AsTable([:symptoms_tick, :removed_tick, :symptom_category]) => ByRow(x -> x.symptom_category != GEMS.SYMPTOM_CATEGORY_ASYMPTOMATIC ? x.removed_tick - x.symptoms_tick : 0) => :symptomatic,
    #         copycols = false) |>
    #     x -> DataFrames.select(x,
    #         :id_b => :id,
    #         :age_b => :age,
    #         :sex_b => :sex,
    #         :setting_id,
    #         :setting_type,
    #         :exposed,
    #         :infectious,
    #         :pre_symptomatic,
    #         :asymptomatic,
    #         :symptomatic)

    # load cached DF if available
    if in_cache(postProcessor, "compartment_periods")
        return(load_cache(postProcessor, "compartment_periods"))
    end

    #according to @btime, this is 10x faster than the above code
    infs = infectionsDF(postProcessor) 
    res = DataFrame(
        infection_id = infs.infection_id,
        total = infs.removed_tick .- infs.tick,
        exposed = infs.infectious_tick .- infs.tick,
        infectious = infs.removed_tick .- infs.infectious_tick,
        pre_symptomatic = (x -> max(0, x)).(infs.symptoms_tick .- infs.infectious_tick),
        asymptomatic = infs.removed_tick .- infs.tick |> # if an individual is asymptomatic, we consider the whole progression the asymptomatic period
            x -> ifelse.(infs.symptom_category .== GEMS.SYMPTOM_CATEGORY_ASYMPTOMATIC, x, Int16(0)),
        symptomatic = infs.removed_tick .- infs.symptoms_tick |>
            x -> ifelse.(infs.symptom_category .== GEMS.SYMPTOM_CATEGORY_ASYMPTOMATIC, Int16(0), x)
    )

    # cache dataframe
    store_cache(postProcessor, "compartment_periods", res)

    return res
end

function aggregated_compartment_periods(postProcessor::PostProcessor)
    
    # group compartment periods by each compartment type and put result
    # dataframes into an array for easier joining later
    cps_vector = compartment_periods(postProcessor) |>
        cps -> [
            groupby(cps, :total) |>
                x -> combine(x, nrow => :total_cnt) |>
                x -> rename(x, :total => :duration, :total_cnt => :total),

            groupby(cps, :exposed) |>
                x -> combine(x, nrow => :exposed_cnt) |>
                x -> rename(x, :exposed => :duration, :exposed_cnt => :exposed),

            groupby(cps, :infectious) |>
                x -> combine(x, nrow => :infectious_cnt) |>
                x -> rename(x, :infectious => :duration, :infectious_cnt => :infectious),

            groupby(cps, :pre_symptomatic) |>
                x -> combine(x, nrow => :pre_symptomatic_cnt) |>
                x -> rename(x, :pre_symptomatic => :duration, :pre_symptomatic_cnt => :pre_symptomatic),

            groupby(cps, :asymptomatic) |>
                x -> combine(x, nrow => :asymptomatic_cnt) |>
                x -> rename(x, :asymptomatic => :duration, :asymptomatic_cnt => :asymptomatic),

            groupby(cps, :symptomatic) |>
                x -> combine(x, nrow => :symptomatic_cnt) |>
                x -> rename(x, :symptomatic => :duration, :symptomatic_cnt => :symptomatic)
        ]

    # normalizing
    all = nrow(compartment_periods(postProcessor))
    cps_vector[1].total = cps_vector[1].total ./ all
    cps_vector[2].exposed = cps_vector[2].exposed ./ all
    cps_vector[3].infectious = cps_vector[3].infectious ./ all
    cps_vector[4].pre_symptomatic = cps_vector[4].pre_symptomatic ./ all
    cps_vector[5].asymptomatic = cps_vector[5].asymptomatic ./ all
    cps_vector[6].symptomatic = cps_vector[6].symptomatic ./ all

    # empty dataframe with all possible "durations" (in ticks)
    res = DataFrame(
        duration = Int16(0):Int16(maximum(map(cps -> isempty(cps.duration) ? 0 : maximum(cps.duration), cps_vector)))
    )

    # join each previously generated dataframe
    for item in cps_vector
        res = leftjoin(res, item, on = :duration)
    end

    # fill up missing values with 0 and return
    return coalesce.(res, 0)
end