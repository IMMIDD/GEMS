export compartment_fill

"""
    compartment_fill(postProcessor::PostProcessor)

Returns a `DataFrame` containing the per-tick population state counts. 

# Returns

- `DataFrame` with the following columns:

| Name                        | Type    | Description                                                                    |
| :-------------------------- | :------ | :----------------------------------------------------------------------------- |
| `tick`                      | `Int16` | Simulation tick (time)                                                         |
| `exposed_cnt`               | `Int64` | Total number of individuals in the exposed state                               |
| `infectious_cnt`            | `Int64` | Total number of individuals in the infectious state                            |
| `dead_cnt`                  | `Int64` | Total number of individuals in the deceased state                              |
| `detected_cnt`              | `Int64` | Total number of detected individuals                                           |
| `quarantined`               | `Int64` | Total number of individuals in quarantine                                      |
| `quarantined_students`      | `Int64` | Students in quarantine                                                         |
| `isolated_students`         | `Int64` | Students in quarantine who are infected                                        |
| `unable_to_attend_students` | `Int64` | Students unable to attend (closed class, severe, hospitalized, or quarantined) |
| `quarantined_workers`       | `Int64` | Workers in quarantine                                                          |
| `isolated_workers`          | `Int64` | Workers in quarantine who are infected                                         |
| `unable_to_attend_workers`  | `Int64` | Workers unable to attend (closed office, severe, hospitalized, or quarantined) |

"""
function compartment_fill(postProcessor::PostProcessor)::DataFrame

    return postProcessor.compartmentsDF
end
