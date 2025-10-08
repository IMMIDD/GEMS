export generate_birthday, get_births_for_tick


"""
    generate_birthday(generator::BirthdayGenerator, age::Int, sex::Int, sim_start_date::Date)

Generates a plausible birthday using the pre-computed data in the generator.
"""
function generate_birthday(generator::BirthdayGenerator, age::Int8, sex::Int8, sim_start_date::Date)
    birth_year = year(sim_start_date) - age
    
    sex_str = (sex == 1) ? "female" : "male" 

    key = (birth_year, sex_str)
    if !haskey(generator.cum_probs_dict, key)
        # Fallback for years not in the data 
        @warn "No birth data for year $birth_year. Using closest available year."

        _, index = findmin(abs.(generator.available_years .- birth_year))
        birth_year = generator.available_years[index]

        key = (birth_year, sex_str) 
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
function get_births_for_tick(model::BirthModel, sim::Simulation)
    current_date = sim.startdate + Day(sim.tick)
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
