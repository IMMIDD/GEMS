# ANALYSE THE IMPLICIT CONTACT STRUCTURE IN SPECIFIC SETTINGTYPES
export contact_samples

"""
    contact_samples(simulation::Simulation, settingtype::DataType, include_non_contacts::Bool)::DataFrame

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
function contact_samples(simulation::Simulation, settingtype::DataType; include_non_contacts::Bool)::DataFrame
    stngs = settings(simulation, settingtype)

    # set up contact dataframe with empty columns. Each row will be added at runtime.
    df = DataFrame(
        a_id = Vector{Int32}(undef, CONTACT_SAMPLES),
        a_age = Vector{Int8}(undef, CONTACT_SAMPLES),
        a_sex = Vector{Int8}(undef, CONTACT_SAMPLES),
        b_id = Vector{Int32}(undef, CONTACT_SAMPLES),
        b_age = Vector{Int8}(undef, CONTACT_SAMPLES),
        b_sex = Vector{Int8}(undef, CONTACT_SAMPLES),
        settingtype = Vector{DataType}(undef, CONTACT_SAMPLES)
    )

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

    cnt = 1

    # counter how many iterations of the loop where performed
    loop_cnt = 0

    # fill data frame with sample contacts
    while cnt <= CONTACT_SAMPLES
        
        loop_cnt += 1
        
        # end loop after trying "GEMS.CONTACT_SAMPLES" many times
        if cnt <= 1 && loop_cnt > GEMS.CONTACT_SAMPLES

            # return empty df, if there are no contacts until now
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
        
        s = stngs[rand(rng(simulation), 1:length(stngs))]
        present_inds = present_individuals(s, simulation)

        # jump to next iteration if there are not individuals present
        if isempty(present_inds) continue end

        ind = present_inds[rand(rng(simulation), 1:length(present_inds))]

        # sample contacts for an individual based on the individuals present in the setting at the current tick
        contacts = sample_contacts(s.contact_sampling_method, s, ind, present_inds, tick(simulation), rng=rng(simulation))

        if length(contacts) > 0
            for contact in contacts
                # add a row with information about "ego" and "contact" to the df
                if cnt <= CONTACT_SAMPLES
                    df[cnt, :] = [
                        id(ind),
                        age(ind),
                        sex(ind),
                        id(contact),
                        age(contact),
                        sex(contact),
                        settingtype
                    ]
                    cnt += 1
                end
            end
        end

        if include_non_contacts && (length(contacts) == 0) && (cnt <= CONTACT_SAMPLES)
            df[cnt, :] = [
                id(ind),
                age(ind),
                sex(ind),
                Int32(-1),
                Int8(-1),
                Int8(-1),
                settingtype
            ]
            cnt += 1
        end
        
    end

    # filter for non-self-contacts
    return(df[(df.a_id .!= df.b_id), :])
end