# CREATION OF MARKDOWN CODE FOR THE REPORT
export escape_markdown, markdown, settingsMD
export savepath

###
### ESCAPING STRINGS
###

"""
    escape_markdown(str::String)

Replaces markdown controls (e.g. "_" or "*") with their escaped version.
"""
function escape_markdown(str::String)
    # replace low-dashes
    res = replace(str, "_" => "\\_")
    # replace italics/bolds
    res = replace(res, "*" => "\\*")
    # replace colons
    res = replace(res, ":" => "\\:")

    return(res)
end

"""
    savepath(str::String)

Replaces all backslashes in a path-string with forward slashes 
to prevent weaving issues while generating TeX-PDFs as backslashes
indicate control structures in TeX.
"""
function savepath(str::String)
   str |>
    x -> replace(x, "\\\\" => "/") |>
    x -> replace(x, "\\" => "/")
end


function print_arr(arr)
    if arr |> length <= 0
        return("")
    elseif arr |> length == 1
        return(arr[1])
    else
        res = "[$(arr[1])"
        for i in 2:length(arr)
            res *= ", $(arr[i])"
        end
        res *= "]"
        return(res)
    end
end

###
### MARKDOWN CONVERSION
###

# fallback
function markdown(par::Any)
    return(
        "There's no markdown function implemented for $(par |> typeof |> string) objects."
    )
end

function markdown(arr::Vector{T}) where T<:Real
    return(
        map(x -> format(x, commas=true), arr) |> print_arr
    )
end

function markdown(arr::Vector{T}) where T<:String
    return(arr |> print_arr)
end


# Simulation Objects
"""
    markdown(infFrac::InfectedFraction)

Returns a markdown string with all parameters (mainly for documentation purposes).
"""
function markdown(infFrac::InfectedFraction)
    percent = fraction(infFrac)*100

    res = "$percent % of the population randomly drawn and infected."
    return(res)
end

"""
    markdown(tu::TimesUp)

Returns a markdown string with all parameters (mainly for documentation purposes).
"""
function markdown(tu::TimesUp)
    lim = limit(tu)
    res = "Simulation terminates after $(format(lim, commas=true)) ticks"
    return(res)
end


# FALLBACK
function markdown(arr::Vector{T}) where T<:Any
    return(
        map(markdown, arr) |> unique |> print_arr
    )
end

function markdown(arr::Vector{T}) where T<:StartCondition
    return(
        map(markdown, arr) |> unique |> print_arr
    )
end

function markdown(arr::Vector{T}) where T<:StopCriterion
    return(
        map(markdown, arr) |> unique |> print_arr
    )
end



"""
    markdown(pathogen::Pathogen)

Returns a markdown string with all parameters (mainly for documentation purposes).
"""
function markdown(pathogen::Pathogen)
    # encapsule in array to use function that dispatches on arrays 
    # (to not have basically the same function twice)
    return([pathogen] |> markdown)
end


function markdown(arr::Vector{Pathogen})

    if arr |> Base.isempty
        return ""
    end

    # read name
    nm = arr[1] |> name

#     res =  "

# | Pathogen Property                     | Value                                            |
# | :------------------------------------ | :----------------------------------------------- |
# | Name                                  | $nm                                              |
# | Infection Rate                        | $(map(infection_rate, arr) |> markdown)          |
# | Death Rate (Mild Cases)               | $(map(mild_death_rate, arr) |> markdown)         |
# | Death Rate (Severe Cases)             | $(map(severe_death_rate, arr) |> markdown)       |
# | Death Rate (Critical Cases)           | $(map(critical_death_rate, arr) |> markdown)     |
# | Hospitalization Rate (Severe Cases)   | $(map(hospitalization_rate, arr) |> markdown)    |
# | Ventilation Rate (Critical Cases)     | $(map(ventilation_rate, arr) |> markdown)        |
# | ICU Rate (Critical Cases)             | $(map(icu_rate, arr) |> markdown)                |
# | Onset of symptoms[^time]              | $(map(onset_of_symptoms, arr) |> markdown)       |
# | Infectious Offset[^offset]            | $(map(infectious_offset, arr) |> markdown)       |
# | Time to Recovery[^increment1]         | $(map(time_to_recovery, arr) |> markdown)        |
# | Onset of severe symptoms[^increment1] | $(map(onset_of_severeness, arr) |> markdown)     |
# | Time to hospitalization[^increment1]  | $(map(time_to_hospitalization, arr) |> markdown) |
# | Time to ICU[^increment2]              | $(map(time_to_icu, arr) |> markdown)             |
# | Length of stay[^increment2]           | $(map(length_of_stay, arr) |> markdown)          |
# Table: Pathogen **$nm** Configuration

# [^time]: The unit of all time-related parameters are _ticks_.
# [^offset]: The infectious offset describes how many ticks an individual is infectious before having symptoms.
# [^increment1]: This is defined as an increment to the onset of symptoms.
# [^increment2]: This is defined as an increment to the time of hospitalization.
# "

    res = "Pathogen $nm, printing of parameters needs to be implemented."

    return(res)
end


# Distributions
"""
    markdown(unDist::Uniform)

Returns a markdown string with all parameters (mainly for documentation purposes).
"""
function markdown(unDist::Uniform)
    return("Uniform distribution ranging from $(unDist.a) to $(unDist.b)")
end

"""
    markdown(poisDist::Poisson)

Returns a markdown string with all parameters (mainly for documentation purposes).
"""
function markdown(poisDist::Poisson)
    return("Poisson distribution with \$\\lambda\$ = $(poisDist.λ)")
end


"""
    markdown(binDist::Binomial)

Returns a markdown string with all parameters (mainly for documentation purposes).
"""
function markdown(binDist::Binomial)
    return("Binomial distribution with n = $(binDist.n) trials and a p = $(binDist.p) success rate")
end


"""
    markdown(dist::Distribution)

Return a markdown string with all parameters (mainly for documentation purposes).
Fallback function for arbitrary distributions without dedicated formatting.
"""
function markdown(dist::Distribution)

    return(
        "$(typeof(dist)) distribution with"*
        string([" $field = $(getfield(dist, field))," for field in fieldnames(typeof(dist))]...)[1:end-1]*
        "."
    )
end

# Settings
"""
    markdown(stngs::SettingsContainer, sim::Simulation)

Returns a markdown string with all parameters (mainly for documentation purposes).
"""
function markdown(stngs::SettingsContainer, sim::Simulation)

    res =  "| Setting | Number | Min. Individuals | Max. Individuals | Avg. Individuals |\n"
    res *= "| :------ | -----: | ---------------: | ---------------: | ---------------: |\n"

    for (type, sets) in settings(stngs)

        name = string(type)
        cnt = length(sets)
        min = min_individuals(sets, sim)
        max = max_individuals(sets, sim)
        avg = avg_individuals(sets, sim)
        
        res *= "| $name | $(format(cnt, commas=true)) | $(!isnothing(min) ? format(min, commas=true) : "-") | $(!isnothing(max) ? format(max, commas=true) : "-") | $(!isnothing(avg) ? format(avg, commas=true) : "-") |\n"
    end

    res *= "Table: Setting Summary"

    return(res)
end

function settingsMD(settingdata::DataFrame)
   
    res =  "| Setting | Number | Min. Individuals | Max. Individuals | Avg. Individuals |\n"
    res *= "| :------ | -----: | ---------------: | ---------------: | ---------------: |\n"

    for row in eachrow(settingdata)
        
        stype = row.setting_type
        cnt = row.number_of_settings
        min = row.min_individuals
        max = row.max_individuals
        avg = row.avg_individuals

        res *= "| $stype | $(format(cnt, commas=true)) | $(min > 0 ? format(min, commas=true) : "-") | $(max > 0 ? format(max, commas=true) : "-") | $(avg > 0 ? format(avg, commas=true) : "-") |\n"
    end

    return(res)
end


function markdown(vaccine::Vaccine)
    return(
        "| Property | Value                            |\n" *
        "| -------- | -------------------------------- |\n" *
        "| Name     | $(vaccine |> name)               |\n"
    )
end

function markdown(scheduler::VaccinationScheduler)
    return(
        "To be implemented."
    ) 
end


function markdown(strategy::Strategy)
    
    res =
        "| Time | Type        | Measure                | Parameters                                        |\n" *
        "| ---- | ------------| ---------------------- | ---------------------------------- |\n"

    for me in strategy |> measures

        time = string(offset(me))
        msupertype = "Unknown"
        msupertype = typeof(me.measure) <: IMeasure ? "IMeasure" : msupertype
        msupertype = typeof(me.measure) <: SMeasure ? "SMeasure" : msupertype
        mtype = string(typeof(me.measure))

        res *= "| $time | $msupertype | $mtype | "

        # MEASURE PARAMETERS
        for f in me.measure |> typeof |> fieldnames
            # field name
            res *= escape_markdown(string(f)) * ": "

            # field value
            fval = getfield(me.measure, f)

            try 
                res *= escape_markdown(name(fval))
            catch
                try
                    res *= escape_markdown(id(fval))
                catch

                    res *= escape_markdown(string(fval))
                end
            end

            res *= "; "
        end

        res *= "|\n"
    end

    res *= "Table: $(strategy |> name) Strategy"
    
    return(res)
end


function markdown(ttypes::Vector{AbstractTestType})

    res =
        "| Name                    | Pathogen                 | Sensitivity[^sen] |\n" *
        "| ----------------------- | ------------------------ | ----------------- |\n"

    for tt in ttypes
        res *= "| $(tt |> name) | $(tt |> pathogen |> name) | $(100 * (tt |> sensitivity))% |\n"
    end

    res *= "Table: TestTypes\n\n"

    res *= "[^sen]: The test's ability to correctly identify a positive case."

    return(res)
end