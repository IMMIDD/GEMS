export compartment_periods, aggregated_compartment_periods

# HELPER FUNCTIONS TO CALCULATE PERIODS

# calculate removed time (max of recovery and death)
calc_rem(infs) = max.(infs.recovery, infs.death)
# calculate asymptomatic, symptomatic and pre-symptomatic periods
calc_asymp(infs, rem) = ((t, so, r) -> so < 0 ? r - t : 0).(infs.tick, infs.symptom_onset, rem)
calc_symp(infs, rem) = ((so, r) -> so >= 0 ? r - so : 0).(infs.symptom_onset, rem)
calc_pre_symp(infs) = ((so, t) -> so >= 0 ? so - t : 0).(infs.symptom_onset, infs.tick)


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
| `asymptomatic`    | `Int16` | Duration of the asymptomatic period in ticks    |
| `pre_symptomatic` | `Int16` | Duration of the pre-symptomatic period in ticks |
| `symptomatic`     | `Int16` | Duration of the symptomatic period in ticks     |
| `severe`          | `Int16` | Duration of the severe period in ticks          |
| `hospitalized`    | `Int16` | Duration of the hospitalized period in ticks    |
| `icu`             | `Int16` | Duration of the ICU period in ticks             |
| `ventilated`      | `Int16` | Duration of the ventilated period in ticks      |
"""
function compartment_periods(postProcessor::PostProcessor)

    # load cached DF if available
    if in_cache(postProcessor, "compartment_periods")
        return(load_cache(postProcessor, "compartment_periods"))
    end

    res = infectionsDF(postProcessor) |>
        # calculate max of recovery and death time (as removed (rem))
        infs -> (infs, calc_rem(infs)) |>
        splat((infs, rem) -> DataFrame(
            infection_id = infs.infection_id,
            total = rem .- infs.tick,
            exposed = infs.infectiousness_onset .- infs.tick,
            infectious = rem .- infs.infectiousness_onset,
            asymptomatic = calc_asymp(infs, rem),
            pre_symptomatic = calc_pre_symp(infs),
            symptomatic = calc_symp(infs, rem),
            severe = infs.severeness_offset .- infs.severeness_onset,
            hospitalized = infs.hospital_discharge .- infs.hospital_admission,
            icu = infs.icu_discharge .- infs.icu_admission,
            ventilated = infs.ventilation_discharge .- infs.ventilation_admission
        ))

    # res = infectionsDF(postProcessor) |>
    #     # calculate max of recovery and death time (as removed (rem))
    #     infs -> DataFrame(
    #         infection_id = infs.infection_id,
    #         total = calc_rem(infs) .- infs.tick,
    #         exposed = infs.infectiousness_onset .- infs.tick,
    #         infectious = calc_rem(infs) .- infs.infectiousness_onset,
    #         asymptomatic = calc_asymp(infs, calc_rem(infs)),
    #         pre_symptomatic = calc_pre_symp(infs),
    #         symptomatic = calc_symp(infs, calc_rem(infs)),
    #         severe = infs.severeness_offset .- infs.severeness_onset,
    #         hospitalized = infs.hospital_discharge .- infs.hospital_admission,
    #         icu = infs.icu_discharge .- infs.icu_admission,
    #         ventilated = infs.ventilation_discharge .- infs.ventilation_admission
    #     )

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