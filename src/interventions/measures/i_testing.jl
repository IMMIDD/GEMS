export Test
export name, type, positive_followup, negative_followup

###
### STRUCT
###

"""
    Test <: IMeasure

Intervention struct to apply a pathogen test to an individual.
Instantiate a `Test` measure with a `name` and a `type`. The
name will determine the labeling of the test series in the logger
and can be chosen arbitrarily. The `type` must be a `TestType`
object that you need to define beforehand. It contains information,
e.g., about the sensitivity and specificity of the respective test type.
Tests are generally separated into 'reportable' tests that contribute
to the statistics of 'detected cases' or non-'reportable' which might
still change an individual's behavior (such as a rapid-self-test at home)
but will not be reported to the authorities.

# Optional Arguments
- `positive_followup::IStrategy`: What to do with the individual if the test is positive
- `negative_followup::IStrategy`: What to do with the individual if the test is negative
- `reportable::Bool`: Whether a positive result should contribute to the statistics of 'detected cases'. The default is `true`.

# Example

```julia
antigen_test = TestType("Antigen Test", pathogen(sim), sim)

my_str = IStrategy("self-test", sim)
add_measure!(my_str, Test("self-test", antigen_test, positive_followup = my_other_strategy))
```

The above example first instantiates a `TestType` for the pathogen 
registered in the `Simulation` object, creates an `IStrategy` called
'my\\_str' and adds an instance of the `Test` measure to the strategy.
The `Test` measure has a follow-up strategy called 'my\\_other\\_strategy'
in case the test result is positive. A follow-up strategy could, for example,
be a self-isolation strategy. While the above example does not have a follow-up
strategy for a negative test, you can of couse have both.
"""
struct Test <: IMeasure
    name::String    # name of testing measure (i.e. "test_after_symptoms")
    type:: AbstractTestType  # test type / brand / make
    positive_followup::Union{IStrategy, Nothing}
    negative_followup::Union{IStrategy, Nothing}
    reportable::Bool # whether a positive test from this event shall lead to a "detected case"

    function Test(name::String, type, positive_followup, negative_followup; reportable = true)
        length(name) <= 0 ? throw("Plesae provide a test series name, i.e. by supplying a keyworded argument name = 'my_test_series'") : nothing
        isnothing(type) ? throw("You need to specify a TestType, i.e. by supplying a keyworded argument type = MyTestType") : nothing
        return new(name, type, positive_followup, negative_followup, reportable)
    end

    Test(name, type; positive_followup = nothing, negative_followup = nothing, reportable = true) = 
        Test(name, type, positive_followup, negative_followup, reportable = reportable)

    Test(;name = "", type = nothing, positive_followup = nothing, negative_followup = nothing, reportable = true) = 
        Test(name, type, positive_followup, negative_followup, reportable = reportable)
end

"""
    name(t::Test)

Returns the `name` of a test-series from a `Test` measure struct.
"""
function name(t::Test)
    return(t.name)
end

"""
    type(t::Test)

Returns the test `type` from a `Test` measure struct.
"""
function type(t::Test)
    return(t.type)
end

"""
    positive_followup(t::Test)

Returns the `positive_followup` strategy from a `Test` measure struct.
"""
function positive_followup(t::Test)
    return(t.positive_followup)
end

"""
    negative_followup(t::Test)

Returns the `negative_followup` strategy from a `Test` measure struct.
"""
function negative_followup(t::Test)
    return(t.negative_followup)
end

"""
    reportable(t::Test)

Returns the `reportable` boolean flag from a `Test` measure struct.
"""
function reportable(t::Test)
    return(t.reportable)
end


###
### PROCESS MEASURE
###


"""
    process_measure(sim::Simulation, ind::Individual, test::Test)

Apply a test of `TestType` (as specified in the `Test` measure) to an individual.
The test will automatically be logged in the `Simulation`'s internal loggers.
If a follow-up strategy is set (for either positive or negative results), the 
follow-up strategy is handed over to the `EventQueue` for this individual.

# Parameters

- `sim::Simulation`: Simulation object
- `ind::Individual`: Individual that this measure will be applied to (focus individual)
- `test::Test`: Measure instance

# Returns

- `Handover`: Struct that contains the focus individual (`ind`) and the respective 
    followup `IStrategy` defined in the input `Test` measure depending
    on whether the test returned a positive or negative result.
"""
function process_measure(sim::Simulation, ind::Individual, test::Test)

    test_pos = apply_test(ind, test |> type, sim, test |> reportable)
    
    @debug "Individual $(ind |> id) $(ind |> infected ? "(inf)" : "") tested $(test_pos ? "positive" : "negative") at tick $(sim |> tick)"

    # if test is positive, return strategy for handling positive results for this individual
    return Handover(ind, test_pos ? test |> positive_followup : test |> negative_followup)
end