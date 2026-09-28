export total_infections, initial_infections

"""
    total_infections(postProcessor::PostProcessor)

Returns the total number of infections per pathogen.

# Returns

- `DataFrame` with the following columns:

| Name                 | Type    | Description                          |
| :------------------- | :------ | :----------------------------------- |
| `pathogen_id`        | `Int8`  | Pathogen identifier                  |
| `total_infections`   | `Int64` | Total number of infections           |
"""
function total_infections(postProcessor::PostProcessor)
    pathogen_ids = _sorted_pathogen_ids(postProcessor)
    counts = _rows_per_pathogen(infectionsDF(postProcessor).pathogen_id, pathogen_ids)
    infected = counts .> 0
    return DataFrame(pathogen_id = pathogen_ids[infected], total_infections = counts[infected])
end

"""
    initial_infections(postProcessor::PostProcessor)

Returns the number of seeding infections (infections set before the simulation
clock starts) per pathogen.

# Returns

- `DataFrame` with the following columns:

| Name                   | Type    | Description                                |
| :--------------------- | :------ | :----------------------------------------- |
| `pathogen_id`          | `Int8`  | Pathogen identifier                        |
| `initial_infections`   | `Int64` | Number of seeding infections               |
"""
function initial_infections(postProcessor::PostProcessor)
    pathogen_ids = _sorted_pathogen_ids(postProcessor)
    infs = infectionsDF(postProcessor)
    all_c = _rows_per_pathogen(infs.pathogen_id, pathogen_ids)
    seed_c = _seed_rows_per_pathogen(infs.pathogen_id, infs.id_a, pathogen_ids)
    infected = all_c .> 0
    return DataFrame(pathogen_id = pathogen_ids[infected], initial_infections = seed_c[infected])
end
