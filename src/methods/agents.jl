export age, age_in_years

"""
    age(individual::Individual, sim::Simulation)

Calculates the age of an individual in days on the current simulation tick.
"""
function age(individual::Individual, sim::Simulation)::Int
    current_date = sim.startdate + Day(tick(sim))
    return (current_date - individual.birthday).value
end

function age(individual::Individual, date::Date)::Int
    return (date - individual.birthday).value
end

"""
    age_in_years(individual::Individual, sim::Simulation)

Calculates the age of an individual in completed years.
"""
function age_in_years(individual::Individual, sim::Simulation)::Int
    return age(individual, sim) ÷ 365
end

function age_in_years(individual::Individual, date::Date)::Int
    return age(individual, date) ÷ 365
end