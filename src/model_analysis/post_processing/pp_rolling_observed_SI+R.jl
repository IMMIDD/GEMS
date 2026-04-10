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
    casethreshold = SI_ESTIMATION_CASE_THRESHOLD # loop up constants.jl
    windowsize = SI_ESTIMATION_TIME_WINDOW # loop up constants.jl
    final_tick = postProcessor |> simulation |> tick

    # Pre-allocated output arrays 
    min_SI = Vector{Union{Float64, Missing}}(missing, final_tick)
    max_SI = Vector{Union{Float64, Missing}}(missing, final_tick)
    lower_95_SI = Vector{Union{Float64, Missing}}(missing, final_tick)
    upper_95_SI = Vector{Union{Float64, Missing}}(missing, final_tick)
    std_SI = Vector{Union{Float64, Missing}}(missing, final_tick)
    mean_SI = Vector{Union{Float64, Missing}}(missing, final_tick)

    # If we have detections, process them
    if nrow(detections) > 0
        # Extract columns as vectors
        det_ticks = detections.tick
        det_SIs = detections.SI

        for t in 1:final_tick
            # Use binary search 
            end_index = searchsortedlast(det_ticks, t)
            
            start_t = t - windowsize + 1
            start_index = searchsortedfirst(det_ticks, start_t)

            # Check if we actually found a valid window
            if end_index >= 1 && start_index <= length(det_ticks) && start_index <= end_index
                
                # enforce case threshold
                if (end_index - start_index + 1) < casethreshold
                    start_index = max(1, end_index - casethreshold + 1)
                end

                # Calculate aggregates using a view to avoid copying the array slice
                agg = aggregate_values(@view det_SIs[start_index:end_index])
                
                # Check the confidence interval immediately, avoiding the secondary loop
                lower = get(agg, "lower_95", missing)
                
                if !ismissing(lower) && !isnan(lower) && lower > 0
                    min_SI[t] = get(agg, "min", missing)
                    max_SI[t] = get(agg, "max", missing)
                    lower_95_SI[t] = lower
                    upper_95_SI[t] = get(agg, "upper_95", missing)
                    std_SI[t] = get(agg, "std", missing)
                    mean_SI[t] = get(agg, "mean", missing)
                end
            end
        end
    end

    # Build and return the final dataframe directly from the arrays
    return DataFrame(
        tick = 1:final_tick,
        min_SI = min_SI,
        max_SI = max_SI,
        lower_95_SI = lower_95_SI,
        upper_95_SI = upper_95_SI,
        std_SI = std_SI,
        mean_SI = mean_SI
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