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
    return combine(groupby(infs, :pathogen_id),
        :id_b => (ids -> length(unique(ids)) / pop_size) => :attack_rate)
end
