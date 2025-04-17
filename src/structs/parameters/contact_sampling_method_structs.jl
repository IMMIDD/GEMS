export ContactSamplingMethod
export RandomSampling
export TestSampling
export ContactparameterSampling
export ContactAgeBasedparameterSampling


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
"""
@with_kw struct ContactparameterSampling <: ContactSamplingMethod
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
end

"""
    ContactAgeBasedparameterSampling <: ContactSamplingMethod

Sample random contacts based on a Poissoin-Distribution spread around `contactparameter_sampling.contactparameter` with weighted sampling based on age distance.
"""
mutable struct ContactAgeBasedparameterSampling <: ContactSamplingMethod
    contactparameter::Float64
    interval::Int64
    contact_matrix::ContactMatrix{Float64}
    age_pyramid::Vector{Float64} #it will be computed in sample_contacts method

    function ContactAgeBasedparameterSampling(; contactparameter::Float64, contact_matrix_file::String, interval::Int64)
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

    function ContactAgeBasedparameterSampling(contactparameter::Float64, interval::Int64, contact_matrix::ContactMatrix{Float64}, age_pyramid::Vector{Float64})
        if contactparameter < 0
            throw(ArgumentError("'contactparameter' is $contactparameter, but the 'contactparameter' has to be non-negative!"))
        end
        return new(contactparameter, interval, contact_matrix, age_pyramid)
    end
end