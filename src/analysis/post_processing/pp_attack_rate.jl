export attack_rate

"""
    attack_rate(postProcessor::PostProcessor)

Divides the number of individuals who have been infected one (or multiple)
time(s) by the total number of individuals, stratified by pathogen.

# Returns

- `DataFrame` with the following columns:

| Name           | Type      | Description                                             |
| :------------- | :-------- | :------------------------------------------------------ |
| `pathogen_id`  | `Int8`    | Pathogen identifier                                     |
| `attack_rate`  | `Float64` | Fraction of population infected by this pathogen        |
"""
function attack_rate(postProcessor::PostProcessor)
    infs = infectionsDF(postProcessor)
    pop_size = nrow(postProcessor.populationDF)
    # pathogens sorted by id; only those that infected anyone get a row
    pathogen_ids = sort(collect(eltype(infs.pathogen_id), map(id, pathogens(simulation(postProcessor)))))
    hosts = _distinct_hosts(infs.pathogen_id, infs.id_b, pathogen_ids)
    infected = hosts .> 0
    return DataFrame(pathogen_id = pathogen_ids[infected], attack_rate = hosts[infected] ./ pop_size)
end

# Distinct hosts per pathogen, marking hosts in one bit vector per pathogen over the id range
function _distinct_hosts(pids::AbstractVector, ids::AbstractVector{<:Integer}, pathogen_ids::Vector)
    lo, hi = isempty(ids) ? (1, 0) : Int.(extrema(ids))
    seen = [falses(hi - lo + 1) for _ in pathogen_ids]
    for (pid, id) in zip(pids, ids)
        p = findfirst(==(pid), pathogen_ids)
        p === nothing || (seen[p][id - lo + 1] = true)
    end
    return count.(seen)
end
