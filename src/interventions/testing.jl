export TestType
export pathogen, sensitivity, name

export apply_test, apply_pool_test


###
### TEST TYPES
###

"""
    TestType <: AbstractTestType

A type to specify a type of pathogen test (e.g. 'PCR Test') and its parameterization.

# Fields
- `name::String`: Name of the test (e.g. 'Rapid Test' or 'PCR Test')
- `pathogen::Pathogen`: Pathogen that this test will detect
- `sensitivity::Float64 = 1.0`: Probability (0-1) that this test will positively identify an infection (true positive rate) 
- `specificity::Float64 = 1.0`: Probability (0-1) that this test will negatively identify a non-infection (true negative rate)

"""
struct TestType <: AbstractTestType
    name::String
    pathogen::Pathogen
    sensitivity::Float64 # 0-1
    specificity::Float64 # 0-1
    
    @doc """
        TestType(name::String, pathogen::Pathogen, sim::Simulation;
            sensitivity::Float64 = 1.0, specificity::Float64 = 1.0, reportable::Bool = true)

    Creates a TestType object.

    # Parameters
      - `name::String`: Name of the test (e.g. 'Rapid Test' or 'PCR Test')
      - `pathogen::Pathogen`: Pathogen that this test will detect
      - `sim::Simulation`: Simulation object (required to interlink test with simulation)
      - `sensitivity::Float64 = 1.0` *(optional)*: Probability (0-1) that this test will positively identify an infection (true positive rate) 
      - `specificity::Float64 = 1.0` *(optional)*: Probability (0-1) that this test will negatively identify a non-infection (true negative rate)
    """
    function TestType(name::String, pathogen::Pathogen, sim::Simulation;
        sensitivity::Float64 = 1.0, specificity::Float64 = 1.0)

        # check input
        if !(0.0 <= sensitivity <= 1.0)
            throw(ArgumentError("Test sensitivity value must be between 0 and 1"))
        end

        if !(0.0 <= specificity <= 1.0)
            throw(ArgumentError("Test specificity value must be between 0 and 1"))
        end

        temp = new(name, pathogen, sensitivity, specificity)

        add_testtype!(sim, temp)
        
        return(temp)
    end
end

"""
    name(tt::TestType)

Returns the TestType's name.
"""
function name(tt::TestType)
    return(tt.name)
end

"""
    pathogen(tt::TestType)

Returns the TestType's associated pathogen.
"""
function pathogen(tt::TestType)
    return(tt.pathogen)
end

"""
    sensitivity(tt::TestType)

Returns the TestType's sensitivity.
"""
function sensitivity(tt::TestType)
    return(tt.sensitivity)
end

"""
    specificity(tt::TestType)

Returns the TestType's specificity.
"""
function specificity(tt::TestType)
    return(tt.specificity)
end

###
### PRINTING
###

Base.show(io::IO, tt::TestType) = print(io, "$(tt.pathogen.name)-Test: $(tt.name) (Sensitivity: $(tt.sensitivity), Specificity: $(tt.specificity))")



###
### TESTING
###


"""
    apply_test(ind::Individual, testtype::TestType, sim::Simulation, reportable::Bool)

Subjects the individual to a test of the specified `TestType` and logs the result in the simulation's 
`TestLogger`. Returns a boolean; `true` if test was positive and `false` otherwise. Note that this
fuction might return false positives and false negatives, depending on the `TestType` parameterization.
If the `reportable` attribute is true, a positive test will lead to the detection of a previously
undetected individual.

# Parameters

- `ind::Individual`: Individual to be tested
- `testtype::TestType`: type of test that will be used (e.g. 'PCR'; needs to be defined as `TestType` beforehand)
- `sim::Simulation`: Simulation object
- `reportable::Bool`: If true, a positive test result will be 'reported'

# Returns

- `Bool`: Test result (**Note**: Pay attention to test sensitivity and specificity of the respective `TestType` as this
    might lead to false negatives or false positives)
"""
function apply_test(ind::Individual, testtype::TestType, sim::Simulation, reportable::Bool)

    # apply test
    test_pos = infected(ind) && rand() <= testtype |> sensitivity ||
        !infected(ind) && rand() > testtype |> specificity

    # add test information in agent
    last_test!(ind, sim |> tick)
    last_test_result!(ind, test_pos)
    test_pos && reportable ? last_reported_at!(ind, sim |> tick) : nothing

    # log test in sim object
    log!(
        sim |> testlogger,
        ind |> id,
        sim |> tick,
        test_pos,
        ind |> infected,
        infected(ind) ? infection_id(ind) : DEFAULT_INFECTION_ID,
        testtype |> name,
        test_pos && reportable)

    return test_pos
end     



"""

    apply_pool_test(setting::Setting, testtype::TestType, sim::Simulation; subset::Union{Vector{Individual}, Nothing} = nothing)

Subjects a collection of individuals to a pool test of the specified `TestType` and logs the result in the simulation's 
`PoolTestLogger`. Returns a boolean; `true` if test was positive (at least one infected individual) and `false` otherwise. Note that this
fuction might return false positives and false negatives, depending on the `TestType` parameterization.
If no subset of individuals (as a vector) is provided, this function will
take all individuals assigned to the specified setting.

# Parameters

- `setting::Setting`: Setting that is being pool-tested
- `testtype::TestType`: type of test that will be used (e.g. 'PCR'; needs to be defined as `TestType` beforehand)
- `sim::Simulation`: Simulation object
- `subset::Union{Vector{Individual}, Nothing} = nothing` *(optional)*: Provide a subset of individuals to apply the pool test to

# Returns

- `Bool`: Test result (**Note**: Pay attention to test sensitivity and specificity of the respective `TestType` as this
    might lead to false negatives or false positives)
"""
function apply_pool_test(setting::Setting, testtype::TestType, sim::Simulation; subset::Union{Vector{Individual}, Nothing} = nothing)
    # if a subset is provided, check whether subset is ACTUALLY a subset of the setting
    if subset !== nothing && !issubset(subset, setting |> individuals)
        throw("Not all individuals of the provided 'subset' are found to be members of the specified settting.")
    end

    # no of individuals. If  no subset provided, use all individuals from setting
    no_of_ind = subset === nothing ? setting |> individuals |> length : subset |> length

    # number of infected. If no subset provided, use all individuals from setting
    no_of_inf = subset === nothing ? setting |> individuals |> num_of_infected : subset |> num_of_infected

    # apply test
    test_pos = no_of_inf > 0 && rand() <= testtype |> sensitivity ||
        no_of_inf == 0 && rand() > testtype |> specificity

    # log pool test in sim object
    log!(
        sim |> pooltestlogger,
        setting |> id,
        setting |> settingchar,
        sim |> tick,
        test_pos,
        Int16(no_of_ind),
        Int16(no_of_inf),
        testtype |> name)

    return test_pos
end