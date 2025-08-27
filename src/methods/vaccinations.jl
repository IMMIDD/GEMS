#=
THIS FILE HANDLES THE CONCRETE SCHEDULING OF INDIVIDUALS  VACCINATION
This is not to be confused with schedule! for a concrete scheduler. This
file is concerned with the "how" of distributing vaccines to a population
and contains the functionality of VaccinationStrategy.
=#
export schedule!

###
### VACCINE-STRATEGY
###
"""
    schedule!(simulation, vaccine, strategy)

Schedules the population of the `simulation` according to the provided `strategy`
for vaccination  with `vaccine`.
"""
function schedule!(
    sim::Simulation,
    vaccine::Vaccine,
    strat::VaccinationStrategy
)
error("`schedule!` not implemented for vaccination strategy" * string(typeof(strat)))
end

"""
    schedule!(simulation, vaccine, dailydosestrategy)

Schedules the population of the `simulation` with a fixed amount of vaccine doses per day
defined in `dailydoses(dailydosestrategy)` and starting from 
`available_from(dailydosestrategy)`.
"""
function schedule!(sim::Simulation, vaccine::Vaccine, strat::DailyDoseStrategy)
    iter = Iterators.partition(shuffle(rng(sim), individuals(population(sim))), dailydose(strat))
    for (tick, indis) in enumerate(iter)
        for ind in indis
            # tick starts at 1, but we want to vaccinate as soon as its available
            schedule!(
                vaccination_schedule(sim),
                ind,
                vaccine,
                Int16(strat.available_from + tick - 1)
            ) 
        end
    end
end