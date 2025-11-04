export generate_birthday, get_births_for_tick


"""
    generate_birthday(generator::BirthdayGenerator, age::Int, sex::Int, sim_start_date::Date)

Generates a plausible birthday using the pre-computed data in the generator.
"""
function generate_birthday(generator::BirthdayGenerator, age::Integer, sex::Integer, sim_start_date::Date)
    # birthday range
    latest_bday = sim_start_date - Year(age)
    earliest_bday = sim_start_date - Year(age + 1) + Day(1)
    
    year_end = year(latest_bday)   
    year_start = year(earliest_bday) #

    # 2ind the closest available year in the data for probability lookup
    lookup_year = year_end
    sex_str = (sex == 1) ? "female" : "male" 
    key = (lookup_year, sex_str)

    if !haskey(generator.cum_probs_dict, key)
        # Fallback for years not in the data
        # @warn "No birth data for year $lookup_year. Using closest available year."

        _, index = findmin(abs.(generator.available_years .- lookup_year))
        lookup_year = generator.available_years[index]
        key = (lookup_year, sex_str) 
    end

    cum_probs = generator.cum_probs_dict[key]

    # sample month and day based on the lookup_year's probabilities
    r = rand()
    month_idx = searchsortedfirst(cum_probs, r)
    
    # Interpolation to find the day within the month
    lower_bound = (month_idx == 1) ? 0.0 : cum_probs[month_idx - 1]
    upper_bound = cum_probs[month_idx]
    
    # Handle potential division by zero if upper and lower bounds are the same 
    fraction_in_month = 0.0
    if (upper_bound - lower_bound) > 0.0
        fraction_in_month = (r - lower_bound) / (upper_bound - lower_bound)
    end
    
    days_in_lookup_month = daysinmonth(Date(lookup_year, month_idx))
    day_sampled = clamp(round(Int, fraction_in_month * days_in_lookup_month), 1, days_in_lookup_month)

    # construct the final date, handling leap years and the two-year window
    
    days_in_end_year_month = daysinmonth(Date(year_end, month_idx))
    final_day = min(day_sampled, days_in_end_year_month)
    
    bday_candidate = Date(year_end, month_idx, final_day)
    
    # Check if this date is valid.
    # If the sampled date is after the latest possible birthday, the person must have been born in the earlier year.
    if bday_candidate > latest_bday
        days_in_start_year_month = daysinmonth(Date(year_start, month_idx))
        final_day = min(day_sampled, days_in_start_year_month)
        
        return Date(year_start, month_idx, final_day)
    else
        return bday_candidate
    end
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

    per_capita_rate = 0.0

    # try to find the data for the current year and month
    if haskey(model.lookup_per_capita_rate, primary_key)
        per_capita_rate = model.lookup_per_capita_rate[primary_key]
    else
        # if not found, fall back to the latest available year
        #@warn "No birth data for $(monthname(current_date)) $year_key. Using data from $(model.latest_available_year)." maxlog=1

        fallback_key = (model.latest_complete_year, month_key)
        per_capita_rate = model.lookup_per_capita_rate[fallback_key]
    end


    # Return a random number of births for the day based on that rate and current population size
    current_pop_size = size(population(sim))
    lambda = per_capita_rate * current_pop_size
    lambda = max(0.0, lambda)
    return rand(Poisson(lambda))
end




"""
    update_maternal_cache!(sim::Simulation)

Recalculates the lists of eligible mothers based on their current age.
"""
function update_maternal_cache!(sim::Simulation)
    # clear cache
    cache = sim.maternal_cache
    empty!(cache.under_18)
    empty!(cache.between_18_and_40)
    empty!(cache.between_40_and_49)

    # get age and define buckets
    current_date = sim.startdate + Day(tick(sim))
    age_15 = 15 * 365
    age_18 = 18 * 365
    age_40 = 40 * 365
    age_49 = 49 * 365

    for ind in individuals(population(sim))
        if sex(ind) == FEMALE
            age_days = age(ind, current_date)

            # sort them into the correct bucket
            if age_days >= age_15 && age_days <= age_49
                if age_days < age_18
                    push!(cache.under_18, ind)
                elseif age_days < age_40
                    push!(cache.between_18_and_40, ind)
                else
                    push!(cache.between_40_and_49, ind)
                end
            end
        end
    end
    sim.last_maternal_cache_update = tick(sim)
end




"""
Selects a random mother from the population based on a weighted
age distribution. Handles maternal cache updates.
"""
function select_random_mother(sim::Simulation)
    # check if the cache needs updating 
    CACHE_INVALIDATION_DAYS = 30
    if sim.last_maternal_cache_update == -1 || tick(sim) - sim.last_maternal_cache_update > CACHE_INVALIDATION_DAYS
        update_maternal_cache!(sim)
    end

    cache = sim.maternal_cache

    # define birht weights
    weights = Weights([0.0026, 0.932, 0.065])

    # get all non empty groups
    all_groups = [cache.under_18, cache.between_18_and_40, cache.between_40_and_49]
    available_groups = Vector{Vector{Individual}}()
    available_weights = Float64[]
    if !isempty(all_groups[1])
        push!(available_groups, all_groups[1])
        push!(available_weights, weights[1])
    end
    if !isempty(all_groups[2])
        push!(available_groups, all_groups[2])
        push!(available_weights, weights[2])
    end
    if !isempty(all_groups[3])
        push!(available_groups, all_groups[3])
        push!(available_weights, weights[3])
    end

    # random non-empty group
    chosen_group = sample(available_groups, Weights(available_weights))
    # random mother within that group
    return rand(chosen_group)
end




"""
    initialize_maternal_links!(sim::Simulation)

Iterates through the initial population and infers a mother for any
individual under 18. This "best-guess" uses a weighted probability
distribution if multiple potential mothers are found in a household.
"""
function initialize_maternal_links!(sim::Simulation)
    current_date = sim.startdate + Day(tick(sim)) 

    # Define age brackets in days
    age_15 = 15 * 365
    age_18 = 18 * 365
    age_40 = 40 * 365
    age_49 = 49 * 365

    for ind in individuals(population(sim))
        if age_in_years(ind, current_date) < 18 && ind.mother_id == -1
            
            hh = households(sim)[household_id(ind)]
            potential_mothers = Individual[]
            
            for member in individuals(hh)
                if sex(member) == FEMALE
                    age_days = age(member, current_date)
                    # Check if they are in the childbearing age range
                    if age_days >= age_15 && age_days <= age_49
                        push!(potential_mothers, member)
                    end
                end
            end

            # make "best guess"
            if isempty(potential_mothers)
                continue
            elseif length(potential_mothers) == 1
                ind.mother_id = id(first(potential_mothers))
            else
                # based on probability distribution
                weights = Float64[]
                for mother in potential_mothers
                    age_days = age(mother, current_date)
                    if age_days < age_18
                        push!(weights, 0.0026) 
                    elseif age_days < age_40
                        push!(weights, 0.932)  
                    else 
                        push!(weights, 0.065)  
                    end
                end
                
                # Sample one mother based on those weights
                chosen_mother = sample(potential_mothers, Weights(weights))
                ind.mother_id = id(chosen_mother)
            end
        end
    end
end