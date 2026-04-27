# ANALYSE THE IMPLICIT CONTACT STRUCTURE IN SPECIFIC SETTINGTYPES
export contact_samples

"""
    contact_samples(simulation::Simulation, settingtype::Type{T}, include_non_contacts::Bool)::DataFrame  where {T <: Setting}

Returns a dataframe with data on two individuals per row (contact).
The contacts are sampled for a provided setting type according to the 
`ContactSamplingMethod` of the desired setting. This also defines, how many contacts will be sampled per individual.
If `include_non_contacts` is `true`, also the number of "non-contacts" (individuals for which the number of sampled contacts is zero) will be included in this dataframe. In this case, `b_id`, `b_age` and `b_sex` will have the value `-1`.
The number of sampled contacts is limited by the global
`CONTACT_SAMPLES` flag in the constants.jl file. It default is `100_000`.
If you need more samples, change the flag using `GEMS.CONTACT_SAMPLES` = `your_new_int_value`.

# Columns

| Name              | Type    | Description                                       |
| :---------------- | :------ | :------------------------------------------------ |
| `a_id`            | `Int32` | Ego id                                            |
| `a_age`           | `Int8`  | Ego age                                           |
| `a_sex`           | `Int8`  | Ego sex                                           |
| `b_id`            | `Int32` | Contact id                                        |
| `b_age`           | `Int8`  | Contact age                                       |
| `b_sex`           | `Int8`  | Contact sex                                       |
| `setting_type`    | `Char`  | Setting, in which the contact occured             |

# Returns
Dataframe containing the sampled contacts for the given settingstype. 

If no settings exist for `settingtype`, an empty DataFrame with the Columns defined above is returned.

If no contacts are sampled in `GEMS.CONTACT_SAMPLES` many iterations, an empty DataFrame with the Columns defined above is returned.
"""
function contact_samples(simulation::Simulation, settingtype::Type{T}, include_non_contacts::Bool)::DataFrame where {T <: Setting}
    stngs = settings(simulation, settingtype)

    # return an empty df, if no settings for the given settingtype exist
    if isnothing(stngs) || isempty(stngs)
        return DataFrame(
            a_id = Int32[], 
            a_age = Int8[], 
            a_sex = Int8[],
            b_id = Int32[],  
            b_age = Int8[], 
            b_sex = Int8[],
            settingtype = DataType[]
        )
    end

    # set up pre-allocated output vectors
    a_id_vec = Vector{Int32}(undef, CONTACT_SAMPLES)
    a_age_vec = Vector{Int8}(undef, CONTACT_SAMPLES)
    a_sex_vec = Vector{Int8}(undef, CONTACT_SAMPLES)
    b_id_vec = Vector{Int32}(undef, CONTACT_SAMPLES)
    b_age_vec = Vector{Int8}(undef, CONTACT_SAMPLES)
    b_sex_vec = Vector{Int8}(undef, CONTACT_SAMPLES)
    settingtype_vec = Vector{DataType}(undef, CONTACT_SAMPLES)

    cnt = 1
    last_s = nothing
    present_inds = simulation.present_buffers[Threads.threadid()]
    contacts = simulation.contact_buffers[Threads.threadid()]

    # reusable batch buffer
    batch = Vector{Int}(undef, CONTACT_SAMPLES)

    while cnt <= CONTACT_SAMPLES

        # sample a batch of setting indices and sort for cache coherence
        for i in eachindex(batch)
            batch[i] = gems_rand(simulation, 1:length(stngs))
        end
        sort!(batch)

        cnt_before_batch = cnt

        for sidx in batch
            cnt > CONTACT_SAMPLES && break

            s = stngs[sidx]::T

            if s !== last_s
                empty!(present_inds)
                present_individuals!(present_inds, s, simulation)
                last_s = s
            end

            isempty(present_inds) && continue

            ind_index = gems_rand(simulation, 1:length(present_inds))
            ind = present_inds[ind_index]

            sample_contacts!(contacts, s.contact_sampling_method, s, ind_index, present_inds, tick(simulation), true, rng(simulation))

            if length(contacts) > 0
                for contact in contacts
                    cnt > CONTACT_SAMPLES && break
                    a_id_vec[cnt] = id(ind)
                    a_age_vec[cnt] = age(ind)
                    a_sex_vec[cnt] = sex(ind)
                    b_id_vec[cnt] = id(contact)
                    b_age_vec[cnt] = age(contact)
                    b_sex_vec[cnt] = sex(contact)
                    settingtype_vec[cnt] = T
                    cnt += 1
                end
            end

            if include_non_contacts && isempty(contacts) && cnt <= CONTACT_SAMPLES
                a_id_vec[cnt] = id(ind)
                a_age_vec[cnt] = age(ind)
                a_sex_vec[cnt] = sex(ind)
                b_id_vec[cnt] = Int32(-1)
                b_age_vec[cnt] = Int8(-1)
                b_sex_vec[cnt] = Int8(-1)
                settingtype_vec[cnt] = T
                cnt += 1
            end
        end

        # if the entire batch produced no new rows, return
        if cnt == cnt_before_batch
            return DataFrame(
                a_id = Int32[], 
                a_age = Int8[], 
                a_sex = Int8[],
                b_id = Int32[],  
                b_age = Int8[], 
                b_sex = Int8[],
                settingtype = DataType[]
            )
        end

    end

    valid_rows = 1:(cnt - 1)
    df = DataFrame(
        a_id = a_id_vec[valid_rows],
        a_age = a_age_vec[valid_rows],
        a_sex = a_sex_vec[valid_rows],
        b_id = b_id_vec[valid_rows],
        b_age = b_age_vec[valid_rows],
        b_sex = b_sex_vec[valid_rows],
        settingtype = settingtype_vec[valid_rows]
    )

    # filter for non-self-contacts
    return df[(df.a_id .!= df.b_id), :]
end