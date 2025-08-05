# THIS FILE CONTAINS UTILITY FUNCTION THAT ARE USEFUL FOR GEMS
# BUT DONT HAVE A COMMON THEME OR CONTRIBUTE TO INFECTION LOGIC
export concrete_subtypes, is_existing_subtype, find_subtype
export isdate
export foldercount, aggregate_df, aggregate_dfs, aggregate_dfs_multcol, aggregate_values, aggregate_dicts, print_aggregates
export read_git_repo, read_git_branch, read_git_commit
export aggregate_matrix
export basefolder, identical, bad_unique
export get_missing_docs
export parameters
export lognow, printinfo, subinfo
export _int
export remove_kw
export germanshapes, state_data, county_data, municipality_data
export gemscolors

# contact stuff
export calculate_absolute_error

function concrete_subtypes(type::Type)::Vector{Type}
    if subtypes(type) == []
        if !isabstracttype(type)
            return [type]
        end
        return []
    else
        return vcat([concrete_subtypes(t) for t in subtypes(type)]...)
    end
end

function is_existing_subtype(subtype::String, type::Type)::Bool
    #= 
    sometimes 'concrete_subtypes' produces a list with subtypes in namespace
    e.g. Distributions.Uniform
    Therefore, if applicable, we split the name to the last part after the dot
    and filter only the last part. The following will do that
    =#
    return subtype in [t[end] for t in split.(string.(concrete_subtypes(type)), ".")]
    # return subtype in string.(concrete_subtypes(type))
end

"""
    is_subtype(type::String, parent::DataType)
    is_subtype(type::Symbol, parent::DataType)

Returns `true` if the specified string in `type` is a subtype of the struct class `parent`.
If will check both, the type itself and `GEMS.type`, to resolve any namespacing problems.
This function supersedes `is_existing_subtype(...)`
"""
function is_subtype(type::String, parent::DataType)
    parent_strings = string.(subtypes(parent))
    gems_string = string(nameof(@__MODULE__))
    return (type in parent_strings) || ("$gems_string.$type" in parent_strings)
end

is_subtype(type::Symbol, parent::DataType) = is_subtype(string(type), parent)


function find_subtype(subtype::String, type::Type)::Type
    subtypes = concrete_subtypes(type)
    idx = findfirst(item -> item[end] == subtype, split.(string.(subtypes),"."))
    if idx === nothing
        throw("$subtype is not a subtype of "*string(type))
    else
        return subtypes[idx]
    end
end

"""
    get_subtype(type::String, parent::DataType)

Returns the `DataType` which is a subtype of `parent` specified by the `type` string.
This function supersedes `find_subtype(...)`

"""
function get_subtype(type::String, parent::DataType)
    stypes = subtypes(parent)
    gems_string = string(nameof(@__MODULE__))
    # find index of matching type
    i = findfirst(x -> x == type || x == "$gems_string.$type", string.(stypes))
    # return index
    return stypes[i]
end

get_subtype(type::Symbol, parent::DataType) = get_subtype(string(type), parent)


# helper function to check whether input is valid date format
function isdate(x)
    try
        Date(x)
        return true
    catch
        return false
    end
end

"""
    foldercount(directory)

Returns the number of subfolders in a directory.
"""
function foldercount(directory::AbstractString)
    items = readdir(directory)
    count = 0

    for item in items
        if isdir(joinpath(directory, item))
            count += 1
        end
    end

    return count
end



function confidence_interval_95(row)
    n = length(row)
    mean_val = mean(row)
    std_dev = std(row)
    critical_value = quantile(TDist(max(n - 1, 1 + 1e-8)), 0.975)  # For a 95% confidence level (alpha = 0.05)

    lower_bound = mean_val - (critical_value * std_dev / sqrt(n))
    upper_bound = mean_val + (critical_value * std_dev / sqrt(n))

    return (lower_bound, upper_bound)
end




"""
    aggregate_dfs(dfs::Vector{DataFrame}, key::Symbol)

Joins the input vector of `dataframes` on the `key` and
aggregates the residual data. Requires all dataframes to 
provide the exact same columns and column names.
"""
function aggregate_dfs(dfs::Vector{DataFrame}, key::Symbol)

    #TODO: input validation according to requirements

    # as the input arrives "mapped", the reduce step can begin right away
    res = reduce((df1, df2) -> outerjoin(df1, df2, on = key, makeunique = true), dfs)

    mins = [minimum(row) for row in eachrow(res[!,2:ncol(res)])]
    maxs = [maximum(row) for row in eachrow(res[!,2:ncol(res)])]
    avgs = [mean(row) for row in eachrow(res[!,2:ncol(res)])]
    stds = [std(row) for row in eachrow(res[!,2:ncol(res)])]
    CIs = [confidence_interval_95(row) for row in eachrow(res[!,2:ncol(res)])]

    return(
        DataFrame(
            string(key) => res[!,key],
            "minimum" => mins,
            "maximum" => maxs,
            "mean" => avgs,
            "std" => stds,
            "lower_95" => [t[1] for t in CIs],
            "upper_95" => [t[2] for t in CIs]
        )
    )
end
"""
    aggregate_dfs_multcol(dfs::Vector{DataFrame}, key::Symbol)

Aggregates data on the columns of the dataframes contained in the 
provided vector for each value in the key column.
All dataframes must have identical columnnames. 
Returns a dictionary with the columnnames as keys and a dataframe as the value.
"""
function aggregate_dfs_multcol(dfs::Vector{DataFrame}, key::Symbol)

    #TODO: input validation according to requirements
    columns = names(dfs[1])

    if ! all(names(df) == columns for df in dfs)
        @error "The dataframes do not have identical columns!"
    elseif length(columns) == 0
        @error "The Dataframes are empty!"
    elseif ! (string(key) in columns)
        @error "The Dataframes are empty!"
    end
    # Remove key from columns to ignore it when calculating stats
    deleteat!(columns, findfirst(x -> x == string(key), columns))

    # Costruct result dictionary
    res_dict = Dict()
    for c in columns

        # Get all the dataframes into one
        res = deepcopy(DataFrames.select(dfs[1], key, c))
        for df in dfs[2:end]
            res = outerjoin(res, DataFrames.select(df, key, c), on = key, makeunique = true)
        end

        # Set all missing fields to 0
        for col in names(res)
            res[!, col] = coalesce.(res[!, col],  0)
        end

        # Calculate stats
        mins = [minimum(row) for row in eachrow(res[!,2:ncol(res)])]
        maxs = [maximum(row) for row in eachrow(res[!,2:ncol(res)])]
        avgs = [mean(row) for row in eachrow(res[!,2:ncol(res)])]
        stds = [std(row) for row in eachrow(res[!,2:ncol(res)])]
        CIs = [confidence_interval_95(row) for row in eachrow(res[!,2:ncol(res)])]

        # Save stats in dict
        res_dict[c] = DataFrame(
            string(key) => res[!,key],
            "minimum" => mins,
            "maximum" => maxs,
            "mean" => avgs,
            "std" => stds,
            "lower_95" => [t[1] for t in CIs],
            "upper_95" => [t[2] for t in CIs]
        )
    end
    return res_dict
end

function aggregate_values(values)
    return(
        Dict(
            "min" => minimum(values),
            "max" => maximum(values),
            "mean" => mean(values),
            "std" => std(values),
            "lower_95" => confidence_interval_95(values)[1], 
            "upper_95" =>confidence_interval_95(values)[2]
        )
    )
end

function aggregate_dicts(dicts::Vector{<:Dict})
    if length(dicts) <= 0
        return(Dict())
    end

    # collect all individual values in a vector
    res_dict = Dict()
    for d in dicts
        for (key, val) in d
            if haskey(res_dict, key)
                push!(res_dict[key], val)
            else
                res_dict[key] = [val]
            end
        end
    end

    # aggregate vectors
    for (key, val) in res_dict
        res_dict[key] = aggregate_values(val)
    end   

    return(res_dict)
end


"""
    aggregate_df(df::DataFrame, key::Symbol)

Groups dataframes (with numerical values) on the provided `key`
column and applies the `aggregate_values` function to each of them.
The resulting dataframe has all initial columns supplemented with the
suffixes `min`, `max`, `mean`, `lower_95`, `upper_95`, and `std`
"""
function aggregate_df(df::DataFrame, key::Symbol)

    res = []
    grouped_df = groupby(df, key)

    # aggregate each group
    for group in grouped_df

        dictrow = Dict(string(key) => group[1, key])

        # itertate each column
        for colname in names(group)
            if colname != string(key)
                dictrow = merge(dictrow, Dict(k * "_" * colname => v for (k, v) in aggregate_values(group[!, colname])))
            end
        end

        push!(res, dictrow)
    end
    
    return(DataFrame(res))
end

"""
    print_aggregates(agg; unit, multiplier, digits)

Pretty-prints the outcomes of an `aggregate_values()` function call.
"""
function print_aggregates(agg::Dict; unit::String = "", multiplier = 1, digits::Int = 2)

    u = unit |> length <= 1 ? unit : " " * unit

    return(
        "$(round(multiplier*agg["mean"], digits = digits))$(u), " * 
        "std: $(round(multiplier*agg["std"], digits = digits))$(u), " *  
        "95-CI: " *  
        "[" *
            "$(round(multiplier*agg["lower_95"], digits = digits))" *
            "-" *
            "$(round(multiplier*agg["upper_95"], digits = digits))$(u)" *
        "], " *
        "range: " *
        "[" *
            "$(round(multiplier*agg["min"], digits = digits))" *
            "-" *
            "$(round(multiplier*agg["max"], digits = digits))$(u)" *
        "]"
    )
end


function read_git_repo()
    cmd = `git config --get remote.origin.url`
    try
        @suppress result = strip(String(read(cmd)))
        return result
    catch e
        return "No repository information available."
    end
end


function read_git_branch()
    cmd  = `git rev-parse --abbrev-ref HEAD`
    try
        @suppress result = strip(String(read(cmd)))
        return result
    catch e
        return "No branch information available."
    end
end

function read_git_commit()
    cmd = `git rev-parse HEAD`
    try
        @suppress result = strip(String(read(cmd)))
        return result
    catch e
        return "No commit information available."
    end
end


"""
    aggregate_matrix(matrix::Matrix, interval_steps::Int64)

Calculate an aggregated matrix by providing the length of the interval to aggregate. Each interval will have the same length.
If the dimension of the given matrix isn't divisible by `interval_steps`, the last interval will contain the rest of the values (this causes the last interval to be shorter than every other interval).

# Assumptions:
- The input matrix has to be of shape n x n, where n is an Int64.


# Example:
```
julia> matrix = [1 1  2 2 3 ; 1 1  2 2 3 ; 3 3 4 4 3; 3 3 4 4 3; 3 3 3 3 3]
5×5 Matrix{Int64}:
 1  1  2  2  3
 1  1  2  2  3
 3  3  4  4  3
 3  3  4  4  3
 3  3  3  3  3

julia> aggregate_matrix(matrix,2) # intervals would be [1:3), [3:5), [5:5]
3×3 Matrix{Int64}:
  4   8  6
 12  16  6
  6   6  3

```
"""
function aggregate_matrix(matrix::Matrix, interval_steps::Int64)::Matrix
    
    if (length(matrix[1,:]) != length(matrix[:,1]))
        throw(ArgumentError("input matrix needs to be of shape: n x n!"))
    end

    if (interval_steps <= 1)
        throw(ArgumentError("interval steps have to be at least 2 or greater!"))
    end

    input_matrix_dimension = length(matrix[1,:])
    new_matrix_dimension = ceil(Int, input_matrix_dimension / interval_steps)
    aggregated_matrix = zeros(Int64, new_matrix_dimension, new_matrix_dimension)

    for i in 1:new_matrix_dimension
        for j in 1:new_matrix_dimension

            row_start = (i-1) * interval_steps + 1

            # only true if in the last row of the input matrix
            row_end = (i != new_matrix_dimension) ? i * interval_steps : input_matrix_dimension

            col_start = (j-1) * interval_steps + 1

            # only true if in the last column of the input matrix
            col_end = (j != new_matrix_dimension) ? j * interval_steps : input_matrix_dimension

            aggregated_matrix[i,j] = sum(matrix[row_start:row_end, col_start:col_end])
        end
    end

    return aggregated_matrix

end


"""
    aggregate_matrix(vector::Vector, interval_steps::Int64)::Matrix

Aggregate values in a Vector by a given interval (defined by `interval_steps`).
If the dimension of the given Vector isn't divisible by `interval_steps`, the last interval will contain the rest of the values (this causes the last interval to be shorter than every other interval).

# Example
```
julia> vector = [1, 1, 8, 5, 3]
5-element Vector{Int64}:
 1
 1
 8
 5
 3

# intervals would be [1:3), [3:5), [5:5]
julia> aggregate_matrix(vector,2)
3×1 Matrix{Int64}:
  2
 13
  3

```
"""
function aggregate_matrix(vector::Vector, interval_steps::Int64)::Matrix

    if (interval_steps <= 1)
        throw(ArgumentError("interval steps have to be at least 2 or greater!"))
    end
    

    new_matrix_dimension = ceil(Int, length(vector) / interval_steps)
    aggregated_matrix = zeros(Int64, new_matrix_dimension, 1)

    for i in 1:new_matrix_dimension
        start_index = (i-1) * interval_steps + 1
        end_index = (i != new_matrix_dimension) ? i * interval_steps : length(vector)
    
        aggregated_matrix[i] = sum(vector[start_index:end_index])
    end

    return aggregated_matrix
end

"""
    aggregate_matrix(matrix::Matrix, interval_steps::Int64, aggregation_bound::Int64)

Aggregate values in a matrix by a given interval (defined by `interval_steps`).
`aggregation_bound` sets a upper boundary. In the interval [1:`aggregation_bound`), values are aggregated in sub-intervals defined by `interval_steps`.
In the interval [`aggregation_bound`:length(matrix[1,:])] all values will be summed up.

# Assumptions:
- The input matrix has to be of shape n x n, where n is an Int64.

# Example:
```
julia> matrix = [1 1  2 2 3 ; 1 1  2 2 3 ; 3 3 4 4 3; 3 3 4 4 3; 3 3 3 3 3]
5×5 Matrix{Int64}:
 1  1  2  2  3
 1  1  2  2  3
 3  3  4  4  3
 3  3  4  4  3
 3  3  3  3  3

# intervals would be [1:3), 3+
julia> aggregate_matrix(matrix, 2, 3)
2×2 Matrix{Int64}:
  4  14
 18  31

```
"""
function aggregate_matrix(matrix::Matrix, interval_steps::Int64, aggregation_bound::Int64)::Matrix
    
    if (length(matrix[1,:]) != length(matrix[:,1]))
        throw(ArgumentError("input matrix needs to be of shape: n x n!"))
    end

    if (interval_steps <= 1)
        throw(ArgumentError("interval steps have to be at least 2 or greater!"))
    end

    if (aggregation_bound <= 1)
        throw(ArgumentError("aggregation bound has to be at least 2 or greater!"))
    end

    if (aggregation_bound < interval_steps)
        throw(ArgumentError("aggregation bound has to be greater or equal to interval steps!"))
    end

    if ((aggregation_bound % interval_steps) != 0)
        throw(ArgumentError("interval steps have to be a multiple of aggregation bound!"))
    end

    input_matrix_dimension = length(matrix[1,:])

    new_matrix_dimension = trunc(Int64, aggregation_bound / interval_steps) + 1

    aggregated_matrix = zeros(Int64, new_matrix_dimension, new_matrix_dimension)

    for i in 1:new_matrix_dimension
        for j in 1:new_matrix_dimension

            row_start = (i-1) * interval_steps + 1

            # only true if in the last row of the input matrix
            row_end = (i != new_matrix_dimension) ? i * interval_steps : input_matrix_dimension

            col_start = (j-1) * interval_steps + 1

            # only true if in the last column of the input matrix
            col_end = (j != new_matrix_dimension) ? j * interval_steps : input_matrix_dimension

            aggregated_matrix[i,j] = sum(matrix[row_start:row_end, col_start:col_end])
        end
    end

    return aggregated_matrix

end

"""
    aggregate_matrix(vector::Vector, interval_steps::Int64, aggregation_bound::Int64)::Matrix

Aggregate values in a Vector by a given interval (defined by `interval_steps`).
`aggregation_bound` sets a upper boundary. In the interval [1:`aggregation_bound`), values are aggregated in sub-intervals, defined by `interval_steps`.
In the interval [`aggregation_bound`:length(vector)] all values will be summed up.

# Example
```
julia> vector = [1, 1, 8, 5, 3, 5, 8, 7 ,9]
9-element Vector{Int64}:
 1
 1
 8
 5
 3
 5
 8
 7
 9

# intervals would be [1:3), [3:5), 5+
julia> aggregate_matrix(vector, 2, 5)
3×1 Matrix{Int64}:
  2
 13
 32

```
"""
function aggregate_matrix(vector::Vector, interval_steps::Int64, aggregation_bound::Int64)::Matrix

    if (interval_steps <= 1)
        throw(ArgumentError("interval steps have to be at least 2 or greater!"))
    end
    
    if (aggregation_bound <= 1)
        throw(ArgumentError("aggregation bound has to be at least 2 or greater!"))
    end

    if (aggregation_bound < interval_steps)
        throw(ArgumentError("aggregation bound has to be greater or equal to interval steps!"))
    end

    if ((aggregation_bound % interval_steps) != 0)
        throw(ArgumentError("interval steps have to be a multiple of aggregation bound!"))
    end

    new_matrix_dimension = trunc(Int64, aggregation_bound / interval_steps) + 1

    aggregated_matrix = zeros(Int64, new_matrix_dimension, 1)

    for i in 1:new_matrix_dimension
        start_index = (i-1) * interval_steps + 1
        end_index = (i != new_matrix_dimension) ? i * interval_steps : length(vector)
    
        aggregated_matrix[i] = sum(vector[start_index:end_index])
    end

    return aggregated_matrix
end



function basefolder()
    return(dirname(dirname(pathof(GEMS))))
end


function identical(a, b, ident = true)
    if typeof(a) != typeof(b)
        return false
    end
    if length(fieldnames(typeof(a))) == 0
        ident = a == b && ident
    else
        for f in fieldnames(typeof(a))
            ident = identical(getproperty(a, f), getproperty(b, f)) && ident
        end
    end
    return ident
end

function bad_unique(vec)
    if length(vec) == 1
        return
    end
    for (i, entry) in enumerate(vec)
        for j in (i+1):length(vec)
            if entry == vec[j]
                deleteat!(vec, j)
            elseif identical(entry, vec[j])
                deleteat!(vec, j)
            end
        end
    end
end




function get_missing_docs()
    # copied from: https://discourse.julialang.org/t/check-if-a-function-has-a-docstring/103489/3
    hasdoc(mod::Module, sym::Symbol) = haskey(Base.Docs.meta(mod), Base.Docs.Binding(mod, sym));

    return(
        filter(n -> !hasdoc(GEMS, n), names(GEMS))
    )
end

"""
    parameters(d::Distribution)

Returns a dictionary containing the string() of the distribution, the mean and
the std.
"""
function parameters(d::Distribution)
    # Get the parameters as a named tuple
    res = Dict( 
        "distribution" => string(d),
        "mean" => d |> mean,
        "std" => d |> std
    )
    return res
end


"""
    clean_result!(dict::Dict)

Helper function to clean data for JSON output.
Also uses parameter function for the StartCondition, Vaccine and Pathogen.

"""
function clean_result!(dict::Dict)
    for (key, val) in dict
        if isa(val, DataFrame) || isa(val, Matrix)
            delete!(dict, key)
        elseif isa(val, StartCondition)
            dict[key] = parameters(val)
        elseif isa(val, StopCriterion)
            dict[key] = parameters(val)
        elseif isa(val, Vector{<:StartCondition})
            dict[key] = [parameters(v) for v in val]
        elseif isa(val, Pathogen)
            dict[key] = parameters(val)
        elseif isa(val, Vector{Pathogen})
            dict[key] = [parameters(v) for v in val]
        elseif isa(val, Vaccine)
            dict[key] = parameters(val)
        elseif isa(val, Vector{Vaccine})
            dict[key] = [parameters(v) for v in val]
        elseif isa(val, Dict)
            clean_result!(dict[key])
            if length(dict[key]) == 0
                delete!(dict, key)
            end
        end
    end
end


"""
    calculate_absolute_error(matrix1::Matrix{T}, matrix2::Matrix{T})::Matrix{T} where T <: Number

Calculate the absolute difference between `matrix1` and `matrix2`.

# Example

```
julia> m1 = [2 2; 2 2]
2×2 Matrix{Int64}:
 2  2
 2  2

julia> m2 = [3 1; 4 2]
2×2 Matrix{Int64}:
3  1
4  2

calculate_absolute_error(m1,m2)
2×2 Matrix{Int64}:
 1  1
 2  0
```
"""
function calculate_absolute_error(matrix1::Matrix{T}, matrix2::Matrix{T})::Matrix{T} where T <: Number

    result::Matrix = zeros(T, length(matrix1[1,:]), length(matrix1[1,:]))

    for i in 1:length(matrix1[1,:])
        for j in 1:length(matrix1[1,:])
            result[i,j] = abs(matrix1[i,j] - matrix2[i,j])
        end
    end
    
    return result

end

"""
    find_alpha(observation_matrix::Matrix{T}, prediction_matrix::Matrix{T})::T where T <: Number

This is an internal function not intended for direct use!

This function uses maximum likelyhood estimation to find the "alpha" for which the function:

    f(alpha) = sum((observation_matrix - alpha * prediction_matrix)^2)

is minimal. Alpha describes the factor in which `observation_matrix` and `prediction_matrix` differ. This is based on the assumption that the difference between two numbers of contacts from two different models can be described by a scalar factor `alpha`.

`observation_matrix` (om) = the matrix of observed values
`prediction_matrix` (pm) = the matrix of predicted values

# Assumptions
- `om` and `pm` have to be of the same dimensions.
- `om` and `pm` both have to be of shape: n x n.

"""
function find_alpha(observation_matrix::Matrix{T}, prediction_matrix::Matrix{T})::T where T <: Number

    if (length(prediction_matrix[1,:]) != length(observation_matrix[:,1]))
        throw(ArgumentError("input matrices needs to be of same dimension"))
    end

    sum_om_pm::T = 0.0
    sum_pm_squared::T = 0.0

    for i in 1:length(prediction_matrix[1,:])
        for j in 1:length(prediction_matrix[1,:])
            sum_om_pm += prediction_matrix[i,j] * observation_matrix[i,j]
        end
    end

    for i in 1:length(prediction_matrix[1,:])
        for j in 1:length(prediction_matrix[1,:])
            sum_pm_squared += prediction_matrix[i,j]^2  
        end
    end

    alpha::T = (sum_om_pm) / sum_pm_squared

    return alpha
end
"""
    lognow()

Returns the current time in HH:MM:SS format for logging purposes.
"""
function lognow()
    return(Dates.format(Dates.now(), "HH:MM:SS"))
end


"""
    printinfo(str::String)

Prints an @info-Text with the provided string and a HH:MM:SS timestamp.
"""
function printinfo(str::String)
    PRINT_INFOS ? (@info "$(lognow()) | $str") : nothing
end


"""
    subinfo(str::String)

Returns a string with a "sub-line-hook" indicating subtasks
of an @info task (as generated by `printinfo()`)
"""
function subinfo(str::String)
    if !PRINT_INFOS return "" end

    #  console dimensions
    height, width = displaysize(stdout)

    # default offset
    offset = 8
    # cut string length if necessary

    toprint = "$(lognow()) | \u2514 $str"
    
    toprint = offset < width ? (" " ^ offset) * toprint : toprint

    # cut output to console length
    toprint = length(toprint) > width ? toprint[1:width] : toprint

    # fill with spaces until console width is reached
    toprint *= (" " ^ (width - length(toprint)))

    return(toprint)
end

"""
    _int(f::Function)
    
Wrapper to enforce Integer returns of anonymous functions.
"""
_int(f) = x->f(x)::Int


"""
    remove_kw(to_remove::Symbol, kwrds)

Removes a particular keyword from a Named Tuple keyword ist.
This is mainly used to exclude certain keywords in plots
when passing `plotargs...` to subplots.

# Example

```julia
function my_function(;args...)
    new_kwrds = remove_kw(:a, args)
    my_other_function(new_kwrds...)
end
```

If you call the above function with `my_function(a = 2, b = 3)`,
it will call the inner function with `my_other_function(b = 3)`.

"""
function remove_kw(to_remove::Symbol, kwrds)
    kwrds_dict = Dict(kwrds)
    if haskey(kwrds_dict, to_remove)
        delete!(kwrds_dict, to_remove)
    end
    return (; kwrds_dict...)
end


"""
    germanshapes(level::Int64)

Returns the `Shapefile.Table` object read from the respective shapefile.
Downloads the file if it is not already locally available.
Lookup `constants.jl` to find remote location of the shapefile.
The `level` argument defines wether the state- (`level = 1`),
county- (`level = 2`) or municipality- (`level = 3`) shapes are returned.

# Returns

`Shapefile.Table{Union{Missing, Shapefile.Polygon}}`: Shapefile data.
    Lookup `Shapefile.jl` package for documentation.

"""
function germanshapes(level::Int64)
    # check if level is between 1 and 3
    !(1 <= level <= 3) ? throw("The level must be either 1 (States), 2 (Counties), or 3 (Municipalities)") : nothing
    
    lookups = Dict(1 => "LAN", 2 => "KRS", 3 => "GEM")
    filename = GERMAN_SHAPEFILE(lookups[level])

    # return shapefile if its locally available
    if isfile(filename)
        return(Shapefile.Table(filename))
    end

    # download shapefile
    printinfo("German shapefile not available locally. Downloading files...")
    
    zipath = joinpath(TEMP_FOLDER_PATH, "shapefile.zip")
    
    # make sure directory exists
    mkpath(dirname(zipath))
    
    # download stuff
    try 
        urldownload(GERMAN_SHAPEFILE_URL, true;
            compress = :none,
            parser = x -> nothing,
            save_raw = zipath)
        printinfo("Unpacking ZIP file")
    catch e
        msg = "Data could not be downloaded. Are you sure the data is available at $GERMAN_SHAPEFILE_URL? "
        msg *= "Is there a firewall preventing automatic downloads? "
        msg *= "Try downloading the files manually and extract the ZIP-folder into $SHAPEFILE_FOLDER_PATH"
        throw(msg)
    end

    # unzip
    z = ZipFile.Reader(zipath)
    for f in z.files
        #println(f)
        # Determine the output file path
        out_path = joinpath(SHAPEFILE_FOLDER_PATH, f.name)
        
        # Ensure that the output directory exists
        mkpath(dirname(out_path))
        
        if !(isdir(out_path))
            # Open the output file for writing
            open(out_path, "w") do io
                # Write the uncompressed data to the output file
                write(io, read(f))
            end
        end
    end

    # Close the ZIP archive to free resources
    close(z)

    # remove temporary zipfile
    rm(zipath, force = true)

    # return shapefile
    return(Shapefile.Table(filename))
end

"""
    state_data()

Returns a dataframe with AGS and string-names of German states.
"""
function state_data()
    return germanshapes(1) |>
        shps -> DataFrame(ags = AGS.(shps.AGS_0), gen = shps.GEN) |>
        df -> groupby(df, :ags) |>
        df -> combine(df, :gen => first => :gen)
end


"""
    county_data()

Returns a dataframe with AGS and string-names of German counties.
"""
function county_data()
    return germanshapes(2) |>
        shps -> DataFrame(ags = AGS.(shps.AGS_0), gen = shps.GEN) |>
        df -> groupby(df, :ags) |>
        df -> combine(df, :gen => first => :gen)
end


"""
    municipality_data()

Returns a dataframe with AGS and string-names of German municipalities.
"""
function municipality_data()
    return germanshapes(3) |>
        shps -> DataFrame(ags = AGS.(shps.AGS_0), gen = shps.GEN) |>
        df -> groupby(df, :ags) |>
        df -> combine(df, :gen => first => :gen)
end

"""
    gemscolors(l::Int64)

Returns the GEMS ColorScheme for plots.
The `l` parameter defines the number of colors you would like to get in your scheme.
"""
function gemscolors(l::Int64)
    if l <= 0
        return []
    end

    if l <= 2
        return palette(:auto, l)
    end

    if l <= 9
        tab10 = [palette(:tab10)...]
        return [gemscolors(2)..., tab10[4:(1+l)]...]
    end

    return [gemscolors(9)..., palette(:darktest, l-9)...]
end