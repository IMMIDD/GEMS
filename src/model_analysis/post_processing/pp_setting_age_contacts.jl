export setting_age_contacts

"""
    setting_age_contacts(postProcessor::PostProcessor, settingtype::Type{T}) where {T <: Setting}

Returns an age X age matrix containing sampled contacts for a provided settingtype T (i.e. Households)

# Returns

- `Matrix{Int32}`: Sampled contacts in age-age matrix

"""
function setting_age_contacts(postProcessor::PostProcessor, settingtype::Type{T}) where {T <: Setting}

    # sample contacts for analysis
    df = contact_samples(postProcessor |> simulation, settingtype, false)

    # build age x age contact matrix
    mx = max((postProcessor |> simulation |> population |> maxage), 0)
    co_age = zeros(Int32, mx+1, mx+1)

    a_id_col = df.a_id::Vector{Int32}
    b_id_col = df.b_id::Vector{Int32}
    a_age_col = df.a_age::Vector{Int8}
    b_age_col = df.b_age::Vector{Int8}

    for x in 1:nrow(df)
        if a_id_col[x] != b_id_col[x]
            # (Optional minor optimization) adding Int32(1) instead of standard Int64 1 
            # prevents the compiler from having to promote and then demote the integer
            co_age[a_age_col[x]+1, b_age_col[x]+1] += Int32(1)
        end
    end

    return co_age
end