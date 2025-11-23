export RegionalSeeds
export pathogen, seeds
export initialize!

"""
    RegionalSeeds <: StartCondition

A `StartCondition` that infects the provided number of individual at the beginning (drawn at random) in 
the regions provided by their AGS (community identification number).

# Fields
- `pathogen::Pathogen`: The pathogen with which the individual(s) has to be infected
- `seeds::Dict{Int64, Int64}`: Dict that holds {AGS, NUMBER} pairs specifying the regions and the respective number of individuals that shall be infected at initialization. 

Example
```julia
# 5 and 7 individuals infected at random in regions 13003000 and 13076033
# needs to be used with a population that contains these regions, e.g., "MV"
condition = RegionalSeeds(seeds = Dict(13003000=>5, 13076033=>7))
sim = Simulation(population = "MV", start_condition = condition)
```
"""
struct RegionalSeeds <: StartCondition
    pathogen::String
    # region and number of seeds
    seeds::Dict{Int64, Int64}

    function RegionalSeeds(;pathogen::String = "", seeds::Dict = Dict{Int64, Int64}())
        isempty(seeds) && throw(ArgumentError("At least one {AGS, NUMBER} pair must be provided in seeds."))
        AGS.(keys(seeds)) # try casting to AGS (will throw error if invalid)

        sds = Dict{Int64, Int64}()
        for (k, v) in seeds
            try
                sds[typeof(k) <: Int ? k : parse(Int64, k)] = typeof(v) <: Int ? v : parse(Int64, v)
            catch e
                println(e)
                throw("You need to pass values that can be parsed to integers to the RegionalSeeds start condition.")
            end
        end

        return new(pathogen, sds)
    end
end
Base.show(io::IO, cnd::RegionalSeeds) = write(io, "RegionalSeeds(AGS=$(join(["$k($v)" for (k,v) in cnd.seeds], ", ")))")



"""
    pathogen(regionalseeds::RegionalSeeds)

Returns pathogen used to infect individuals at the beginning  using the `RegionalSeeds` start condition.
"""
function pathogen(regionalseeds::RegionalSeeds)::String
    return regionalseeds.pathogen
end

"""
    seeds(regionalseeds::RegionalSeeds)

Returns the dictionary holding the {AGS, NUMBER} pairs, specifying the regions
(via community identification number (AGS)) and the number of initial infections
using the `RegionalSeeds` start condition.
"""
function seeds(regionalseeds::RegionalSeeds)
    return regionalseeds.seeds
end


"""
    initialize!(simulation::Simulation, condition::RegionalSeeds; seed_sample::Union{Int64,Nothing}=nothing)

Initializes the simulation model, infecting the number of individuals
in the regions, both provided by the `RegionalSeeds` start condition.
Regions can be specified as states, counties or municipalities.

It would also be possible to provide, e.g., a municiaplity AND its
surrounding county. In that case, an individual could be sampled twice.
This function will not prevent that but throw a warning.
"""
function initialize!(simulation::Simulation, condition::RegionalSeeds; seed_sample::Union{Int64,Nothing}=nothing)
    # create a new Xoshiro RNG for sampling, seeded from rng(simulation) if seed_sample is nothing, or from seed_sample otherwise
    rng_sample = isnothing(seed_sample) ? rng(simulation) : Xoshiro(seed_sample)

    # TODO handle pathogen selection
    # TODO handle multiple pathogens

    # takes an input vector of AGS and a reference AGS
    # returns a bitvector indicating whether the respective
    # AGS is equal to (for municipalities) or contained
    # in the proivided "parent_ags"
    function filter_by_ags(ags_vector, parent_ags)
        if is_state(parent_ags)
            return (a -> in_state(a, parent_ags)).(ags_vector)
        elseif is_county(parent_ags)
            return (a -> in_state(a, parent_ags)).(ags_vector)
        else
            return parent_ags .== ags_vector
        end
    end

    # build dataframe referencing AGS (extracted from households)
    # and individuals
    ind_ags = individuals(simulation) |>
        inds -> DataFrame(
            ags = (i -> ags(household(i, simulation))).(inds),
            individual = inds)

    # build array of individuals to infect
    to_infect = Individual[]
    for (a, cnt) in seeds(condition)
        try
            AGS(a) |>
                # filter individuals depending on AGS
                # (whether its a state, county, or municipality)
                in_ags -> ind_ags.individual[filter_by_ags(ind_ags.ags, in_ags)] |>
                # sample required number of individuals
                inds -> gems_sample(rng_sample, inds, cnt, replace=false) |>
                inds -> append!(to_infect, inds)
        catch
            throw("Getting the seeding infections crashed. You might have provided a region in the configs that is not available in the population model or asked to infect a number of people that exceeds the population size of the region.")
        end
    end

    # theoretically, an individual can get selected multiple times
    # if the dict has AGSs' that are contained in others
    # we don't resample in that case but just print a warning
    if length(unique(to_infect)) != length(to_infect)
        @warn "One or more individuals were sampled multiple times for the seeding infections. You may have passed nested regions (AGS) to the StartCondition causing this problem."
    end

    # infect individuals
    for i in to_infect
        infect!(i, tick(simulation), pathogen(simulation), sim = simulation, rng = rng_sample)

        for (type, id) in settings(i, simulation)
            activate!(settings(simulation, type)[id])
        end
    end
end