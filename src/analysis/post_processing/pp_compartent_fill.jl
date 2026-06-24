export compartment_fill

"""
    compartment_fill(postProcessor::PostProcessor)

Returns a `DataFrame` containing the total count of infected individuals in the respective
disease states exposed, infectious, and deceased.

# Returns

- `DataFrame` with the following columns:

| Name               | Type    | Description                                         |
| :----------------- | :------ | :-------------------------------------------------- |
| `tick`             | `Int16` | Simulation tick (time)                              |
| `exposed_cnt`      | `Int64` | Total number of individuals in the exposed state    |
| `infectious_cnt`   | `Int64` | Total number of individuals in the infectious state |
| `dead_cnt`         | `Int64` | Total number of individuals in the deceased state   |

"""
function compartment_fill(postProcessor::PostProcessor)::DataFrame

    return postProcessor.compartmentsDF
end