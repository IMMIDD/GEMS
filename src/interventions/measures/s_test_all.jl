export TestAll
export name, type, positive_followup, negative_followup, reportable

###
### STRUCT
###

"""
    TestAll <: SMeasure

Intervention struct to apply a pathogen test to each individual
in a specified setting. Instantiate a `TestAll` measure with a `name` and a `type`.
A `TestAll` will return a positive result if at least one of the individuals
present at a given setting has a positive test result. However, the logger
will contain test results for each of the individuals.
The name will determine the labeling of the test series in the logger
and can be chosen arbitrarily. The `type` must be a `TestType`
object that you need to define beforehand. It contains information,
e.g., about the sensitivity and specificity of the respective test type.

The `TestAll` measure is different from the `PoolTest` measure as the
latter just uses one test to evaluate whether any of the individuals
is infected and the former applies a separate test to all individuals.

# Optional Arguments
- `positive_followup::SStrategy`: What to do with the setting if the test is positive
- `negative_followup::SStrategy`: What to do with the setting if the test is negative
- `reportable::Bool`: Whether a positive result should contribute to the statistics of 'detected cases'. The default is `true`.

# Example

```julia
pcr_test = TestType("PCR Test", pathogen(sim), sim)

my_str = SStrategy("test-household-members", sim)
add_measure!(my_str, TestAll("pcr-test", pcr_test, positive_followup = my_isolate_household_str))
```

The above example first instantiates a `TestType` for the pathogen 
registered in the `Simulation` object, creates an `SStrategy` called
'my\\_str' and adds an instance of the `PoolTest` measure to the strategy.
The `PoolTest` measure has a follow-up strategy called 'my\\_isolate\\_household\\_str'
in case the test result is positive. A follow-up strategy could, for example,
be a hosuehold-isolation strategy. While the above example does not have a follow-up
strategy for a negative test, you can of couse have both.
"""
struct TestAll <: SMeasure
    name::String    # name of testing measure (i.e. "test_after_symptoms")
    type::TestType  # test type / brand / make
    positive_followup::Union{SStrategy, Nothing}
    negative_followup::Union{SStrategy, Nothing}
    reportable::Bool # whether a positive test from this event shall lead to a "detected case"

    function TestAll(name::String, type, positive_followup, negative_followup; reportable = true)
        length(name) <= 0 ? throw("Plesae provide a test series name, i.e. by supplying a keyworded argument name = 'my_test_series'") : nothing
        isnothing(type) ? throw("You need to specify a TestType, i.e. by supplying a keyworded argument type = MyTestType") : nothing
        return new(name, type, positive_followup, negative_followup, reportable)
    end

    TestAll(name, type; positive_followup = nothing, negative_followup = nothing, reportable = true) = 
        TestAll(name, type, positive_followup, negative_followup, reportable = reportable)

    TestAll(;name = "", type = nothing, positive_followup = nothing, negative_followup = nothing, reportable = true) = 
        TestAll(name, type, positive_followup, negative_followup, reportable = reportable)
end

"""
    name(t::TestAll)

Returns the `name` of a test-series from a `TestAll` measure struct.
"""
function name(t::TestAll)
    return(t.name)
end

"""
    type(t::TestAll)

Returns the test `type` from a `TestAll` measure struct.
"""
function type(t::TestAll)
    return(t.type)
end

"""
    positive_followup(t::TestAll)

Returns the `positive_followup` strategy from a `TestAll` measure struct.
"""
function positive_followup(t::TestAll)
    return(t.positive_followup)
end

"""
    negative_followup(t::TestAll)

Returns the `negative_followup` strategy from a `TestAll` measure struct.
"""
function negative_followup(t::TestAll)
    return(t.negative_followup)
end

"""
    reportable(t::TestAll)

Returns the `reportable` boolean flag from a `TestAll` measure struct.
"""
function reportable(t::TestAll)
    return(t.reportable)
end


###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, s::Setting, measure::TestAll)

Apply a test of `TestType` (as specified in the `TestAll` measure) to each individual of a setting.
The test results will automatically be logged in the `Simulation`'s internal loggers.
If a follow-up strategy is set (for either positive or negative results), the 
follow-up strategy is handed over to the `EventQueue` for this setting.

# Parameters

- `sim::Simulation`: Simulation object
- `s::Setting`: Setting that this measure will be applied to (focus setting)
- `measure::TestAll`: Measure instance

# Returns

- `Handover`: Struct that contains the focus setting (`s`) and the respective 
    followup `SStrategy` defined in the input `TestAll` measure depending
    on whether the test returned a at least one positive or all negative result.
"""
function process_measure(sim::Simulation, s::Setting, measure::TestAll)

    # testing each individual
    testres = [apply_test(i, measure |> type, sim, measure |> reportable) for i in individuals(s, sim)]
    
    # number of positive tests
    numpos = sum(testres)

    @debug "Testing all members in $(string(typeof(s)))[$(id(s))]: $numpos positives at tick $(sim |> tick)"

    return Handover(s, numpos > 0 ? measure |> positive_followup : measure |> negative_followup)
end