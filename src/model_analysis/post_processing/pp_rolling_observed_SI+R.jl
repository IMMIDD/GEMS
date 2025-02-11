export rolling_observed_SI, observed_R

"""
    rolling_observed_SI(postProcessor::PostProcessor)

Returns a `DataFrame` containing aggregated estimations on the serial interval based on true detected cases.
The estimations are based on all true detected cases in a 14-past-days time window.
If fewer than 50 infections were recorded in that time window, detections prior to
that are added until the sample is complete.
This is done in order to reduce large stochastic fluctuations due to small sample size.

# Returns

- `DataFrame` with the following columns:

| Name          | Type      | Description                                                  |
| :------------ | :-------- | :----------------------------------------------------------- |
| `tick`        | `Int16`   | Simulation tick (time)                                       |
| `min_SI`      | `Int16`   | Minimal serial interval recored for any infection that tick  |
| `max_SI`      | `Int16`   | Maximum serial interval recored for any infection that tick  |
| `lower_95_SI` | `Float64` | Lower 95% confidence interval for serial intervals that tick |
| `upper_95_SI` | `Float64` | Upper 95% confidence interval for serial intervals that tick |
| `std_SI`      | `Float64` | Stanard deviation for serial intervals that tick             |
| `mean_SI`     | `Float64` | Mean for serial intervals that tick                          |
"""
function rolling_observed_SI(postProcessor::PostProcessor)

    # detected cases and serial interval
    detections = postProcessor |> detected_infections |>
        # filter for data with known serial interval
        x -> x[.!ismissing.(x.serial_interval), :] |>
        # rename to SI
        x -> DataFrames.select(x, :tick, :serial_interval => :SI) |>
        x -> sort!(x, :tick)

    # parameters
    casethreshold = SI_ESTIMATION_CASE_THRESHOLD # case threshold for SI estimation (loop up constants.jl)
    windowsize = SI_ESTIMATION_TIME_WINDOW # time window (look up constants.jl)
    final_tick = postProcessor |> simulation |> tick

    res = [] 

    # iterate through each tick
    for t in 1:final_tick
        # build dicts to use aggregate_value function and flatten into a DF later
        dictrow = Dict("tick" => Int16(t))

        # given, that dataframe will probably not have an entry
        # for each possible tick, find largest tick with tick <= t
        end_index = findlast(row -> row.tick <= t, eachrow(detections))

        # find start index (based on window-size)
        start_index = findfirst(row -> row.tick > t - windowsize + 1, eachrow(detections))

        # if neither start nor end-index is missing, proceed to calculate values
        # end_index, for exmaple, is missing for all values where t is below the tick of the first detected case
        if !isnothing(end_index) && !isnothing(start_index)

            # if window does not at least contain 50 cases, update start_index
            if (end_index - start_index) < casethreshold
                start_index = max(1, end_index - casethreshold)
            end

            # call aggregate values function to get mean, range, and confidence intervals
            dictrow = merge(dictrow, Dict(k * "_SI" => v for (k, v) in aggregate_values(detections.SI[start_index:end_index])))
            push!(res, dictrow)
        end
    end

    # if result vector is empty, return empty dataframe
    if res |> length <= 0
        return(
            DataFrame(
                tick = 1:final_tick,
                min_SI = Vector{Union{Int16, Missing}}(missing, final_tick),
                max_SI = Vector{Union{Int16, Missing}}(missing, final_tick),
                lower_95_SI = Vector{Union{Float64, Missing}}(missing, final_tick),
                upper_95_SI = Vector{Union{Float64, Missing}}(missing, final_tick),
                std_SI = Vector{Union{Float64, Missing}}(missing, final_tick),
                mean_SI = Vector{Union{Float64, Missing}}(missing, final_tick)
            )
        )
    end

    # convert array to dataframe
    res = DataFrame(res)

    # remove values with "negative" confidence intervals
    for row in eachrow(res)
        if ismissing(row.lower_95_SI) || isnan(row.lower_95_SI) || row.lower_95_SI <= 0
            row.mean_SI = NaN
            row.std_SI = NaN
            row.lower_95_SI = NaN
            row.upper_95_SI = NaN
        end
    end

    # result dataframe from combining dicts
    return(
        res |>
            x -> leftjoin(DataFrame(tick = 1:final_tick), x, on = [:tick => :tick]) |>
            x -> sort(x, :tick)
    )
end

"""
    observed_R(postProcessor::PostProcessor)

Returns a `DataFrame` containing estimations for the effective (current)
reproduction number R, based on detected infections. The calculation uses the 
estimation for the (rolling) observed serial interval (SI) and the total of detected
cases within a time window of the length defined in `R_ESTIMATION_TIME_WINDOW`
(lookup `constants.jl`) ending with a current tick `t`. It divides the total
detected infections in the current time window with the total detected infections
in the time window that lies one SI behind. The function does this for the mean
estimate of the serial interval as well as the (floored) lower-95% confidence bound
and the (ceiled) upper-95% confidence bound.

# Example

- For tick `t = 42` and
- Given the `R_ESTIMATION_TIME_WINDOW = 7`, and
- The rolling observed serial interval being `4`,
- This function does: `sum(infections[35:42]) / sum(infections[31:38])`

# Returns

- `DataFrame` with the following columns:

| Name          | Type      | Description                                                 |
| :------------ | :-------- | :---------------------------------------------------------- |
| `tick`        | `Int16`   | Simulation tick (time)                                      |
| `mean_est_R`  | `Float64` | Mean estimation (based on detected infections) for R        |
| `lower_est_R` | `Float64` | Lower bound estimation (based on detected infections) for R |
| `upper_est_R` | `Float64` | Upper bound estimation (based on detected infections) for R |
"""
function observed_R(postProcessor::PostProcessor)
    
    # required data frames
    roSI = postProcessor |> rolling_observed_SI
    rtc = postProcessor |> reported_tick_cases
    
    # required constants
    r_window = R_ESTIMATION_TIME_WINDOW

    # join with reported cases
    df = roSI |> 
        x -> leftjoin(x, rtc, on = [:tick => :tick])

    # add empty columns
    df.reported_cnt_window = zeros(Int, df |> nrow)
    df.lower_est_R = Vector{Union{Float64, Missing}}(missing, df |> nrow)
    df.mean_est_R = Vector{Union{Float64, Missing}}(missing, df |> nrow)
    df.upper_est_R = Vector{Union{Float64, Missing}}(missing, df |> nrow)

    for i in 1:nrow(df)
        # sum up reported cases in time window
        df.reported_cnt_window[i] = df.reported_cnt[max(1, i - r_window + 1):i] |> sum

        # calculate the time points to compare the 
        # rolling R sum to based on the mean estimation
        # of the current SI and the 95% confidence bands
        diff_lower_SI = i - floor(df.lower_95_SI[i])
        diff_mean_SI = i - round(df.mean_SI[i])
        diff_upper_SI = i - ceil(df.upper_95_SI[i])

        # 

        # only do calculation if the diff-points are not missing and
        # all time points are at least one time window away from the simulation start
        if !ismissing(diff_lower_SI) && !ismissing(diff_mean_SI) && !ismissing(diff_upper_SI) &&
            (diff_lower_SI >= r_window) && (diff_mean_SI >= r_window) && (diff_upper_SI >= r_window)

            # weekly current count and counts for time points in the past dependent on SI 
            crrnt_cnt = df.reported_cnt_window[i]
            lower_diff_cnt = df.reported_cnt_window[Int(diff_lower_SI)]
            mean_diff_cnt = df.reported_cnt_window[Int(diff_mean_SI)]
            upper_diff_cnt = df.reported_cnt_window[Int(diff_upper_SI)]

            # only calculate R if 7-tick time window has enough infections
            # to get a reliable "idea" of the dynamics
            if (crrnt_cnt >= R_CALCULATION_THRESHOLD) &&
                (lower_diff_cnt >= R_CALCULATION_THRESHOLD) &&
                (mean_diff_cnt >= R_CALCULATION_THRESHOLD) &&
                (upper_diff_cnt >= R_CALCULATION_THRESHOLD)

                df.lower_est_R[i] = crrnt_cnt / lower_diff_cnt
                df.mean_est_R[i] = crrnt_cnt / mean_diff_cnt
                df.upper_est_R[i] = crrnt_cnt / upper_diff_cnt
            end
        end
    end

    return(
        df |> 
            x -> DataFrames.select(x, :tick, :mean_est_R, :lower_est_R, :upper_est_R)
    )
end