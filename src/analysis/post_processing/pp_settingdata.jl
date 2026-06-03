export settingdata

""" 
    settingdata(postProcessor::PostProcessor)

Returns a `DataFrame` containing information about setting types

# Returns

- `DataFrame` with the following columns:

| Name                 | Type      | Description                                                      |
| :------------------- | :-------- | :--------------------------------------------------------------- |
| `setting_type`       | `String`  | Setting type identifier (name)                                   |
| `number_of_settings` | `Int64`   | Overall number of settings of that type                          |
| `min_individuals`    | `Float64` | Lowest number of individuals assigned to a setting of this type  |
| `max_individuals`    | `Float64` | Highest number of individuals assigned to a setting of this type |
| `avg_individuals`    | `Float64` | Average number of individuals assigned to a setting of this type |

"""
function settingdata(postProcessor::PostProcessor)

    stype = Vector{String}()
    cnt = Vector{Int64}()
    min = Vector{Float64}()
    max = Vector{Float64}()
    avg = Vector{Float64}()

    for (type, sets) in postProcessor |> simulation |> settings

        (min_val, max_val, avg_val) = min_max_avg_individuals(sets, postProcessor |> simulation)

        push!(stype, string(type))
        push!(cnt, length(sets))
        push!(min, isnothing(min_val) ? 0 : min_val)
        push!(max, isnothing(max_val) ? 0 : max_val)
        push!(avg, isnothing(avg_val) ? 0 : avg_val)
        
    end

    return(DataFrame(setting_type = stype,
        number_of_settings = cnt,
        min_individuals = min,
        max_individuals = max,
        avg_individuals = avg))
end