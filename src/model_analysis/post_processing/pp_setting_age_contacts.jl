export setting_age_contacts

"""
    setting_age_contacts(postProcessor::PostProcessor, settingtype::DataType)

Returns an age X age matrix containing sampled contacts for a provided `settingtype` (i.e. Households)

# Returns

- `Matrix{Int32}`: Sampled contacts in age-age matrix

"""
function setting_age_contacts(postProcessor::PostProcessor, settingtype::DataType)
    sim = postProcessor |> simulation
    # sample contacts for analysis
    df = contact_samples(sim, settingtype, include_non_contacts = false)
    df.a_age_years = div.(df.a_age, 365)
    df.b_age_years = div.(df.b_age, 365)

    # build age x age contact matrix
    mx_years = maximum([maxage(sim |> population, sim.startdate + Day(tick(sim))), 0]) ÷ 365
    co_age = zeros(Int32, mx_years+1, mx_years+1)

    for x in 1:nrow(df)
        if df.a_id[x] != df.b_id[x]
            co_age[df.a_age_years[x]+1, df.b_age_years[x]+1] += 1
        end
    end

    return co_age
end