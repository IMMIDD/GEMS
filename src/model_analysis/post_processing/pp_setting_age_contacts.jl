export setting_age_contacts

"""
    setting_age_contacts(postProcessor::PostProcessor, settingtype::DataType)

Returns an age X age matrix containing sampled contacts for a provided `settingtype` (i.e. Households)

# Returns

- `Matrix{Int32}`: Sampled contacts in age-age matrix

"""
function setting_age_contacts(postProcessor::PostProcessor, settingtype::DataType)

    # sample contacts for analysis
    df = contact_samples(postProcessor |> simulation, settingtype, include_non_contacts = false)

    # build age x age contact matrix
    mx = maximum([postProcessor |> simulation |> population |> maxage, 0])
    co_age = zeros(Int32, mx+1, mx+1)

    for x in 1:nrow(df)
        if df.a_id[x] != df.b_id[x]
            co_age[df.a_age[x]+1,df.b_age[x]+1] += 1
        end
    end

    return co_age
end