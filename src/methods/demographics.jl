using Dates
using CSV
using DataFrames
using StatsBase

"""
A struct to hold pre-computed birth probability data
"""
struct BirthdayGenerator
    cum_probs_dict::Dict{Tuple{Int, String}, Vector{Float64}}
end

"""
Holds birth data for direct lookup and tracks the latest available year for fallback.
"""
struct BirthModel
    lookup_data::Dict{Tuple{Int, Int}, Float64} # Stores (Year, Month) -> Daily Births
    latest_available_year::Int
end


"""
    BirthdayGenerator(data_path::String)

Constructor for the BirthdayGenerator. Reads birth data from a CSV and
pre-computes all cumulative probabilities.
"""
function BirthdayGenerator(data_path::String)
    data = CSV.read(data_path, DataFrame)
    
    cum_probs_dict = Dict{Tuple{Int, String}, Vector{Float64}}()
    years = unique(data.year)

    for year in years
        df_year = filter(row -> row.year == year, data)
        for sex in ["male", "female"]
            counts = (sex == "male") ? df_year."total male" : df_year."total female"
            
            # Normalize and compute cumulative probabilities
            probs = counts ./ sum(counts)
            cum_probs = cumsum(probs)
            cum_probs_dict[(year, sex)] = cum_probs
        end
    end
    
    return BirthdayGenerator(cum_probs_dict)
end

"""
    BirthModel(data_path::String)

Loads birth data, prepares it for direct lookup, and finds the latest year
in the dataset to use as a fallback.
"""
function BirthModel(data_path::String)
    df = CSV.read(data_path, DataFrame)
    sort!(df, [:year, :month])

    lookup = Dict{Tuple{Int, Int}, Float64}()
    for row in eachrow(df)
        year, month = row.year, row.month
        days_in_month = daysinmonth(Date(year, month))
        daily_births = (row.total_male + row.total_female) / days_in_month
        lookup[(year, month)] = daily_births
    end

    latest_year = maximum(filter(row -> row.month == 12, df).year)

    return BirthModel(lookup, latest_year)
end


"""
    generate_birthday(generator::BirthdayGenerator, age::Int, sex::Int, sim_start_date::Date)

Generates a plausible birthday using the pre-computed data in the generator.
"""
function generate_birthday(generator::BirthdayGenerator, age::Int, sex::Int, sim_start_date::Date)
    birth_year = year(sim_start_date) - age
    
    sex_str = (sex == 1) ? "female" : "male" 

    key = (birth_year, sex_str)
    if !haskey(generator.cum_probs_dict, key)
        # Fallback for years not in the data 
        @warn "No birth data for year $birth_year. Using random month/day."
        birth_month = rand(1:12)
        birth_day = rand(1:daysinmonth(Date(birth_year, birth_month)))
        return Date(birth_year, birth_month, birth_day)
    end

    cum_probs = generator.cum_probs_dict[key]
    
    # Sample month and day
    r = rand()
    month_idx = searchsortedfirst(cum_probs, r)
    
    # Interpolation to find the day within the month
    lower_bound = (month_idx == 1) ? 0.0 : cum_probs[month_idx - 1]
    upper_bound = cum_probs[month_idx]
    fraction_in_month = (r - lower_bound) / (upper_bound - lower_bound)
    
    days = daysinmonth(Date(birth_year, month_idx))
    day = clamp(round(Int, fraction_in_month * days), 1, days)
    
    return Date(birth_year, month_idx, day)
end




"""
    get_births_for_tick(model::BirthModel, current_date::Date)

Returns the number of births for a given day.
It first tries a direct lookup. If no data exists, it uses the data
from the latest available year as a fallback.
"""
function get_births_for_tick(model::BirthModel, tick::Int16)
    current_date = sim.startdate + Day(tick)
    year_key, month_key = year(current_date), month(current_date)

    primary_key = (year_key, month_key)

    avg_daily_births = 0.0

    # try to find the data for the current year and month
    if haskey(model.lookup_data, primary_key)
        avg_daily_births = model.lookup_data[primary_key]
    else
        # if not found, fall back to the latest available year
        @warn "No birth data for $(monthname(current_date)) $year_key. Using data from $(model.latest_available_year)." maxlog=1

        fallback_key = (model.latest_available_year, month_key)
        avg_daily_births = model.lookup_data[fallback_key]
    end

    # Return a random number of births for the day based on that rate
    return rand(Poisson(avg_daily_births))
end
