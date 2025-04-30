export AbstractSection, Section, PlotSection
export title, title!, subtitle, subtitle!, content, content!, subsections
export plt, plotpackage
export generate

### SECTION STRUCTS
#=
    Reports consist of sections (AbstractSection struct).
    Sections can either be text sections (Section struct)
    or plot sections (PlotSection struct). Text sections
    can be nested.
=#
"Supetype for all report sections"
abstract type AbstractSection end

"Supertype for all section builders"
abstract type SectionBuilder end

"""
    Section(title::String = "", content::String = "", subsections::Vector{AbstractSection} = [])
    Section(rd::ResultData, type::Symbol)
    Section(rd::BatchData, type::Symbol)

A type for Report Sections. All reports consist of
(nested) sections. A report section will be parsed
into a markdown section (indicated by "#"s) during
report generation. Each section must have a `title`
and `content`. It can have an arbitrary number of
`subsections`.

# Example

This code creates two sections. The first one having a title
and some content. The second section contains the first 
secion as a subsection.

```Julia
sec_1 = Section(
    title = "My Section Title",
    content = "Great section contents"
)

sec_2 = Section(
    title = "My Second Section
    subsections = [sec_1]
)
```

# Defaut Sections

There are a number of default sections that you can simply
plug into your report by calling the `Section()` constructor
and pass a `ResultData` or `BatchData` object and a `Symbol`
qualifying the type of section you'd like to get:

```Julia
# run simulation
sim = Simulation()
run!(sim)
rd = ResultData(sim)

overview_section = Section(rd, :Overview)
```

## Default Sections for Single Simulation Reports

*Input must be `ResultData`.*

| Type             | Title               | Content                                                                             |
| :--------------- | :------------------ | :---------------------------------------------------------------------------------- |
| `:Debug`         | Debug Information   | Contains `:Memory`, `:Processor`,`:Repo`, and `:System` section.                    |
| `:General`       | General             | Geeral simulation info; tick unit, start conditions, and others.                    |
| `:InputFiles`    | Input Files         | Config- and population file paths.                                                  |
| `:Interventions` | Interventions       | Triggers, strategies, and measures.                                                 |
| `:Memory`        | Memory              | Available and used system memory.                                                   |
| `:Model`         | Model Configuration | Contains `:InputFiles`, `:Interventions`, `:General`, `:Pathogens`, and `:Settings` |                                            |
| `:Observations`  | Observations        | Summary of observed progression, detection rate, dark figure, and others.           |
| `:Overview`      | Overview            | Simulation summmary with initial infections, total attack rate, and others.         |
| `:Pathogens`     | Pathogens           | Pathogen configuration with one subsection per pathogen.                            |
| `:Processor`     | Processor           | Processor model, cores, and others.                                                 |
| `:Repo`          | Repository          | Current repo-, branch- and commit-ID.                                               |
| `:Settings`      | Settings            | Number of settings per type and min, max, average number of individuals.            |
| `:System`        | System Information  | Julia config, number of threads, and others.                                        |

## Default Sections for Batch Reports

*Input must be `BatchData`.*

| Type             | Title               | Content                                                                             |
| :--------------- | :------------------ | :---------------------------------------------------------------------------------- |
| `:Allocations`   | Allocations         | Summary statistics on memory usage across simulation runs in `BatchData` object.    |
| `:Debug`         | Debug Information   | Contains `:Memory`, `:Processor`,`:Repo`, and `:System` section.                    |
| `:General`       | Genera              | Geeral simulation info; tick unit, start conditions, and others.                    |
| `:Memory`        | Memory              | Available and used system memory.                                                   |
| `:Overview`      | Overview            | Summary statistics on total infections, attack rates, and others.                   |
| `:Processor`     | Processor           | Processor model, cores, and others.                                                 |
| `:Repo`          | Repository          | Current repo-, branch- and commit-ID.                                               |
| `:Resouces`      | Resources           | Contains `:Runtime` and `:Allocations` sections.                                    |
| `:Runtime`       | Runtime             | Summary statistics on runtime across simulation runs in `BatchData` object.         |
| `:Settings`      | Settings            | Number of settings per type and min, max, average number of individuals.            |
| `:System`        | System Information  | Julia config, number of threads, and others.                                        |

"""
@with_kw mutable struct Section <: AbstractSection

    title::String = ""
    content::AbstractString = ""

    subsections::Vector{AbstractSection} = Vector{AbstractSection}()
    
end

"""
    title(section::Section)

Returns a section's title.
"""
function title(section::Section)
    return(section.title)
end

"""
    title!(section::Section, title::String)

Sets a section's title.
"""
function title!(section::Section, title::String)
    section.title = title
end

"""
    content(section::Section)

Returns a section's content.
"""
function content(section::Section)
    return(section.content)
end

"""
    content!(section::Section, content::String)

Sets a section's content.
"""
function content!(section::Section, content::String)
    section.content = content
end

"""
    subsections(section::Section)

Returns a section's array of subsections.
"""
function subsections(section::Section)
    return(section.subsections)
end

"""
    addsection!(section::Section, subsection::AbstractSection)

Adds a `subsection` to a provided `section`.
"""
function addsection!(section::Section, subsection::AbstractSection)
    push!(section.subsections, subsection)
end

"""
    addsection!(section::Section, subsections::Vector)

Adds multiple `subsection` to a provided `section`.
"""
function addsection!(section::Section, subsections::Vector)
    for sec in subsections
        addsection!(section, sec)
    end
end


"""
    PlotSection <: AbstractSection

This type wraps a `ReportPlot` into an `AbstractSection`
struct. Thus the only field is a report plot. Its mainly used
to add plots to reports. You can look up the aviailable default
report styles to get an idea how that might look like.

You can either pass an instance of a `SimulationPlot` to the constructor like:

```julia
PlotSection(TickCases())
```

or pass the `SimulationPlot` type as a `Symbol` like:

```julia
PlotSection(:TickCases)
```

The `gemsplot()` function contains a comprehensive list on the
available plot types.
"""
mutable struct PlotSection <: AbstractSection
    
    plt::ReportPlot

end

# unifying usage with gemsplot typing
function PlotSection(type::Symbol)
    !is_subtype(type, SimulationPlot) ? throw("There's no plot type that matches $type") : nothing

    plt = try 
        # instantiate plot
        # we go via the subtypes function as it evaluates the "known"
        # subtypes at runtime, not compilation time. This allows
        # to also add user-defined plots.
        get_subtype(type, SimulationPlot)()
    catch
        # throws exception if the plot type doesn't have a 0-argument constructor
        throw("$type cannot be used via PlotSection(:$type), please intantiate the object with its required arguments instead, like: PlotSection($type(args...))")
    end

    return PlotSection(plt)
end


"""
    plt(section::PlotSection)

Return the nested `ReportPlot` from a `PlotSection` object.
"""
function plt(section::PlotSection)
    return(section.plt)
end

"""
    plotpackage(ps::PlotSection)

This function is local to the report.jl script. It extracts the
plotting package a PlotSection relies on (:plots, :vega, :gmt, etc...).
This information is used to parallelize plot generation.
It will return :other, if to package information is available 
in the Plot struct.
"""
function plotpackage(ps::PlotSection)
    try 
        return ps.plt.package
    catch
        return :other
    end
end

###
### SECTION GENERATORS
###

function generate_title(section::Section, depth::Int64)
    return repeat("#", depth) * " " * title(section) * "\n\n"  
end

function generate_title(section::PlotSection, depth::Int64)
    return repeat("#", depth) * " " * (section |> plt |> title) * "\n\n"   
end

function generate_content(section::Section, rd::AbstractResultData, directory::AbstractString)
    return content(section) * "\n\n" 
end

function generate_content(section::PlotSection, rd::AbstractResultData, directory::AbstractString)
    
    res = ""
    typewarning = false

    try
        # generate plot
        resultplot = generate(section |> plt, rd)
        typewarning = resultplot |> typeof |> parentmodule |> string != section |> plotpackage |> string && section |> plotpackage != :other

        # export PNG
        PATH = directory * "/img/";
        saveplot(resultplot, PATH * filename(section |> plt))

        res *= "![$(title(section |> plt))](./img/$(filename(section |> plt))){ width=75% }\n\n" *
            description(section |> plt) * "\n\n"

    catch e
        res *= "**ERROR: UNABLE TO GENERATE THIS PLOT**\n\n$e"
    end

    if typewarning && PARALLEL_REPORT_GENERATION
        @warn "The plot generated by $(section |> plt |> typeof) is not consistent with the orgin package information provided in the struct definition ($(section |> plotpackage)). This might cause the parallel report generation to crash."
    end

    return(res)
end

"""
    generate(section::Section, depth::Int64, rd::AbstractResultData, directory::AbstractString)

Generates markdown string from a `Section` object including its
nested subsections. The `depth` parameter controls the number
of leading "#"s before the title. A `directory` must be provided
in case subsections generate images that will be stored outside
of the report.
"""
function generate(section::Section, depth::Int64, rd::AbstractResultData, directory::AbstractString)
    
    @info "\r$(subinfo(section |> title))" # console info outpupt
    
    res  = generate_title(section, depth)  
    @suppress res *= generate_content(section, rd, directory)

    for s in subsections(section)
        res *= generate(s, depth + 1, rd, directory) * "\n\n"
    end

    return(res)
end

"""
    generate(section::PlotSection, depth::Int64, rd::AbstractResultData, directory::AbstractString)

Generates markdown string from a `PlotSection` object.
The `depth` parameter controls the number of leading "#"s before
the title. A `directory` must be provided as the generated 
images (of the plots) will be stored outside of the report
in dedicated "/img" folder.
"""
function generate(section::PlotSection, depth::Int64, rd::AbstractResultData, directory::AbstractString)
    
    @info "\r$(subinfo(section |> plt |> title))" # console info outpupt

    # content function genertes title so must be run in advance
    plotcontent = @suppress generate_content(section, rd, directory)

    # markdown title
    res  = generate_title(section, depth)   
    res *= plotcontent

    return(res)

end

"""
    generate(section::AbstractSection, rd::AbstractResultData, directory::AbstractString)

Generates markdown string from an `AbstractSection` object including its
potential nested subsections starting from depth 1 (one leading "#" for titles).
A `directory` must be provided in case subsections generate images
that will be stored outside of the report.
"""
function generate(section::AbstractSection, rd::AbstractResultData, directory::AbstractString)
    return(generate(section, 1, rd, directory))
end


function flatten_sections(section::AbstractSection, depth::Int)
    flat_list = Any[(section, depth)]
    if hasfield(typeof(section), :subsections)
        for subsection in section.subsections
            append!(flat_list, flatten_sections(subsection, depth + 1))
        end
    end
    return flat_list
end


###
### SECTION BUILDERS (pre-defined Sections)
###

###
### "empty" structs to dispatch to the right section builder
### None of this is exported. If you want to add a new default
### section, add a new custom struct and set up a Simulation()
### function that takes the Type{::YourNewType} as the second
### argument.
###

struct sec_Allocations <: SectionBuilder end
struct sec_BatchInfo <: SectionBuilder end
struct sec_Debug <: SectionBuilder end
struct sec_General <: SectionBuilder end
struct sec_InputFiles <: SectionBuilder end
struct sec_Interventions <: SectionBuilder end
struct sec_Memory <: SectionBuilder end
struct sec_Model <: SectionBuilder end
struct sec_Observations <: SectionBuilder end
struct sec_Overview <: SectionBuilder end
struct sec_Repo <: SectionBuilder end
struct sec_Resources <: SectionBuilder end
struct sec_Runtime <: SectionBuilder end
struct sec_Pathogens <: SectionBuilder end
struct sec_Processor <: SectionBuilder end
struct sec_Settings <: SectionBuilder end
struct sec_System <: SectionBuilder end


# this function ogranizes the dispatching depending on the provided symbol
function Section(data::Union{ResultData, BatchData}, type::Symbol)
     
    dtype = try
         eval(Symbol("sec_$type"))
    catch
        throw("There is no default report section called $type.")
    end

    return Section(data, dtype)

end



################### COMMON ResultData & BatchData SECTIONS ###################

# REPOSITORY
function Section(data::Union{ResultData, BatchData}, ::Type{sec_Repo})
    return Section(
        title = "Repository",
        content = "" * 
            "| Repository Property              | Value                                               |\n" *
            "| -------------------------------- | --------------------------------------------------- |\n" *
            "| Origin Repository                | $(data |> git_repo)                                 |\n" *
            "| Branch                           | $(data |> git_branch)                               |\n" *
            "| Commit ID                        | $(data |> git_commit)                               |\n" *
            "Table: Repository Properties")
end

# SYSTEM INFORMATION
function Section(data::Union{ResultData, BatchData}, ::Type{sec_System})
    return Section(
        title = "System Information",
        content = "" * 
            "| System Property          | Value                                  |\n" *
            "| ------------------------ | -------------------------------------- |\n" *
            "| System Kernel            | $(data |> kernel)                      |\n" *
            "| Julia Version            | $(data |> julia_version)               |\n" *
            "| Word Size                | $(data |> word_size)                   |\n" *
            "| Julia Threads            | $(data |> threads)                     |\n" *
            "Table: General Sytem Properties")
end

# PROCESSPOR
function Section(data::Union{ResultData, BatchData}, ::Type{sec_Processor})
    return Section(
        title = "Processor",
        content = string(data |> cpu_data))
end

# MEMORY
function Section(data::Union{ResultData, BatchData}, ::Type{sec_Memory})
    return Section(
        title = "Memory",
        content = "" * 
            "| Memory Property                                        | Value                                              |\n" *
            "| :----------------------------------------------------- | :------------------------------------------------- |\n" *
            "| Total Available Memory                                 | $(format(data |> total_mem_size, commas=true)) MB  |\n" *
            "| Free Memory                                            | $(format(data |> free_mem_size, commas=true)) MB   |\n")
end

# DEBUG INFORMATION
function Section(data::Union{ResultData, BatchData}, ::Type{sec_Debug})
    return Section(
        title = "Debug Information",
        subsections = [
            Section(data, :Repo),
            Section(data, :System),
            Section(data, :Processor),
            Section(data, :Memory)])
end


################### ResultData SECTIONS ###################

# INPUT FILES
function Section(rd::ResultData, ::Type{sec_InputFiles})
    return Section(
        title = "Input Files",
        content = "" * 
            "- **Config File**: $(rd |> config_file |> x -> (x != Dict() ? escape_markdown(x) : "No configuration file specified") |> savepath)\n" *
            "- **Population File**: $(rd |> population_file |> x -> (x != Dict() ? escape_markdown(x) : "No population file specified") |> savepath)")
end

# PATHOGENS
function Section(rd::ResultData, ::Type{sec_Pathogens})

    ss = Vector{Section}()

    for p in rd |> pathogens
        push!(ss, Section(title = name(p), content = markdown(p)))
    end

    return Section(
        title = "Pathogens",
        subsections = ss)

end

# SETTINGS
function Section(rd::ResultData, ::Type{sec_Settings})

    res =  rd |> setting_data |> settingsMD
    res *= "Table: Setting Summary"

    return Section(
        title = "Settings",
        content = res
    )   
end

# GENERAL
function Section(rd::ResultData, ::Type{sec_General})
    return Section(
        title = "General",
        content = "" *
            "| Model Property        | Value                                               |\n" *
            "| :-------------------- | :-------------------------------------------------- |\n" *
            "| Tick Unit (Length)    | $(rd |> tick_unit)                                  |\n" *
            "| Start Condition       | $(markdown(rd |> start_condition))                  |\n" *
            "| Simulation Duration   | $(format(rd |> final_tick, commas=true))            |\n" *
            "| Number of Individuals | $(format(rd |> number_of_individuals, commas=true)) |\n" *
            "Table: General Sytem Properties")
end

# OVERVIEW
function Section(rd::ResultData, ::Type{sec_Overview})
    return Section(
        title = "Overview",
        content = "" *
            "| Property                | Value                                                            |\n" *
            "| ----------------------- | -----------------------------------------------------------------|\n" *
            "| Initial Infections      | $(format(rd |> initial_infections, commas=true))                 |\n" *
            "| Total Infections[^tinf] | $(format(rd |> total_infections, commas=true))                   |\n" *
            "| Attack Rate[^atr]       | $(round((rd |> attack_rate) * 100, digits = 2))%                 |\n" *
            "Table: Simulation Results Overview\n\n" *
            "[^tinf]: Initially infected individuals and infections that happened during the simulation\n\n" *
            "[^atr]: Total infections divided by number of individuals")
end

# OBSERVATIONS
function Section(rd::ResultData, ::Type{sec_Observations})
    return Section(
        title = "Observation Summary",
        content = "" *
            "| Property                   | Value                                                            |\n" *
            "| -------------------------- | -----------------------------------------------------------------|\n" *
            "| Total Detection Rate[^dtr] | $(round((rd |> detection_rate) * 100, digits = 2))%              |\n" *
            "| Total Dark Figure[^tdf]    | $(round((1 - (rd |> detection_rate)) * 100, digits = 2))%        |\n" *
            "Table: Observed Simulation Results Overview\n\n" *
            "[^dtr]: Total of detected infections divided by total number of infections\n\n" *
            "[^tdf]: Total of un-detected infections divided by total number of infections")
end

# INTERVENTIONS
function Section(rd::ResultData, ::Type{sec_Interventions})

    if rd |> strategies |> isempty
        return Section(
            title = "Interventions",
            content = "The ResultData object used to construct this report does not contain intervention data.")
    end

    return Section(
        title = "Interventions",
        subsections = [
            Section(title = "Strategies",
                subsections = [Section(title = "Strategy: _" * name(s) * "_", content = markdown(s)) for s in rd |> strategies]),
            Section(title = "Triggers",
                content =
                    "Symptoms will trigger the following strategies: _" * markdown([st |> strategy |> name for st in rd |> symptom_triggers]) * "_"), 
            Section(title = "Testing",
                content = rd |> testtypes |> length > 0 ? rd |> testtypes |> markdown : "No Test Types defined")  ])
end

# MODEL
function Section(rd::ResultData, ::Type{sec_Model})

    return(
        Section(title = "Model Configuration",
            subsections = [
                Section(rd, :InputFiles),
                Section(rd, :General),
                Section(rd, :Pathogens),
                Section(rd, :Settings),
                Section(rd, :Interventions)
    ]))
end




################### BatchData SECTIONS ###################

# BATCH INFO
function Section(bd::BatchData, ::Type{sec_BatchInfo})
    return Section(
        title = "Batch Information",
        content = "" *
            "| Property         | Value                     |\n" *
            "| ---------------- | ------------------------- |\n" *
            "| Batch ID         | $(bd |> id)               |\n" *
            "| Number of runs   | $(bd |> number_of_runs)   |\n" *
            "Table: Batch Information")
end

# OVERVIEW
function Section(bd::BatchData, ::Type{sec_Overview})
    return Section(
        title = "Overview",
        content = "" *
            "| Property           | Value                                                            |\n" *
            "| ------------------ | -----------------------------------------------------------------|\n" *
            "| Total Infections   | $(print_aggregates(bd |> total_infections, digits=1))            |\n" *
            "| Attack Rate[^atr]  | $(print_aggregates(bd |> attack_rate, multiplier=100, unit="%")) |\n" *
            "Table: Simulation Results Overview\n\n" *
            "[^atr]: Total infections divided by number of individuals")
end


# RUNTIME
function Section(bd::BatchData, ::Type{sec_Runtime})
    if bd |> runtime |> length == 0
        cnt = "No timer available. (Note: This data is only available if the simulation runs were done via the `main()` function)"
        return(Section(title = "Runtime", content = cnt))   
    end

    # runtime table
    rnt = ""*
        "| Task | Runtime        |\n" *
        "| ---- | -------------- |\n"

    for nm in bd |> runtime |> keys |> collect |> sort
        rnt *= "| $nm | $(print_aggregates((bd |> runtime)[nm], unit = "s", multiplier = 1/1_000_000_000, digits = 2)) |\n"
    end
    rnt *= "Table: Batch Runtimes"

    return(Section(title = "Runtime", content = rnt))
end

# ALLOCATIONS
function Section(bd::BatchData, ::Type{sec_Allocations})
    if bd |> allocations |> length == 0
        cnt = "No timer available. (Note: This data is only available if the simulation runs were done via the `main()` function)"
        return(Section(title = "Allocations", content = cnt))   
    end

    # allocations table
    allc = ""*
        "| Task | Allocations    |\n" *
        "| ---- | -------------- |\n"

    for nm in bd |> allocations |> keys |> collect |> sort
        allc *= "| $nm | $(print_aggregates((bd |> allocations)[nm], unit = "MB", multiplier = 1/1_000_000, digits = 2)) |\n"
    end
    allc *= "Table: Batch Runtimes"

    return(Section(title = "Allocations", content = allc))
end

# RESOURCES
function Section(bd::BatchData, ::Type{sec_Resources})
    return Section(
        title = "Resources",
        subsections = [
            Section(bd, :Runtime),
            Section(bd, :Allocations)
        ])
end