export age, age_in_days

"""
    age(individual::Individual, sim::Simulation)

Calculates the age of an individual in completed years.
"""
function age(individual::Individual, sim::Simulation)::Int
    return age_in_days(individual, sim) ÷ 365
end

"""
    age_in_days(individual::Individual, sim::Simulation)

Calculates the age of an individual in days on the current simulation tick.
"""
function age_in_days(individual::Individual, sim::Simulation)::Int
    current_date = sim.startdate + Day(tick(sim))
    return (current_date - individual.birthday).value
end