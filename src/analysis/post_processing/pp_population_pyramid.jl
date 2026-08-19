export population_pyramid

""" 
    population_pyramid(postProcessor::PostProcessor)

Returns a `DataFrame` containing data to generate a population pyramid.
It provides the sum of all female and male individuals in all age groups in the population model.
Sums for female are multiplied by -1 to facilitate visualization.

# Returns

- `DataFrame` with the following columns:

| Name     | Type     | Description                                                 |
| :------- | :------- | :---------------------------------------------------------- |
| `age`    | `Int8`   | 1-year age classes                                          |
| `sex`    | `Int8`   | Sex according to population DataFame (0 = female, 1 = male) |
| `gender` | `String` | String variant of Sex [Female, Male]                        |
| `sum`    | `Int64`  | Total of all genders in all ages (females multiplied by -1) |

"""
function population_pyramid(postProcessor::PostProcessor)

    return(
        populationDF(postProcessor) |>
            x -> groupby(x, [:sex, :age]) |>
            x -> combine(x, nrow => :sum) |>
            x -> DataFrames.select(x, :age, :sex, :sex => ByRow(x -> x == FEMALE ? "Female" : "Male") => :gender, :sum) |>
            x -> transform(x, :, AsTable([:sex, :sum]) => ByRow(x -> x.sex == FEMALE ? -x.sum : x.sum) => :sum) |>
            x -> sort(x, :age)
    )

end