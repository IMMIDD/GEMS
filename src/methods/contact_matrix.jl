# export get_contacts

# """
#     get_contacts(contact_matrix::ContactMatrix{T}, individual::Individual)::T where T <: Number

# Get the number of contacts an Individual has, based on its age and an associated contact matrix containing the numbers of contacts per age group.

# The number of contacts is based on a vector of contacts an individual of the age group of individual would have. The concrete number of contacts is then derived by taking the mean of this vector.
# """
# function get_contacts(contact_matrix::ContactMatrix{T}, individual::Individual)::T where T <: Number

#     # get age of Individual
#     age::Int8 = GEMS.age(individual)

#     # get interval steps
#     interval_steps::Int64 = contact_matrix.interval_steps

#     # get raw data
#     data::Matrix{T} = contact_matrix.data

#     #= the column index, is the index of "get_data(contact_matrix)" for the age group that "individual" is part of.
    
#     Example: "contact_matrix" is aggregated by interval_steps = 10 and "individual" is age 12, then the vector of all numbers of contact is at "get_data(contact_matrix)[:,2]".
    
#     (
#         div(12,10) = 1 
#         1 + 1 = 2
#     )
#     =#
#     column_index::Int64 = div(age,interval_steps) + 1

#     # vector of contacts between the ego ("individual") and a contact person (1 per age group)
#     ego_age_group_contacts::Vector{T} = data[:, column_index]

#     # get mean of all contacts an individual of the age group of "individual" would have
#     n_contacts::T = mean(ego_age_group_contacts)

#     return n_contacts
# end