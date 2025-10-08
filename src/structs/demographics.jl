export BirthdayGenerator, BirthModel

"""
A struct to hold pre-computed birth probability data
"""
struct BirthdayGenerator
    cum_probs_dict::Dict{Tuple{Int, String}, Vector{Float64}}
    available_years::Vector{Int}
end

"""
Holds birth data for direct lookup and tracks the latest available year for fallback.
"""
struct BirthModel
    lookup_data::Dict{Tuple{Int, Int}, Float64} # Stores (Year, Month) -> Daily Births
    latest_available_year::Int
end


"""
    BirthdayGenerator(data_path::String)

Constructor for the BirthdayGenerator. Reads birth data from a CSV and
pre-computes all cumulative probabilities.
"""
function BirthdayGenerator(data_path::String)
    data = CSV.read(data_path, DataFrame)
    
    cum_probs_dict = Dict{Tuple{Int, String}, Vector{Float64}}()
    years = unique(data.year)

    for year in years
        df_year = filter(row -> row.year == year, data)
        for sex in ["male", "female"]
            counts = (sex == "male") ? df_year."total_male" : df_year."total_female"
            
            # Normalize and compute cumulative probabilities
            probs = counts ./ sum(counts)
            cum_probs = cumsum(probs)
            cum_probs_dict[(year, sex)] = cum_probs
        end
    end
    
    return BirthdayGenerator(cum_probs_dict, years)
end

"""
    BirthModel(data_path::String)

Loads birth data, prepares it for direct lookup, and finds the latest year
in the dataset to use as a fallback.
"""
function BirthModel(data_path::String)
    df = CSV.read(data_path, DataFrame)
    sort!(df, [:year, :month])

    lookup = Dict{Tuple{Int, Int}, Float64}()
    for row in eachrow(df)
        year, month = row.year, row.month
        days_in_month = daysinmonth(Date(year, month))
        daily_births = (row.total_male + row.total_female) / days_in_month
        lookup[(year, month)] = daily_births
    end

    latest_year = maximum(filter(row -> row.month == 12, df).year)

    return BirthModel(lookup, latest_year)
end