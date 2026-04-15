export ContactSamplingMethod
export RandomSampling
export TestSampling
export ContactparameterSampling
export AgeBasedContactSampling


"""
    ContactSamplingMethod

Supertype for all contact sampling methods. This type is intended to be extended by providing different sampling methods suitable for the structure of the simulation model.
"""
abstract type ContactSamplingMethod end

"""
    RandomSampling <: ContactSamplingMethod

Sample exactly one contact per individual inside a Setting. The sampling will be random.
"""
struct RandomSampling <: ContactSamplingMethod
    
end

#struct for testing
@with_kw struct TestSampling <: ContactSamplingMethod
    attr1::Int64 = 123
    attr2::String = "correct"
end

"""
    ContactparameterSampling <: ContactSamplingMethod

Sample random contacts based on a Poisson-Distribution spread around `contactparameter`.
If provided with no parameter, `0` contacts are assumed.
"""
struct ContactparameterSampling <: ContactSamplingMethod
    contactparameter::Float64

    function ContactparameterSampling(contactparameter::Float64)
        if contactparameter < 0
            throw(ArgumentError("'contactparameter' is $contactparameter, but the 'contactparameter' has to be non-negative!"))
        end

        return new(contactparameter)
    end
    function ContactparameterSampling(contactparameter::Int64)
        if contactparameter < 0
            throw(ArgumentError("'contactparameter' is $contactparameter, but the 'contactparameter' has to be non-negative!"))
        end

        return new(contactparameter)
    end

    ContactparameterSampling(; contactparameter = 0) = ContactparameterSampling(contactparameter)
end

# empty constructor calls constructor with 0 contacts
#ContactparameterSampling() = ContactparameterSampling(0)


"""
    AgeBasedContactSampling <: ContactSamplingMethod

Sample random contacts based on a Poissoin-Distribution spread around `contactparameter_sampling.contactparameter` with weighted sampling based on age distance.
We sample according to formula
pi = e * wi * qi * mi / N
where e - expected number of contacts, wi - normalization factor, qi - age group probability based on the age pyramid,
mi - mixing factor between age groups, N - number of agents
Normalization factor is required to normalize the sampling ditribution in order to
get expected number of contacts in the end.
We use two fold approach.
Firstly, we sample uniformly with probability pi = e * wi * qi * m_max / N
m_max - maximal mixing factor between age groups
Secondly, we sample with adapted probability mi = mi / m_max

# Parameters

- `contactparameter::Float64`: Expected value of a Poisson-Distribution used to draw the number of contacts
- `contact_matrix_file::String`: String path to a file with an `NxN` contact probability matrix
- `interval::Int64`: Year-intervals of contact matrix (e.g., 5 means, the data contains age-age-couplings for 5-year age groups)
"""
mutable struct AgeBasedContactSampling <: ContactSamplingMethod
    contactparameter::Float64
    interval::Int64
    contact_matrix::ContactMatrix{Float64}
    age_pyramid::Vector{Float64} #it will be computed in sample_contacts method

    function AgeBasedContactSampling(; contactparameter::Float64, contact_matrix_file::String, interval::Int64)
        if contactparameter < 0
            throw(ArgumentError("'contactparameter' is $contactparameter, but the 'contactparameter' has to be non-negative!"))
        end
        matrix = readdlm(contact_matrix_file)
        for i in 1:size(matrix)[1]
            s = sum(matrix[i, :])
            if abs(s - 1.0) > 1e-10
                throw(ArgumentError("Sum of row $i in 'contact_matrix' is $s, but the sum has to be equal to 1.0!"))
            end
        end
        contact_matrix = ContactMatrix{Float64}(matrix, interval)
        return new(contactparameter, interval, contact_matrix, Float64[])
    end

    function AgeBasedContactSampling(contactparameter::Float64, interval::Int64, contact_matrix::ContactMatrix{Float64}, age_pyramid::Vector{Float64})
        if contactparameter < 0
            throw(ArgumentError("'contactparameter' is $contactparameter, but the 'contactparameter' has to be non-negative!"))
        end
        return new(contactparameter, interval, contact_matrix, age_pyramid)
    end
end