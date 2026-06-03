export TestRegistry, TestState

"""
    TestState

Immutable, bits-type record storing the per-individual, per-pathogen test history.
One entry per `(individual, pathogen)` pair, stored in a sharded `TestRegistry`.

An entry is considered inactive when `pathogen_id == DEFAULT_PATHOGEN_ID`.
"""
struct TestState
    pathogen_id::Int8
    last_test::Int16
    last_test_result::Bool
    was_reported::Bool
end

"""
    TestState()

Constructs an empty/inactive `TestState` sentinel.
"""
function TestState()::TestState
    return TestState(DEFAULT_PATHOGEN_ID, DEFAULT_TICK, false, false)
end

"""
    TestRegistry

Sharded dictionary store for per-individual, per-pathogen test state. One entry
per `(individual, pathogen)` pair. Keyed by a packed `UInt64` composite of
`(individual_id, pathogen_id)`.

Unlike `InfectionRegistry` and `ImmunityRegistry`, this registry uses a `Dict`
rather than a linked list because there is at most one record per
`(individual, pathogen)` pair and testing only occurs during intervention
processing (not the hot simulation loop).
"""
struct TestRegistry
    states::Dict{UInt64, TestState}

    function TestRegistry()
        return new(Dict{UInt64, TestState}())
    end
end
