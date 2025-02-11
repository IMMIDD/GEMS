# Contacts
contact sampling

## Overview Structs
```@index
Pages   = ["api_contacts.md"]
Order   = [:type]
```

## Overview Functions
```@index
Pages   = ["api_contacts.md"]
Order   = [:function]
```

## Structs
```@docs
AgeContactDistribution
AgeGroupContactDistribution
ContactMatrix
ContactSamplingMethod
ContactparameterSampling
RandomSampling
```

## Constructors
```@docs
AgeContactDistribution(::Vector{Int64}, ::Int8, ::Int8)
AgeGroupContactDistribution(::Vector{Int64}, ::Tuple{Int8, Int8}, ::Tuple{Int8, Int8})
```

## Functions
```@docs
aggregate_matrix
aggregate_populationDF_by_age
aggregated_setting_age_contacts
calculate_absolute_error(::Matrix{T}, ::Matrix{T}) where T <: Number
calculate_ageGroup_contact_distribution
calculate_age_contact_distribution
calculate_zero_contact_distribution
ContactMatrix{T}(::Matrix{T}, ::Int64, ::Union{Int64, Nothing}) where T <: Number
ContactMatrix{T}(::Matrix{T}, ::Int64) where T <: Number
contact_samples
get_ageGroup_contact_distribution
get_age_contact_distribution
get_age_contact_distribution_matrix
get_contacts
mean_contacts_per_age_group
sample_contacts
setting_age_contacts
```