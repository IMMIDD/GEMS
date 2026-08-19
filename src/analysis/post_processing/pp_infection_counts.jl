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
    return combine(groupby(infectionsDF(postProcessor), :pathogen_id), nrow => :total_infections)
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
    all_c = combine(groupby(infectionsDF(postProcessor), :pathogen_id), nrow => :n_all)
    sim_c = combine(groupby(sim_infectionsDF(postProcessor), :pathogen_id), nrow => :n_sim)
    res = leftjoin(all_c, sim_c, on = :pathogen_id)
    transform!(res, [:n_all, :n_sim] => ByRow((a, s) -> a - coalesce(s, 0)) => :initial_infections)
    return DataFrames.select(res, :pathogen_id, :initial_infections)
end
