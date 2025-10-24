export group_by_age, aggregate_populationDF_by_age, individuals_per_age_group
export mean_contacts_per_age_group, weighted_error_sum


"""
    group_by_age(df::DataFrame)
    
Groups a dataframe by its "age" column. The column "sum" contains the sum of each individual in this age.
This also adds rows for each age from 0 till the maximum age in the "age" column.

# Returns
- returns a DataFrame with an additional column "sum". This column contains the count of the age in the DataFrame.
"""
function group_by_age(df::DataFrame)::DataFrame
    if (!("age" in names(df)))
        throw(ArgumentError("$(df) has to contain a column 'age'!"))
    end

    df = transform(df, :age => ByRow(x -> div(x, 365)) => :age)

    max_age_in_df = maximum(df[:, :age])

    # Set up dataframe with one column: Age = [0,maxage]
    #= join with sum of ages of the "df" to also get sums for ages that aren't represented in 
    the population (these ages should have the sum "0") =#
    sum_of_ages_df = DataFrame(age = 0:max_age_in_df) |>
        #= join the "df" with the newly created DataFrame to get new rows with age = 0.0, when this age 
        isn't represented in the population =#
        x -> leftjoin(x,
            # split df by age and combine each row to get the sum of individuals per age
            df |>
                y -> groupby(y, :age) |>
                y -> combine(y, nrow => :sum),
            on = :age) |>
        # return DataFrame with columns "age" and "sum", while also changing missing values to "0.0"
        x -> DataFrames.select(x, :age, :sum => ByRow(x -> coalesce(x, 0.0)) => :sum) |>
            # sort Dataframe by age (ascending)
            y -> sort!(y, [:age])

    return sum_of_ages_df
end



"""
    aggregate_populationDF_by_age(population_df::DataFrame, interval_steps::Int64)::Matrix

Helper function (it's not intended for direct use, its's rather called by other functions), to aggregate a populationDF by age. `interval_steps` describes the size of each age group to aggregate. 
The aggregated populationDF will be returned as a `Matrix`.

"""
function aggregate_populationDF_by_age(population_df::DataFrame, interval_steps::Int64)::Matrix

    if (!("age" in names(population_df)))
        throw(ArgumentError("the population_df has to contain a column 'age'!"))
    end

    sum_of_ages_df = group_by_age(population_df)
    
    aggregated_population_matrix = aggregate_matrix(sum_of_ages_df[:, :sum], interval_steps)
    
   return aggregated_population_matrix
    
end

"""
    aggregate_populationDF_by_age(population_df::DataFrame, interval_steps::Int64, max_age::Int64)::Vector

Helper function (it's not intended for direct use, its's rather called by other functions, to aggregate a populationDF by age. `interval_steps` describes the size of each age group to aggregate. 
`max_age` sets a maximum age until which the matrix should be aggregated.

# Returns

The aggregated populationDF will be returned as a `Matrix`.
"""
function aggregate_populationDF_by_age(population_df::DataFrame, interval_steps::Int64, max_age::Int64)::Matrix

    if (!("age" in names(population_df)))
        throw(ArgumentError("the population_df has to contain a column 'age'!"))
    end

    max_age_in_population = maximum(population_df[:, :age])

    # Set up dataframe with one column: Age = [0,maxage]
    #= join with sum of ages of the "population_df" to also get sums for ages that aren't represented in 
    the population (these ages should have the sum "0") =#
    sum_of_ages_df = DataFrame(age = 0:max_age_in_population) |>
        #= join the "population_df" with the newly created DataFrame to get new rows with age = 0.0, when this age 
        isn't represented in the population =#
        x -> leftjoin(x,
            # split population_df by age and combine each row to get the sum of individuals per age
            population_df |>
                y -> groupby(y, :age) |>
                y -> combine(y, nrow => :sum),
            on = :age) |>
        # return DataFrame with columns "age" and "sum", while also changing missing values to "0.0"
        x -> DataFrames.select(x, :age, :sum => ByRow(x -> coalesce(x, 0.0)) => :sum) |>
            # sort Dataframe by age (ascending)
            y -> sort!(y, [:age])
    
    aggregated_population_matrix = aggregate_matrix(sum_of_ages_df[:, :sum], interval_steps, max_age)
    
   return aggregated_population_matrix
    
end


"""
    individuals_per_age_group(post_processor::PostProcessor, interval_steps::Int64)


The population in `populationDF` will be splitted in age groups of size `interval_steps` and the number of individuals per age group is counted.

The input DataFrame already needs a column called "sum" where the sum of individuals in this age is stored.

# Returns
- returns a DataFrame with the follwing structure:

| Name             | Type     | Description                                    |
| :--------------- | :------  | :--------------------------------------------- |
| `age_group`      | `String` | Min and Max age in this age group              |
| `num_individuals`| `Int64`  | Total number of individuals                    |
"""
function individuals_per_age_group(post_processor::PostProcessor, interval_steps::Int64)::DataFrame

    population_df = populationDF(post_processor)

    grouped_df = group_by_age(population_df)

    if (!("sum" in names(grouped_df)))
        throw(ArgumentError("$(population_df) has to contain a column 'sum'!"))
    end

    age_groups = ["[$(i * interval_steps):$((i + 1) * interval_steps))" for i in 0:(ceil(Int,maximum(grouped_df[:,:age])/interval_steps)) - 2]

    last_age_group = "$((ceil(Int,maximum(grouped_df[:,:age])/interval_steps) - 1)  * interval_steps)+"

    push!(age_groups, last_age_group)

    num_individuals_per_age_group = aggregate_matrix(grouped_df[:,:sum], interval_steps)

    # create new df for output
    output_df::DataFrame = DataFrame(age_groups = age_groups, num_individuals = vec(num_individuals_per_age_group))

    return output_df

end

"""
    individuals_per_age_group(post_processor::PostProcessor, interval_steps::Int64, aggregation_bound::Int64)

The the population in `populationDF` will be splitted in age groups of size `interval_steps` and the number of individuals per age group is counted. The splitting is capped at `aggregation_bound`.


The input DataFrame already needs a column called "sum" where the sum of individuals in this age is stored.

# Returns
- returns a DataFrame with the follwing structure:

| Name             | Type     | Description                                    |
| :--------------- | :------  | :--------------------------------------------- |
| `age_group`      | `String` | Min and Max age in this age group              |
| `num_individuals`| `Int64`  | Total number of individuals                    |
"""
function individuals_per_age_group(post_processor::PostProcessor, interval_steps::Int64, aggregation_bound::Int64)::DataFrame

    if (interval_steps <= 1)
        throw(ArgumentError("interval steps have to be at least 2 or greater!"))
    end
    
    if (aggregation_bound <= 1)
        throw(ArgumentError("aggregation bound has to be at least 2 or greater!"))
    end

    if (aggregation_bound < interval_steps)
        throw(ArgumentError("aggregation bound has to be greater or equal to interval steps!"))
    end

    if ((aggregation_bound % interval_steps) != 0)
        throw(ArgumentError("interval steps have to be a multiple of aggregation bound!"))
    end

    population_df = populationDF(post_processor)

    grouped_df = group_by_age(population_df)

    if (!("sum" in names(grouped_df)))
        throw(ArgumentError("$(grouped_df) has to contain a column 'sum'!"))
    end

    age_groups = ["[$(i * interval_steps):$((i + 1) * interval_steps))" for i in 0:(round(Int,aggregation_bound/interval_steps)) - 1]

    last_age_group = "$aggregation_bound+"

    push!(age_groups, last_age_group)

    num_individuals_per_age_group = aggregate_matrix(grouped_df[:,:sum], interval_steps, aggregation_bound)

    # create new df for output
    output_df::DataFrame = DataFrame(age_groups = age_groups, num_individuals = vec(num_individuals_per_age_group))

    return output_df

end


"""
    mean_contacts_per_age_group(post_processor::PostProcessor, settingtype::DataType, interval_steps::Int64)::ContactMatrix{Float64}

Calculates the mean number of contacts between two age groups. The age gropus are defined by the size of `interval_steps`.
The population data is accessed via the postProcessor object to get the number of individuals per age group.

# Returns
Returns a ContactMatrix object containing the calculated mean contacts per age group and the interval steps.
"""
function mean_contacts_per_age_group(post_processor::PostProcessor, settingtype::DataType, interval_steps::Int64)::ContactMatrix{Float64}
    
    # contact matrix data calculated from the simulation at the last step
    simulation_contact_matrix_data = setting_age_contacts(post_processor, settingtype)

    if size(simulation_contact_matrix_data) == (1,1)
        return contact_matrix
    end

    aggregated_simulation_contact_matrix_data = aggregate_matrix(simulation_contact_matrix_data, interval_steps)

    population_df = populationDF(post_processor)

    aggregated_population = aggregate_populationDF_by_age(population_df, interval_steps)

    mean_contacts_per_age_group_data = zeros(Float64, length(aggregated_population), length(aggregated_population))

    # divide each cell by the number of individuals in a age group
    for i in 1:length(aggregated_population)
        # if either the contact age group or the ego age group has no individuals, the mean number of contacts should be 0
        if (aggregated_population[i] != 0)
            mean_contacts_per_age_group_data[i,:] = aggregated_simulation_contact_matrix_data[i,:] ./ aggregated_population[i]
        else
            mean_contacts_per_age_group_data[i,:] .= 0
        end

        # mean_contacts_per_age_group_data[i,:] = (aggregated_population[i] != 0) ? aggregated_simulation_contact_matrix_data[i,:] ./ aggregated_population[i] : 0
    end

    # wrap data and parameters of the contact matrix in a ContactMatrix object
    contact_matrix = ContactMatrix{Float64}(mean_contacts_per_age_group_data, interval_steps)

    return contact_matrix
end

"""
    mean_contacts_per_age_group(post_processor::PostProcessor, settingtype::DataType, interval_steps::Int64, max_age::Int64)::ContactMatrix{Float64}

Calculates the mean number of contacts between two age groups. The age gropus are defined by the size of `interval_steps`.
The population data is accessed via the postProcessor object to get the number of individuals per age group.

`max_age` sets a maximum age until which the matrix should be aggregated.

# Returns
Returns a ContactMatrix object containing the calculated mean contacts per age group and the interval steps and max age for aggregation.
"""
function mean_contacts_per_age_group(post_processor::PostProcessor, settingtype::DataType, interval_steps::Int64, max_age::Int64)::ContactMatrix{Float64}
    
    if (max_age <= 1)
        throw(ArgumentError("max age has to be at least 2 or greater!"))
    end

    # contact matrix data calculated from the simulation at the last step
    simulation_contact_matrix_data = setting_age_contacts(post_processor, settingtype)

    aggregated_simulation_contact_matrix_data = aggregate_matrix(simulation_contact_matrix_data, interval_steps, max_age)

    population_df = populationDF(post_processor)

    aggregated_population = aggregate_populationDF_by_age(population_df, interval_steps, max_age)

    mean_contacts_per_age_group_data = zeros(Float64, length(aggregated_population), length(aggregated_population))

    # divide each cell by the number of individuals in a age group
    for i in 1:length(aggregated_population)
        # if either the contact age group or the ego age group has no individuals, the mean number of contacts should be 0
        mean_contacts_per_age_group_data[i,:] = (aggregated_population[i] != 0) ? aggregated_simulation_contact_matrix_data[i,:] ./ aggregated_population[i] : 0
    end

    # wrap data and parameters of the contact matrix in a ContactMatrix object
    contact_matrix = ContactMatrix{Float64}(mean_contacts_per_age_group_data, interval_steps, max_age)

    return contact_matrix
end

"""
    weighted_error_sum(post_processor::PostProcessor, error_matrix::ContactMatrix{T})::T where T <: Number

Calculate a weighted error sum for the given contact matrix. Each cell will be multiplied by the number of individuals in the corresponding age group and then divided by the number of individuals in the whole population.

    weighted_error_sum = (cell value * individuals per age group) / population size)

To calculate the weighted sum, "weighted arithmetic mean" is used.

# Assumptions

- `error_matrix` Matrix contains error values between two contact matrices.

"""
function weighted_error_sum(post_processor::PostProcessor, error_matrix::ContactMatrix{T})::T where T <: Number

    interval_steps::Int64 = error_matrix.interval_steps
    aggregation_bound::Int64 = error_matrix.aggregation_bound

    # get number of individuals per age group 
    indv_per_age_group::DataFrame = individuals_per_age_group(post_processor, interval_steps, aggregation_bound)

    population_size::Int64 = Base.sum(indv_per_age_group[:,:num_individuals])

    matrix_size::Int64 = size(error_matrix.data)[1]

    sum::T = 0

    for i in 1:matrix_size
        # j is the index for the ego age groups
        for j in 1:matrix_size
            # calculate weighted arithmetic mean per cell
            sum += (error_matrix.data[i,j] * indv_per_age_group[j,:num_individuals]) / population_size
        end
    end

    return sum
end

"""
    weighted_error_sum(post_processor::PostProcessor, setting::DataType, reference_matrix::ContactMatrix{T}; fit_to_reference_matrix::Bool)::T where T <: Number

Calculate a "weighted error sum" for a setting specific contact matrix compared to a `reference_matrix`. The `post_processor` is used to calculate a contact matrix for the associated simulation that will then be fitted by a factor `alpha` calculated from the differences between the simulation contact matrix and the `reference_matrix`. 
    
Compared to `weighted_error_sum(post_processor::PostProcessor, error_matrix::ContactMatrix{T})::T where T <: Number` the `error_matrix` first needs to be calculated using the `post_processor` and the `reference_matrix`.
    
Each cell of the calculated error matrix will be multiplied by the number of individuals in the corresponding age group and then divided by the number of individuals in the whole population of the simulation.

    weighted_error_sum = (cell value * individuals per age group) / population size)

To calculate the weighted sum, "weighted arithmetic mean" is used.

# Parameters

- `post_processor::PostProcessor`: `PostProcessor` object containing the simulation and population data
- `setting::DataType`: Settingtype of the `reference_matrix` (i.e. Household)
- `reference_matrix::ContactMatrix{T}`: Matrix containing mean number of contacts per age group between individuals of one settingtype.
- `fit_to_reference_matrix::Bool`: Flag, indicating if the matrix calculated from the simulation should be fitted to the 'reference_matrix`.


# Assumptions

- `reference_matrix` logically stems from the same setting as `setting`!

"""
function weighted_error_sum(post_processor::PostProcessor, setting::DataType, reference_matrix::ContactMatrix{T}; fit_to_reference_matrix::Bool)::T where T <: Number

    # calculate contact matrix for the given setting for the simulation based on the structure of the `reference_matrix`
    simulation_contact_matrix_data::Matrix{T} = mean_contacts_per_age_group(post_processor, setting, reference_matrix.interval_steps, reference_matrix.aggregation_bound)

    # find alpha - a factor that defines the difference between both matrices
    alpha::T = GEMS.find_alpha(reference_matrix.data, simulation_contact_matrix_data)

    # fit contact matrix from the simulation to the reference matrix
    if fit_to_reference_matrix
        simulation_contact_matrix_data = alpha * simulation_contact_matrix_data
    end

    # calculate absolute error between both matrices
    error_matrix_data::Matrix{T} = GEMS.calculate_absolute_error(reference_matrix.data, simulation_contact_matrix_data)

    error_contact_matrix = ContactMatrix{T}(error_matrix_data, reference_matrix.interval_steps, reference_matrix.aggregation_bound)

    return weighted_error_sum(post_processor, error_contact_matrix)
end