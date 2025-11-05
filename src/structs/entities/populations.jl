###
### POPULATIONS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export Population
export popuationfile, params
export add!, remove!, individuals, maxage, num_of_infected, issubset
export save, dataframe
export size, count, each!, first
export get_individual_by_id

"""
    Population

A Type for a simple population. Acts as a container for a collection of individuals.

# Fields
- `individuals::Vector{Individual}`: List of associated individuals
- `maxage`: Age of the oldest individual
- `minid`: smallest id of any individual
"""
mutable struct Population
    individuals::Vector{Individual}
    params::Dict{String, Any}
    maxage # maximum age of any individual. Is updated upon first call of maxage function (for caching)
    minid # smallest id of any individual. Corresponds to the offset compared to the dataset for all of germany

    @doc """
        Population(individuals::Vector{Individual})

    Creates a `Population` object from a vector of `Individual`s.
    """
    function Population(individuals::Vector{Individual})
        # Create the Population object
        pop = new(individuals, Dict("populationfile" => "Not available."), -1)
        maxage(pop)
        pop.minid = isempty(individuals) ? -1 : minimum(x -> x.id, individuals)
        return pop
    end

    
    @doc """
        Population(df::DataFrame)

    Creates a `Population` object from a `DataFrame` where each row corresponds to one individual.
    The dataframe column names must correspond to the fieldnames of the `Individual` struct.
    `id` (Int32), `age` (Int8), and `sex` (Int8) are required columns. Everything else is optional. 
    """
    function Population(df::DataFrame)
    
        # filter for columns available in DF and Individual struct
        df_content = df |>
            x -> DataFrames.select(x, intersect(map(string, fieldnames(Individual)), names(x)))

        # Pre-allocate an array for the population
        individuals = Vector{Individual}(undef, size(df_content, 1))

        # Create individuals in parallel
        Threads.@threads for i in eachindex(individuals)
            @inbounds individuals[i] = Individual(df_content[i, :])
        end

        pop = Population(individuals)
        pop.params["populationfile"] = "Not available." # update input parameters
        return pop
    end


    @doc """
        Population(path::String)

    Creates a `Population` object from a CSV- or JLD2 file (path).
    """
    function Population(path::String)
        file_ext = split(path, ".")[end]

        if file_ext == "csv"
            printinfo("\u2514 Loading population data from $(basename(path))")
            # read dataframe from CSV and pass it to df constructor
            pop = CSV.File(path) |> DataFrame |> Population
            
        elseif file_ext == "jld2"
            printinfo("\u2514 Loading population data from $(basename(path))")
            # read dataframe from JLD2 object ("data"-field) and pass it to df constructor
            pop = load(path, "data") |> Population

        else
            error("File Extension .$file_ext is not supported")
        end

        pop.params["populationfile"] = path
        pop.minid = isempty(individuals(pop)) ? -1 : minimum(x -> x.id, individuals(pop))

        return pop
    end

    @doc """
        Population(; n::Int64 = 100_000, avg_household_size::Real = 3.0, avg_office_size::Real = 5.0, avg_school_size::Real = 100.0)

    Creates a `Population` object without an explicit data source and randomly generates the individuals.
    
    # Parameters

    - `n::Int64 = 100_000` *(optional)*: Number of individuals in the population (default = `100_000`)
    - `avg_household_size::Real = 3.0` *(optional)*: Average size of households (default = `3`)
    - `avg_office_size::Real = 5.0` *(optional)*: Average size of offices (default = `5`)
    - `avg_school_size::Real = 100.0` *(optional)*: Average size of schools (default = `100`)
    - `empty::Bool = false` *(optional)*: If true, overrides all other arguments and returns a completely empty population object
    """
    function Population(;
        n::Int64 = 100_000,
        avg_household_size::Real = 3.0,
        avg_office_size::Real = 5.0,
        avg_school_size::Real = 100.0,
        rng::AbstractRNG = Random.default_rng(),
        empty::Bool = false)

        # if "empty" keyword is passed, generate an empty population object
        if empty
            return new(Individual[], Dict("populationfile" => "Not available."), -1)
        end

        # exception handling
        n <= 0 ? throw("The number of individuals must be a positive integer") : nothing
        avg_household_size <= 0 ? throw("The average household size must be a positive number") : nothing
        avg_household_size > n ? throw("The average household size cannot be larger than the population (n)") : nothing
        avg_office_size <= 0 ? throw("The average office size must be a positive number") : nothing
        avg_office_size > n ? throw("The average office size cannot be larger than the population (n)") : nothing
        avg_school_size <= 0 ? throw("The average school size must be a positive number") : nothing
        avg_school_size > n ? throw("The average school size cannot be larger than the population (n)") : nothing

        # helper functions
        group_to_age(g) = 5 * (g-1) + gems_rand(rng, 0:4)
        age_to_group(a) = min(17, (a ÷ 5) + 1)

        # GENERATE ONE INDEX INDIVIDUAL FOR EACH HOUSEHOLD BASED ON DEMOGRAPHIC DATA
        # get age-weights from census population data
        weights = DataFrame(CSV.File(dirname(dirname(pathof(GEMS))) * "/data/population_by_age.csv", header = false)) |>
            x -> hcat(x, (y -> parse(Int, replace(y, "." => ""))).(x.Column2)) |>
            x -> rename!(x, :x1 => :cnt) |>
            x -> transform(x, :cnt => ByRow(c -> c / sum(x.cnt)) => :weight) |>
            x -> x.weight

        # calculate weight of age-groups (in same intervals as contact data)
        weighted_groups = DataFrame(
                weight = weights,
                group = age_to_group.(collect(1:length(weights)))) |>
                x -> groupby(x, :group) |>
                x -> combine(x, :weight => sum => :weight)

        # number of households
        n_households = Int64(ceil(n / avg_household_size))

        # build the initial dataframe
        df = DataFrame(
            id = Int32.(collect(1:n)),
            age = Int8.([gems_rand(rng, Categorical(weights), n_households); fill(-1, n - n_households)]),
            sex = Int8.(gems_rand(rng, 1:2, n)),
            household = Int32.([collect(1:n_households); fill(-1, n - n_households)]),
            schoolclass = Int32.(fill(-1, n)),
            office = Int32.(fill(-1, n))
        )

        # ASSIGN INDIVIDUALS TO HOUSEHOLDS BASED ON INDEX PERSON AND CONTACT STRUCTURES
        # sample household members based on contact structure
        contacts = DataFrame(CSV.File(dirname(dirname(pathof(GEMS))) * "/data/contact_matrix_data_home.csv")) |>
            x -> reshape(x.contacts, (17, 17))

        # weight contact matrix by size of age groups
        for i in 1:dim(contacts)
            contacts[:,i] = contacts[:,i] .* weighted_groups.weight
        end

        # normalize contacts column-wise
        for i in 1:dim(contacts)
            contacts[:,i] = contacts[:,i] ./ sum(contacts[:,i])
        end

        for i in (n_households+1):nrow(df)
            # sample household to place individual into
            hh_id = gems_rand(rng, 1:n_households)

            # store household
            df.household[i] = hh_id

            # sample age for new individual based on index individual age
            df.age[i] = df.age[hh_id] |> age_to_group |>
                x -> contacts[:,x] |>
                x -> gems_rand(rng, Categorical(x)) |> group_to_age
        end

        # number of people
        isstudent(age) = 6 <= age <= 16
        isworker(age) = 17 <= age <= 67
        n_students = count(isstudent, df.age)
        n_workers = count(isworker, df.age)

        # number of other settings
        n_schools = Int64(ceil(n_students / avg_school_size))
        n_offices = Int64(ceil(n_workers / avg_office_size))

        # assign other settings
        # create set of thread-safe RNGs, seeded from the main RNG
        thread_rngs = [Xoshiro(gems_rand(rng, UInt64)) for _ in 1:Threads.maxthreadid()]
        Threads.@threads :static for i in 1:nrow(df)
            local_rng = thread_rngs[Threads.threadid()]
            isstudent(df.age[i]) ? df.schoolclass[i] = Int32(gems_rand(local_rng, 1:n_schools)) : nothing
            isworker(df.age[i]) ? df.office[i] = Int32(gems_rand(local_rng, 1:n_offices)) : nothing
        end

        # make sure all IDs start at 1 and are consecutive
        unique_off_ids = unique(df.office) |> x -> x[x .> 0] |> sort
        unique_sch_ids = unique(df.schoolclass) |> x -> x[x .> 0] |> sort

        off_join = DataFrame(
            office = unique_off_ids,
            new_office = 1:length(unique_off_ids))
        
        sch_join = DataFrame(
            schoolclass = unique_sch_ids,
            new_schoolclass = 1:length(unique_sch_ids))

        # make sure -1 is still mapped to -1
        push!(off_join, (-1, -1))
        push!(sch_join, (-1, -1))

        df = df |>
            x -> leftjoin(x, off_join, on = :office) |>
            x -> leftjoin(x, sch_join, on = :schoolclass) |>
            x -> DataFrames.select(x, Not(:office, :schoolclass)) |>
            x -> rename(x, :new_office => :office, :new_schoolclass => :schoolclass)

        # build population from dataframe
        pop = Population(df)
        pop.params["n"] = n
        pop.params["avg_household_size"] = avg_household_size
        pop.params["avg_office_size"] = avg_office_size
        pop.params["avg_school_size"] = avg_school_size

        return pop
    end
end

"""
    count(f, population::Population)

Counts the occurences where the boolean expression `f`
returns true when applied to an individual in the population.

# Example
`count(x -> age(x) < 20, pop)` returns the number of individuals
in the population model `pop` who are younger than 20 years.
"""
Base.count(f, population::Population) = count(f, population |> individuals)

"""
    each!(f, population::Population)

Applies function `f` to all individuals in the population.

# Example
`each!(i -> i.age = i.age + 1, pop)` lets all individuals
in the populaiton `pop` age by one year.
"""
each!(f, population::Population) = for i in population |> individuals f(i) end

"""
    first(population::Population)

Returns the first individual of the internal vector.
"""
Base.first(population::Population) = population |> individuals |> first


### INTERFACE
"""
    add!(population::Population, individual::Individual)

Appends specified individual to a population.
"""
function add!(population::Population, individual::Individual)
    push!(population.individuals, individual)
end

"""
    remove!(population::Population, individual::Individual)

Remove a specified individual from a population.
"""
function remove!(population::Population, individual::Individual)
    setdiff!(population.individuals, [individual])
end

"""
    individuals(population::Population)

Return the individuals associated with the population.
"""
function individuals(population::Population)::Vector{Individual}
    population.individuals
end


"""
    maxage(population::Population)

Returns the maximum age of any individual in the population
"""
function maxage(population::Population)
    if population.maxage >= 0
        return(population.maxage)
    end

    mx = Int8(-1)
    for i in population |> individuals
        if age(i) > mx
            mx = age(i)
        end
    end

    population.maxage = mx
    return(mx)
end


"""
    populationfile(population::Population)

Returns the population file that was used to generate this population.
"""
function populationfile(population::Population)
    return(population.params["populationfile"])
end

"""
    params(population::Population)

Returns the parameters that were used to generate this population.
"""
function params(population::Population)
    return(population.params)
end

"""
    num_of_infected(individuals::Vector{Individual})

Takes a vector of individuals and returns the number of infected individuals.
"""
function num_of_infected(individuals::Vector{Individual})
    return(map(x -> infected(x), individuals) |> sum)
end

"""
    num_of_infected(population::Population)

Returns the number of infected individuals in a given population.
"""
function num_of_infected(population::Population)
    return num_of_infected(population |> individuals)
end


"""
    issubset(individuals_a::Vector{Individual}, individuals_b::Vector{Individual})

Checks whether a vector of individuals A is a subset of individuals B based on the individual's IDs.
Does only work if all individuals have unique IDs.
"""
function Base.issubset(individuals_a::Vector{Individual}, individuals_b::Vector{Individual})
    return(
        Base.issubset(
            map(x -> id(x), individuals_a) |> sort,
            map(x -> id(x), individuals_b) |> sort
        )
    )
end


"""
    size(population::Population)

Returns the number of individuals in a given population.
"""
function Base.size(population::Population)::Int64
    return length(population.individuals)
end


"""
    dataframe(population::Population)

Returns a DataFrame representing the given population.

# Returns

- `DataFrame` with the following columns:

| Name         | Type    | Description                       |
| :----------- | :------ | :-------------------------------- |
| `id`         | `Int32` | Individual id                     |
| `sex`        | `Int8`  | Individual sex                    |
| `age`        | `Int8`  | Individual age                    |
| `education`  | `Int8`  | Individual education level        |
| `occupation` | `Int16` | Individual occupation group       |
| `household`  | `Int32` | Individual associated household   |
| `office`     | `Int32` | Individual associated office      |
| `school`     | `Int32` | Individual associated school      |
"""
function dataframe(population::Population)

    return(
        DataFrame(
            id = map(id, population |> individuals),
            sex = map(sex, population |> individuals),
            age = map(age, population |> individuals),
            number_of_vaccinations = map(number_of_vaccinations, population |> individuals),
            vaccination_tick = map(vaccination_tick, population |> individuals),
            education = map(education, population |> individuals),
            occupation = map(occupation, population |> individuals),
            household = map(household_id, population |> individuals),
            office = map(office_id, population |> individuals),
            schoolclass = map(class_id, population |> individuals)
        )
    )
end

"""
    save(population::Population, path::AbstractString)

Saves the given population as a CSV-file at `path`.
"""
function save(population::Population, path::AbstractString)
    CSV.write(path, dataframe(population))
end


"""
    get_individual_by_id(population::Population, ind::Int32)

Returns an individual contained in the `Population` selected by its `id`.

"""
function get_individual_by_id(population::Population, ind::Int32)
    # compute index with offset
    idx = ind - population.minid + 1
    
    if 1 <= idx <= length(population.individuals)
        @inbounds return population.individuals[idx]
    end
    
    return nothing
end


###
### PRINTING
###

function Base.show(io::IO, pop::Population)

    println(io, "Population(n = $(size(pop)))")
        
end