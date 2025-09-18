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
    process_births!(sim::Simulation, daily_birth_rate::Float64)

Adds new individuals (births) to the population based on a daily birth rate.
"""
function process_births!(sim::Simulation, daily_birth_rate::Float64)
    pop = population(sim)
    num_births = rand(Poisson(daily_birth_rate * size(pop)))

    if num_births == 0 return end

    
    # get the highest existing individual ID to ensure new IDs are unique
    max_id = maximum(i -> id(i), individuals(pop))

    for i in 1:num_births
        # create a new individual
        new_id = max_id + i
        newborn = Individual(
            id = new_id,
            age = 0,
            sex = rand(1:2)
        )

        # assign the newborn to a random household
        target_household = rand(households(sim))
        setting_id!(newborn, Household, id(target_household))
        add!(pop, newborn)
        add!(target_household, newborn)
    end
end