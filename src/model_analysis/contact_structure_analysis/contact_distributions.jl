# CALCULATE CONTACT DISTRIBUTIONS BASED ON A CONTACT SURVEY CREATED IN GEMS
export AgeContactDistribution, AgeGroupContactDistribution
export get_age_contact_distribution
export get_age_contact_distribution_matrix
export get_ageGroup_contact_distribution

"""
    AgeContactDistribution

Wrapper for a 'Age x Age Contact Distribution'.

# Attributes

- `distribution_data::Vector{Int64}`: Vector containing the numbers of contacts from each individual of `ego_age` with individuals of age `contact_age`.
- `ego_age::Int8`: Age of the "Ego" individual.
- `contact_age::Int8`: Age of the "Contact" individual
"""
struct AgeContactDistribution
    distribution_data::Vector{Int64}
    ego_age::Int8
    contact_age::Int8


    @doc """
        AgeContactDistribution(distribution_data::Vector{Int64}, ego_age::Int8, contact_age::Int8)
    
    Default constructor for `AgeContactDistribution`.

    # Parameters
    - `distribution_data::Vector{Int64}`: Vector containing the numbers of contacts from each individual of `ego_age` with individuals of age `contact_age`.
    - `ego_age::Int8`: Age of the "Ego" individual.
    - `contact_age::Int8`: Age of the "Contact" individual
    """
    function AgeContactDistribution(distribution_data::Vector{Int64}, ego_age::Int8, contact_age::Int8)
        
        if ego_age < 0 
            throw(ArgumentError("'ego_age' is: $ego_age, but has to be non-negative!"))
        end

        if contact_age < 0 
            throw(ArgumentError("'contact_age' is: $contact_age, but has to be non-negative!"))
        end

        if any(x -> x < 0, distribution_data)
            throw(ArgumentError("'distribution data' is a Frequency and therefore has to be non-negative!"))
        end
        
        return new(distribution_data, ego_age, contact_age)
    end
end

"""
    AgeGroupContactDistribution

Wrapper for a 'AgeGroup x AgeGroup Contact Distribution'.

# Attributes

- `distribution_data::Vector{Int64}`: Vector containing the numbers of contacts from each individual of `ego_age_group` with individuals of `contact_age_group`.
- `ego_age_group::Tuple{Int8, Int8}`: Lower and Upper bound of the Age Group of "Ego" individuals. The upper bound is excluded (`ego_age_group=(0,5)` corresponds to the ages 0 till 4).
- `contact_age_group::Tuple{Int8, Int8}`: Lower and Upper bound of the Age Group of "Contact" individuals. The upper bound is excluded (`ego_age_group=(0,5)` corresponds to the ages 0 till 4).
"""
struct AgeGroupContactDistribution
    distribution_data::Vector{Int64}
    ego_age_group::Tuple{Int8, Int8}
    contact_age_group::Tuple{Int8, Int8}

    @doc """
        AgeGroupContactDistribution(distribution_data::Vector{Int64}, ego_age_group::Tuple{Int8, Int8}, contact_age_group::Tuple{Int8, Int8})
    
    Default constructor for `AgeGroupContactDistribution`.

    # Parameters

    - `distribution_data::Vector{Int64}`: Vector containing the numbers of contacts from each individual of `ego_age_group` with individuals of `contact_age_group`.
    - `ego_age_group::Tuple{Int8, Int8}`: Lower and Upper bound of the Age Group of "Ego" individuals. The upper bound is excluded (`ego_age_group=(0,5)` corresponds to the ages 0 till 4).
    - `contact_age_group::Tuple{Int8, Int8}`: Lower and Upper bound of the Age Group of "Contact" individuals. The upper bound is excluded (`contact_age_group=(0,5)` corresponds to the ages 0 till 4).
    """
    function AgeGroupContactDistribution(distribution_data::Vector{Int64}, ego_age_group::Tuple{Int8, Int8}, contact_age_group::Tuple{Int8, Int8})

        if ego_age_group[1] > ego_age_group[2]
            throw(ArgumentError("The 'lower bound' ($(ego_age_group[1])) of the age group needs to be lower than the 'upper bound' ($(ego_age_group[2]))"))
        end

        if contact_age_group[1] > contact_age_group[2]
            throw(ArgumentError("The 'lower bound' ($(contact_age_group[1])) of the age group needs to be lower than the 'upper bound' ($(contact_age_group[2]))"))
        end

        if any(x -> x < 0, ego_age_group)
            throw(ArgumentError("'ego_age_group' values have to be non-negative!"))
        end

        if any(x -> x < 0, contact_age_group)
            throw(ArgumentError("'contact_age_group' values have to be non-negative!"))
        end

        if any(x -> x < 0, distribution_data)
            throw(ArgumentError("'distribution data' is a Frequency and therefore has to be non-negative!"))
        end

        return new(distribution_data, ego_age_group, contact_age_group)
    end
end

"""
Utitility function.
Get how many individuals of a specific age have no contact. An Individiual with no contact, has an entry in `contactdata` where the columns for data about the contact are "-1".

# Parameters

- `contactdata`: DataFrame containing data about contacts between an 'ego' and a 'contact'.
- `ego_age`: Age of the 'Ego', that should be included in this distribution.
- `ego_id_column`: Index indicating which column of `contactdata` stores information about each ego's id.
- `ego_age_column`: Index indicating which column of `contactdata` stores information about each ego's age.
- `contact_age_column`: Index indicating which column of `contactdata` stores information about each contact's age.

"""
function calculate_zero_contact_distribution(contactdata::DataFrame; ego_age::Int64, ego_id_column::Int64, ego_age_column::Int64, contact_age_column::Int64)
    # filter DF by age of the ego
    filtered_df = filter(x -> x[ego_age_column] == ego_age, contactdata)

    # filter all individuals that have no contact
    filtered_df = filter(x -> x[contact_age_column] == -1, filtered_df)

    # group by ego id 
    grouped_df = groupby(filtered_df, ego_id_column) |> x -> combine(x, nrow)

    # replace all counts in "nrow" with a zero, to create a distribution of zero contacts. THis makes it easier to display the number of "zero contacts" in the histogram
    grouped_df.nrow .= 0

    return grouped_df.nrow
end


"""
Utitility function.
Calculates the number of contacts an individual of age `ego_age` has with an individual of age `contact_age`. Each entry is the number of contacts one individual of age `ego_age` has.

# Parameters

- `contactdata`: DataFrame containing data about contacts between an 'ego' and a 'contact'.
- `ego_age`: Age of the 'Ego', that should be included in this distribution.
- `contact_age`: Age of the 'Contact', that should be included in this distribution.  
- `ego_id_column`: Index indicating which column of `contactdata` stores information about each ego's id.
- `ego_age_column`: Index indicating which column of `contactdata` stores information about each ego's age.
- `contact_age_column`: Index indicating which column of `contactdata` stores information about each contact's age.

"""
function calculate_age_contact_distribution(contactdata::DataFrame; ego_age::Int64, contact_age::Int64, ego_id_column::Int64, ego_age_column::Int64, contact_age_column::Int64)::Vector{Int}

    # filter DF by age of the ego
    filtered_df = filter(x -> x[ego_age_column] == ego_age, contactdata)

    # filter by age of contact
    filtered_df = filter(x -> x[contact_age_column] == contact_age, filtered_df)

    # group by ego id and combine all rows (each row represents one contact)
    grouped_df = groupby(filtered_df, ego_id_column) |> x -> combine(x, nrow)

    return grouped_df.nrow
end

"""
Utitility function.
Calculates the number of contacts an individuals in the age group `ego_age_group` have with individuals in the age group `contact_age_group`. Each entry is the number of contacts one individual in the age group `ego_age_group` has with individuals in the age group `contact_age_group`.

# Parameters

- `contactdata`: DataFrame containing data about contacts between an 'ego' and a 'contact'.
- `ego_age_group::Tuple{Int,Int}`: Defines the age interval that should be aggregated for the "ego age group". The upper age bound (the second entry of the Tuple) will be excluded like "[ego_lower_bound, ego_upper_bound)"
- `contact_age_group::Tuple{Int,Int}`: Defines the age interval that should be aggregated for the "contact age group". The upper age bound (the second entry of the Tuple) will be excluded like "[contact_lower_bound, contact_upper_bound)"
- `ego_id_column`: Index indicating which column of `contactdata` stores information about each ego's id.
- `ego_age_column`: Index indicating which column of `contactdata` stores information about each ego's age.
- `contact_age_column`: Index indicating which column of `contactdata` stores information about each contact's age.

"""
function calculate_ageGroup_contact_distribution(contactdata::DataFrame; ego_age_group::Tuple{Int,Int}, contact_age_group::Tuple{Int,Int}, ego_id_column::Int64, ego_age_column::Int64, contact_age_column::Int64)

    filtered_df = DataFrame()

    # filter every ego of "ego_age_group"
    for i in (ego_age_group[1]):(ego_age_group[2]-1)
        filtered_df = vcat(filtered_df, filter(x -> x[ego_age_column] == i, contactdata))
    end

    # remove all "contacts" that aren't in the interval defined by [contact_age_group[1], contact_age_group[2])
    filtered_df = filter(x -> x[contact_age_column] >= contact_age_group[1] && x[contact_age_column] < contact_age_group[2], filtered_df)

    # # group by ego id and combine all rows (each row represents one contact)
    grouped_df = groupby(filtered_df, ego_id_column) |> x -> combine(x, nrow)

    return grouped_df.nrow
end


"""
    get_age_contact_distribution(contactdata::DataFrame; ego_age::Int64, contact_age::Int64, ego_id_column::Int64, ego_age_column::Int64, contact_age_column::Int64)::AgeContactDistribution

Calculate a 'Age x Age' contact distribution for two given ages defined by `ego_age` and `contact_age`.
The correct columns of the input dataframes can be defined by `ego_id_column`, `ego_age_column` and `contact_age_column`.

The dataframe must contain data of a (artificial) contact survey, where each row represents a contact between two individuals.

# Parameters

- `contactdata`: DataFrame containing data about contacts between an 'ego' and a 'contact'.
- `ego_age`: Age of the 'Ego', that should be included in this distribution.
- `contact_age`: Age of the 'Contact', that should be included in this distribution.  
- `ego_id_column`: Index indicating which column of `contactdata` stores information about each ego's id.
- `ego_age_column`: Index indicating which column of `contactdata` stores information about each ego's age.
- `contact_age_column`: Index indicating which column of `contactdata` stores information about each contact's age.

# Returns

A Distribution of contacts between individuals of age "Ego Age" and "Contact Age"

"""
function get_age_contact_distribution(contactdata::DataFrame; ego_age::Int64, contact_age::Int64, ego_id_column::Int64, ego_age_column::Int64, contact_age_column::Int64)::AgeContactDistribution

    contact_distribution_data = calculate_age_contact_distribution(contactdata; ego_age=ego_age, contact_age=contact_age, ego_id_column=ego_id_column, ego_age_column=ego_age_column, contact_age_column=contact_age_column)

    # calculate how many individuals of age "ego age" don't have any contacts
    zero_contact_distribution = calculate_zero_contact_distribution(contactdata; ego_age=ego_age, ego_id_column=ego_id_column, ego_age_column=ego_age_column, contact_age_column=contact_age_column)

    contact_distribution = [contact_distribution_data; zero_contact_distribution]

    age_contact_distribution::AgeContactDistribution = AgeContactDistribution(contact_distribution, Int8(ego_age), Int8(contact_age))

    return age_contact_distribution
end


"""
    get_age_contact_distribution_matrix(contactdata::DataFrame)::Matrix{AgeContactDistribution}

Create a matrix of contact distributions between individuals of two ages until a given maximum age `maxage`.

"""
function get_age_contact_distribution_matrix(contactdata::DataFrame)::Matrix{AgeContactDistribution}
    
    maxage = maximum([maximum(contactdata.a_age), maximum(contactdata.b_age)])

    @info "-> Calculating Contact Distribution Matrix for $((maxage+1) * (maxage+1)) Distributions!"

    # initialize with empty objects to allocate sequential memory
    contact_distribution_matrix::Matrix{AgeContactDistribution} = Matrix{AgeContactDistribution}(undef, maxage+1, maxage+1)

    for i in 1:(maxage+1)
        for j in 1:(maxage+1)

            # fill matrix in column-major order
            contact_distribution_matrix[j,i] = get_age_contact_distribution(contactdata, ego_age = i-1, contact_age = j-1, ego_id_column = 1, ego_age_column = 2, contact_age_column = 5)
        end
    end

    return contact_distribution_matrix
end





"""
    get_ageGroup_contact_distribution(contact_distribution_matrix::Matrix{AgeContactDistribution}; ego_age_group::Tuple{Int,Int}, contact_age_group::Tuple{Int,Int})::AgeGroupContactDistribution

Aggregates a number of 'Age x Age Contact Distribution's to one new 'AgeGroup x AgeGroup Contact Distribution'.

# Parameters

- `contact_distribution_matrix::Matrix`: Contains "Age x Age Contact Distributions".
- `ego_age_group::Tuple{Int,Int}`: Defines the age interval that should be aggregated for the "ego age group". The upper age bound (the second entry of the Tuple) will be excluded like "[`ego_lower_bound`, `ego_upper_bound`)"
- `contact_age_group::Tuple{Int,Int}`: Defines the age interval that should be aggregated for the "contact age group". The upper age bound (the second entry of the Tuple) will be excluded like "[`contact_lower_bound`, `contact_upper_bound`)"

# Returns

'AgeGroup x AgeGroup Contact Distribution'

"""
function get_ageGroup_contact_distribution(contact_distribution_matrix::Matrix{AgeContactDistribution}; ego_age_group::Tuple{Int,Int}, contact_age_group::Tuple{Int,Int})::AgeGroupContactDistribution

    ego_low::Int = ego_age_group[1]

    # the upper bound will always be excluded like [ego_low, ego_up)
    ego_up::Int = ego_age_group[2] - 1

    contact_low::Int = contact_age_group[1]
    # the upper bound will always be excluded like [contact_low_low, contact_low_up)
    contact_up::Int = contact_age_group[2] - 1

    # indices "ego_age" and "contact_age" have to be incremented as the  "0 x 0 Contact Distribution" corresponds to `contact_distribution_matrix[1,1]` 
    ageGroup_x_ageGroup_distributions_matrix::Matrix = [(contact_distribution_matrix[ego_age+1, contact_age+1]).distribution_data for ego_age in ego_low:ego_up, contact_age in contact_low:contact_up]

    # flatten matrix to a single distribution vector
    ageGroup_x_ageGroup_distribution_vector::Vector = [(ageGroup_x_ageGroup_distributions_matrix...)...]

    age_group_contact_distribution::AgeGroupContactDistribution = AgeGroupContactDistribution(ageGroup_x_ageGroup_distribution_vector, convert(Tuple{Int8, Int8}, ego_age_group), convert(Tuple{Int8, Int8}, contact_age_group))

    return age_group_contact_distribution

end


"""
    get_ageGroup_contact_distribution(contactdata::DataFrame; ego_age_group::Tuple{Int,Int}, contact_age_group::Tuple{Int,Int}, ego_id_column::Int64, ego_age_column::Int64, contact_age_column::Int64)::AgeGroupContactDistribution

Calculate a 'AgeGroup x AgeGroup' contact distribution for two given age groups defined by `ego_age_group` and `contact_age_group`.
The correct columns of the input dataframes can be defined by `ego_id_column`, `ego_age_column` and `contact_age_column`.

The dataframe must contain data of a (artificial) contact survey, where each row represents a contact between two individuals.

# Parameters

- `contactdata`: DataFrame containing data about contacts between a 'ego' and 'contacts'.
- `ego_age_group::Tuple{Int,Int}`: Defines the age interval that should be aggregated for the "ego age group". The upper age bound (the second entry of the Tuple) will be excluded like "[`ego_lower_bound`, `ego_upper_bound`)"
- `contact_age_group::Tuple{Int,Int}`: Defines the age interval that should be aggregated for the "contact age group". The upper age bound (the second entry of the Tuple) will be excluded like "[`contact_lower_bound`, `contact_upper_bound`)"
- `ego_id_column::Int64`: Index indicating which column of `contactdata` stores information about each ego's id.
- `ego_age_column::Int64`: Index indicating which column of `contactdata` stores information about each ego's age.
- `contact_age_column::Int64`: Index indicating which column of `contactdata` stores information about each contact's age.

# Returns

'AgeGroup x AgeGroup Contact Distribution'

"""
function get_ageGroup_contact_distribution(contactdata::DataFrame; ego_age_group::Tuple{Int,Int}, contact_age_group::Tuple{Int,Int}, ego_id_column::Int64, ego_age_column::Int64, contact_age_column::Int64)::AgeGroupContactDistribution

    ageGroup_x_ageGroup_distribution_vector::Vector = calculate_ageGroup_contact_distribution(contactdata; ego_age_group=ego_age_group, contact_age_group=contact_age_group, ego_id_column=ego_id_column, ego_age_column=ego_age_column, contact_age_column=contact_age_column)

    age_group_contact_distribution::AgeGroupContactDistribution = AgeGroupContactDistribution(ageGroup_x_ageGroup_distribution_vector, convert(Tuple{Int8, Int8}, ego_age_group), convert(Tuple{Int8, Int8}, contact_age_group))

    return age_group_contact_distribution

end