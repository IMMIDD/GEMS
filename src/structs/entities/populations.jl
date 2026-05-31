###
### POPULATIONS (TYPE DEFINITION & BASIC FUNCTIONALITY)
###
export Population
export populationfile, params
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
mutable struct Population{E}
    individuals::Vector{Individual{E}}
    params::Dict{String, Any}
    maxage::Int8 # maximum age of any individual. Is updated upon first call of maxage function (for caching)
    minid::Int32 # smallest id of any individual. Corresponds to the offset compared to the dataset for all of germany
    id_map::Vector{Int32} # Maps (id - minid + 1) to the individual's index in the `individuals` array. Needed for O(1) lookups.
    

    @doc """
        make_id_map!(population::Population)

    Creates an `id_map` for the given Population to avoid missmatches later.
    """
    function make_id_map!(pop::Population)
        map_size = isempty(pop.individuals) ? 0 : maximum(x -> x.id, pop.individuals) - pop.minid + 1
        pop.id_map = zeros(Int32, map_size)

        for (i, ind) in enumerate(pop.individuals)
            pop.id_map[ind.id - pop.minid + 1] = i 
        end
    end
    
    @doc """
        Population(individuals::Vector{Individual})

    Creates a `Population` object from a vector of `Individual`s.
    """
    function Population(individuals::Vector{Individual{E}}) where {E}
        # Create the Population object
        pop = new{E}(individuals, Dict("populationfile" => "Not available."), -1, -1, Int32[])
        maxage(pop)
        pop.minid = isempty(individuals) ? -1 : minimum(x -> x.id, individuals)
        make_id_map!(pop)
        return pop
    end

    
    @doc """
        Population(df::DataFrame)

    Creates a `Population` object from a `DataFrame` where each row corresponds to one individual.
    The dataframe column names must correspond to the fieldnames of the `Individual` struct.
    `id` (Int32), `age` (Int8), and `sex` (Int8) are required columns. Everything else is optional. 
    """
    function Population(df::DataFrame; ind_extension = nothing)

        # Intersect DataFrame columns with base Individual field names
        base_cols = Tuple(intersect(individual_base_fieldnames(), propertynames(df)))
        base_data = NamedTuple{base_cols}(Tuple(df[!, c] for c in base_cols))
        # Check for extra columns not belonging to the base Individual fields
        extra_cols = Tuple(c for c in propertynames(df) if c ∉ Set(individual_base_fieldnames()))

        # Dispatch to the appropriate builder based on the extension mode
        inds = if ind_extension isa DataFrame
            pop_ids = [Int32(df[i, :id]) for i in 1:nrow(df)]
            _build_individuals_from_ext_df(base_data, pop_ids, ind_extension, nrow(df))
        elseif !isnothing(ind_extension)
            _build_individuals_with_factory(base_data, nrow(df), ind_extension)
        elseif !isempty(extra_cols)
            _build_individuals_auto_extension(base_data, df, extra_cols, nrow(df))
        else
            _build_individuals(base_data, nrow(df))
        end

        pop = Population(inds)
        pop.params["populationfile"] = "Not available."
        return(pop)
    end


    @doc """
        Population(path::String)

    Creates a `Population` object from a CSV- or JLD2 file (path).
    """
    function Population(path::String; ind_extension = nothing)
        file_ext = split(path, ".")[end]

        if file_ext == "csv"
            printinfo("\u2514 Loading population data from $(basename(path))")
            # read dataframe from CSV and pass it to df constructor
            pop = Population(CSV.File(path) |> DataFrame; ind_extension = ind_extension)

        elseif file_ext == "jld2"
            printinfo("\u2514 Loading population data from $(basename(path))")
            # read dataframe from JLD2 object ("data"-field) and pass it to df constructor
            pop = Population(load(path, "data"); ind_extension = ind_extension)

        else
            error("File Extension .$file_ext is not supported")
        end

        pop.params["populationfile"] = path
        pop.minid = isempty(individuals(pop)) ? -1 : minimum(x -> x.id, individuals(pop))

        make_id_map!(pop)
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
        rng::Xoshiro = default_gems_rng(),
        empty::Bool = false,
        ind_extension = nothing)

        # if "empty" keyword is passed, generate an empty population object
        if empty
            return new{Nothing}(Individual{Nothing}[], Dict("populationfile" => "Not available."), -1, -1, Int32[])
        end

        # exception handling
        n <= 0 ? throw(ArgumentError("The number of individuals must be a positive integer")) : nothing
        avg_household_size <= 0 ? throw(ArgumentError("The average household size must be a positive number")) : nothing
        avg_household_size > n ? throw(ArgumentError("The average household size cannot be larger than the population (n)")) : nothing
        avg_office_size <= 0 ? throw(ArgumentError("The average office size must be a positive number")) : nothing
        avg_office_size > n ? throw(ArgumentError("The average office size cannot be larger than the population (n)")) : nothing
        avg_school_size <= 0 ? throw(ArgumentError("The average school size must be a positive number")) : nothing
        avg_school_size > n ? throw(ArgumentError("The average school size cannot be larger than the population (n)")) : nothing

        # load raw contact matrix to determine the number of age groups dynamically
        contacts_raw = DataFrame(CSV.File(dirname(dirname(pathof(GEMS))) * "/data/contact_matrix_data_home.csv"))
        n_age_groups = Int(sqrt(nrow(contacts_raw)))

        # reshape into the correct matrix size, explicitly casting to Float64 for type stability
        contacts = reshape(Vector{Float64}(contacts_raw.contacts), (n_age_groups, n_age_groups))

        # helper functions
        group_to_age(g) = 5 * (g-1) + gems_rand(rng, 0:4)
        age_to_group(a) = min(n_age_groups, (a ÷ 5) + 1)

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

        # preallocate RAW ARRAYS to guarantee type stability in loops
        id_col = Int32.(1:n)
        sex_col = Int8.(gems_rand(rng, 1:2, n))
        
        age_col = fill(Int8(-1), n)
        age_col[1:n_households] .= Int8.(gems_rand(rng, Categorical(weights), n_households))

        hh_col = fill(Int32(-1), n)
        hh_col[1:n_households] .= Int32.(1:n_households)
        
        sch_col = fill(Int32(-1), n)
        off_col = fill(Int32(-1), n)

        # ASSIGN INDIVIDUALS TO HOUSEHOLDS BASED ON INDEX PERSON AND CONTACT STRUCTURES
        # weight contact matrix by size of age groups
        for col in axes(contacts, 2)
            contacts[:, col] = contacts[:, col] .* weighted_groups.weight
        end

        # normalize contacts column-wise
        for col in axes(contacts, 2)
            contacts[:, col] = contacts[:, col] ./ sum(contacts[:, col])
        end

        # pre-calculate categorical distributions for age groups
        contact_dists = [Categorical(Vector(contacts[:, i])) for i in axes(contacts, 2)]

        # iterate using the strongly-typed raw arrays instead of DataFrame columns
        for i in (n_households+1):n
            # sample household to place individual into
            hh_id = gems_rand(rng, 1:n_households)

            # store household
            hh_col[i] = hh_id

            # sample age for new individual based on index individual age
            group_idx = age_to_group(age_col[hh_id])
            age_col[i] = group_to_age(gems_rand(rng, contact_dists[group_idx]))
        end

        # number of people
        isstudent(age) = 6 <= age <= 16
        isworker(age) = 17 <= age <= 67
        n_students = count(isstudent, age_col)
        n_workers = count(isworker, age_col)

        # number of other settings
        n_schools = Int64(ceil(n_students / avg_school_size))
        n_offices = Int64(ceil(n_workers / avg_office_size))

        # assign other settings using raw arrays
        # create set of thread-safe RNGs, seeded from the main RNG
        thread_rngs = [Xoshiro(gems_rand(rng, UInt64)) for _ in 1:Threads.maxthreadid()]
        Threads.@threads :static for i in 1:n
            local_rng = thread_rngs[Threads.threadid()]
            isstudent(age_col[i]) ? sch_col[i] = Int32(gems_rand(local_rng, 1:n_schools)) : nothing
            isworker(age_col[i]) ? off_col[i] = Int32(gems_rand(local_rng, 1:n_offices)) : nothing
        end

        # make sure all IDs start at 1 and are consecutive
        unique_off_ids = unique(off_col) |> x -> x[x .> 0] |> sort
        unique_sch_ids = unique(sch_col) |> x -> x[x .> 0] |> sort

        # create dictionary maps
        off_dict = Dict{Int32, Int32}(id => Int32(i) for (i, id) in enumerate(unique_off_ids))
        off_dict[Int32(-1)] = Int32(-1)
        
        sch_dict = Dict{Int32, Int32}(id => Int32(i) for (i, id) in enumerate(unique_sch_ids))
        sch_dict[Int32(-1)] = Int32(-1)

        # map IDs using dictionaries
        off_col .= getindex.(Ref(off_dict), off_col)
        sch_col .= getindex.(Ref(sch_dict), sch_col)

        # construct the dataframe once all data operations are perfectly complete
        df = DataFrame(
            id = id_col,
            age = age_col,
            sex = sex_col,
            household = hh_col,
            schoolclass = sch_col,
            office = off_col
        )

        # build population from dataframe
        pop = Population(df; ind_extension = ind_extension)
        pop.params["n"] = n
        pop.params["avg_household_size"] = avg_household_size
        pop.params["avg_office_size"] = avg_office_size
        pop.params["avg_school_size"] = avg_school_size

        make_id_map!(pop)
        return pop
    end
end

# Backward-compat outer constructor: accepts Vector{<:Individual} where the element type
# may be the abstract UnionAll Individual (e.g., from Individual[] in tests or user code).
# Infers the concrete extension type from the first element; defaults to Nothing for empty vectors.
function Population(individuals::Vector{<:Individual})
    isempty(individuals) && return Population(Individual{Nothing}[])
    T = typeof(first(individuals))
    return Population(Vector{T}(individuals))
end

###
### INDIVIDUAL BUILDER HELPERS
###

"""
    _build_individuals(base_data, n)

Creates `n` baseline `Individual{Nothing}` instances in parallel from the provided column data.
"""
function _build_individuals(base_data, n)
    inds = Vector{Individual{Nothing}}(undef, n)
    Threads.@threads for i in eachindex(inds)
        @inbounds inds[i] = Individual(; map(col -> col[i], base_data)...)
    end
    return(inds)
end

"""
    _build_individuals_auto_extension(base_data, df, extra_cols, n)

Creates `n` `Individual{AutoExtension{NT}}` instances in parallel, where `NT` is a NamedTuple
inferred from the extra DataFrame columns not present in the base `Individual` field set.
"""
function _build_individuals_auto_extension(base_data, df, extra_cols, n)
    ext_data = NamedTuple{extra_cols}(Tuple(df[!, c] for c in extra_cols))
    # Infer E from the first row to pre-allocate the typed vector
    E = AutoExtension{typeof(NamedTuple{extra_cols}(map(col -> col[1], ext_data)))}
    inds = Vector{Individual{E}}(undef, n)
    Threads.@threads for i in eachindex(inds)
        ext = E(NamedTuple{extra_cols}(map(col -> col[i], ext_data)))
        @inbounds inds[i] = Individual{E}(; map(col -> col[i], base_data)..., extensions = ext)
    end
    return(inds)
end

"""
    _build_individuals_with_factory(base_data, n, extension)

Creates `n` `Individual{E}` instances in parallel using `extension(ind)` to produce each
individual's extension value. `E` is inferred from the first factory call.
"""
function _build_individuals_with_factory(base_data, n, extension::F) where {F}
    # Determine E by applying the factory to a temporary baseline individual
    E = typeof(extension(Individual(; map(col -> col[1], base_data)...)))
    inds = Vector{Individual{E}}(undef, n)
    Threads.@threads for i in eachindex(inds)
        kw = map(col -> col[i], base_data)
        @inbounds inds[i] = Individual{E}(; kw..., extensions = extension(Individual(; kw...)))
    end
    return(inds)
end

"""
    _build_individuals_from_ext_df(base_data, pop_ids, ext_df, n)

Creates `n` `Individual{AutoExtension{NT}}` instances by joining `ext_df` to the
population by `id`. Missing individuals receive zero-filled extension values; a
warning is issued if any IDs are absent from the extension DataFrame.
"""
function _build_individuals_from_ext_df(base_data, pop_ids, ext_df, n)
    ext_cols = Tuple(c for c in propertynames(ext_df) if c !== :id)
    id_to_row = Dict{Int32, Int}(Int32(ext_df[i, :id]) => i for i in 1:nrow(ext_df))

    # Infer E from first matched row (fall back to zeros if the first ID is missing)
    first_idx = get(id_to_row, pop_ids[1], nothing)
    first_nt = isnothing(first_idx) ?
        NamedTuple{ext_cols}(map(c -> zero(eltype(ext_df[!, c])), ext_cols)) :
        NamedTuple{ext_cols}(map(c -> ext_df[first_idx, c], ext_cols))
    E = AutoExtension{typeof(first_nt)}

    # Warn once if any population IDs are absent from the extension DataFrame
    missing_ids = [id for id in pop_ids if !haskey(id_to_row, id)]
    if !isempty(missing_ids)
        @warn "$(length(missing_ids)) individual(s) not found in ind_extension DataFrame; extension fields filled with zero."
    end

    inds = Vector{Individual{E}}(undef, n)
    Threads.@threads for i in eachindex(inds)
        row_idx = get(id_to_row, pop_ids[i], nothing)
        nt = isnothing(row_idx) ?
            NamedTuple{ext_cols}(map(c -> zero(eltype(ext_df[!, c])), ext_cols)) :
            NamedTuple{ext_cols}(map(c -> ext_df[row_idx, c], ext_cols))
        base_kw = map(col -> col[i], base_data)
        @inbounds inds[i] = Individual{E}(; base_kw..., extensions = E(nt))
    end
    return(inds)
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
function individuals(population::Population{E}) where {E}
    population.individuals
end


"""
    maxage(population::Population)

Returns the maximum age of any individual in the population
"""
function maxage(population::Population)::Int8
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
function num_of_infected(individuals::Vector{<:Individual})
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
function Base.issubset(individuals_a::Vector{<:Individual}, individuals_b::Vector{<:Individual})
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
    
    if 1 <= idx <= length(population.id_map)
        arr_idx = population.id_map[idx]
        if arr_idx > 0
            @inbounds return population.individuals[arr_idx]
        end
    end
    
    return nothing
end


###
### PRINTING
###

function Base.show(io::IO, pop::Population)

    println(io, "Population(n = $(size(pop)))")
        
end