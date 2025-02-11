export PoolTest
export name, type, positive_followup, negative_followup

###
### STRUCT
###

"""
    PoolTest <: SMeasure

Intervention struct to apply a pathogen pool test to all individuals
in a specified setting. Instantiate a `PoolTest` measure with a `name` and a `type`.
A `PoolTest` will return a positive result if at least one of the individuals
present at a given setting is infected.
The name will determine the labeling of the test series in the logger
and can be chosen arbitrarily. The `type` must be a `TestType`
object that you need to define beforehand. It contains information,
e.g., about the sensitivity and specificity of the respective test type.

The `PoolTest` measure is different from the `TestAll` measure as the
former just uses one test to evaluate whether any of the individuals
is infected and the latter applies a separate test to all individuals.

# Optional Arguments
- `positive_followup::SStrategy`: What to do with the setting if the test is positive
- `negative_followup::SStrategy`: What to do with the setting if the test is negative

# Example

```julia
pcr_test = TestType("PCR Test", pathogen(sim), sim)

my_str = SStrategy("school-pool-test", sim)
add_measure!(my_str, PoolTest("pool-test", pcr_test, positive_followup = my_close_school_str))
```

The above example first instantiates a `TestType` for the pathogen 
registered in the `Simulation` object, creates an `SStrategy` called
'my\\_str' and adds an instance of the `PoolTest` measure to the strategy.
The `PoolTest` measure has a follow-up strategy called 'my\\_close\\_school\\_str'
in case the test result is positive. A follow-up strategy could, for example,
be a school-closure strategy. While the above example does not have a follow-up
strategy for a negative test, you can ofcouse have both.
"""
struct PoolTest <: SMeasure
    name::String    # name of testing measure (i.e. "test_after_symptoms")
    type::TestType  # test type / brand / make
    positive_followup::Union{SStrategy, Nothing}
    negative_followup::Union{SStrategy, Nothing}

    function PoolTest(name::String, type, positive_followup, negative_followup)
        length(name) <= 0 ? throw("Plesae provide a test series name, i.e. by supplying a keyworded argument name = 'my_test_series'") : nothing
        isnothing(type) ? throw("You need to specify a TestType, i.e. by supplying a keyworded argument type = MyTestType") : nothing
        return new(name, type, positive_followup, negative_followup)
    end

    PoolTest(name, type; positive_followup = nothing, negative_followup = nothing) = 
        PoolTest(name, type, positive_followup, negative_followup)

    PoolTest(;name = "", type = nothing, positive_followup = nothing, negative_followup = nothing) = 
        PoolTest(name, type, positive_followup, negative_followup)
end

"""
    name(t::PoolTest)

Returns the `name` of a test-series from a `PoolTest` measure struct.
"""
function name(t::PoolTest)
    return(t.name)
end

"""
    type(t::PoolTest)

Returns the test `type` from a `PoolTest` measure struct.
"""
function type(t::PoolTest)
    return(t.type)
end

"""
    positive_followup(t::PoolTest)

Returns the `positive_followup` strategy from a `PoolTest` measure struct.
"""
function positive_followup(t::PoolTest)
    return(t.positive_followup)
end

"""
    negative_followup(t::PoolTest)

Returns the `negative_followup` strategy from a `PoolTest` measure struct.
"""
function negative_followup(t::PoolTest)
    return(t.negative_followup)
end

###
### PROCESS MEASURE
###

"""
    process_measure(sim::Simulation, s::Setting, measure::PoolTest)

Apply a test of `TestType` (as specified in the `PoolTest` measure) to a setting.
The test will automatically be logged in the `Simulation`'s internal loggers.
If a follow-up strategy is set (for either positive or negative results), the 
follow-up strategy is handed over to the `EventQueue` for this setting.

# Parameters

- `sim::Simulation`: Simulation object
- `s::Setting`: Setting that this measure will be applied to (focus setting)
- `measure::PoolTest`: Measure instance

# Returns

- `Handover`: Struct that contains the focus setting (`s`) and the respective 
    followup `SStrategy` defined in the input `PoolTest` measure depending
    on whether the test returned a positive or negative result.
"""
function process_measure(sim::Simulation, s::Setting, measure::PoolTest)

    # apply pool test to setting
    test_pos = apply_pool_test(s, measure |> type, sim)

    @debug "Pool testing setting $(string(typeof(s)))[$(id(s))]: $(test_pos ? "positive" : "negative") test result at tick $(sim |> tick)"

    return Handover(s, test_pos ?  measure |> positive_followup : measure |> negative_followup) 
end