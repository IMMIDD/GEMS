export ContactSamplingMethod
export RandomSampling
export TestSampling
export ContactparameterSampling


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