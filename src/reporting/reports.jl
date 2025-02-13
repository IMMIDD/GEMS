# Find weave docs here: https://weavejl.mpastell.com/stable/
# Running this script requires a LaTeX distribution (e.g. MiKTeX) and Pandoc installed on your machine
#   https://miktex.org/download
#   https://pandoc.org/installing.html
# Installation might require a system reboot (at least on Windows)

export Report, SimulationReport, BatchReport
export title, title!, subtitle, subtitle!
export simulation, dpi, dpi!, fontfamily, fontfamily!, plt
export reportdata, batchdata, author, author!, date, date!, abstract, abstract!
export sections, glossary, glossary!, addsection!, addtimer!
export generate, buildreport
export SimulationReportStyle, BatchReportStyle

### INCLUDES
include("plots.jl")
include("maps.jl")
include("markdown.jl")
include("sections.jl")


###
### REPORT STRUCTS
###

"Supertype for all simulation reports"
abstract type Report end

"""
    dpi(report)

Returns dpi (dots per inch) from a report object.
dpi conditions the resolution of images generated for the report.
"""
function dpi(report::Report)
    return(report.dpi)
end

"""
    dpi!(report, dpi)

Setter for report dpi (dot per inch) for images.
"""
function dpi!(report::Report, dpi::Int64)
    report.dpi = dpi
end

"""
    fontfamily(report)

Returns font family config from a report object.
"""
function fontfamily(report::Report)
    return(report.fontfamily)
end

"""
    fontfamily!(report, fontfamily)

Setter for report fontfamily.
"""
function fontfamily!(report::Report, fontfamily::String)
    report.fontfamily = fontfamily
end



###
### SINGLE SIMULATION RUN REPORTS
###

"""
    SimulationReport <: Report

A Type for generating a single-run simulation report.

# Fields
## Result Data
- `rd::ResultData`: Result data object used to generate this report
## Meta Information
- `title::String`: Report title
- `subtitle::String`: Report subtitle
- `author::String`: Report authors
- `date::String`: Simulation execution date (post processing)
- `abstract::String`: Report abstract

## Configuration
- `glossary::Bool`: flag to add or remove glossary with term definitions
- `dpi::Int64`: dots per inch for report plots (default: 300)
- `fontfamily::String`: font family for report (default: Times New)
"""
@with_kw mutable struct SimulationReport <: Report

    data::Union{ResultData,BatchData}

    # Meta Information
    title::String = ""
    subtitle::String = ""
    author::String = ""
    date::String = ""
    abstract::String = ""

    sections::Vector{AbstractSection} = Vector{AbstractSection}()

    # no glossary by default, but can be switched on
    glossary::Bool = false

    # Configurations
    dpi::Int64 = 300 # dots per inch for images in report (Default: 300)
    fontfamily::String = "Times New Roman" # Font Family (Default: Times New Roman)

end

"""
    reportdata(report)

Returns the associated `ReportData` object from a `Report`.
"""
function reportdata(report::Report)
    return(report.data)
end

"""
    title(report)

Returns the title of a `Report`.
"""
function title(report::Report)
    return(report.title)
end

"""
    title!(report, title)

Sets the title of a `Report`.
"""
function title!(report::Report, title::String)
    report.title = title
end

"""
    subtitle(report)

Returns the subtitle of a `Report`.
"""
function subtitle(report::Report)
    return(report.subtitle)
end

"""
    subtitle!(report, subtitle)

Sets the subtitle of a `Report`.
"""
function subtitle!(report::Report, subtitle::String)
    report.subtitle = subtitle
end


"""
    author(report)

Returns the author of a `Report`.
"""
function author(report::Report)
    return(report.author)
end

"""
    author!(report, author)

Sets the author of a `Report`.
"""
function author!(report::Report, author::String)
    report.author = author
end

"""
    date(report)

Returns the date of a `Report`.
"""
function date(report::Report)
    return(report.date)
end

"""
    date!(report, date)

Sets the date of a `Report`.
"""
function date!(report::Report, date::String)
    report.date = date
end

"""
    abstract(report)

Returns the abstract of a `Report`.
"""
function abstract(report::Report)
    return(report.abstract)
end

"""
    abstract!(report, abstract)

setss the abstract of a `Report`.
"""
function abstract!(report::Report, abstract::String)
    report.abstract = abstract
end

"""
    sections(report)

Returns the array of sections of a `Report`.
"""
function sections(report::Report)
    return(report.sections)
end

"""
    glossary(report)

Returns the glossary flag of a `Report`.
"""
function glossary(report::Report)
    return(report.glossary)
end

"""
    glossary!(report, glossary)

Sets the glossary flag of a `Report`.
If true, the glossary will be copied into the report upon generation.
"""
function glossary!(report::Report, glossary::Bool)
    report.glossary = glossary
end

"""
    addsection!(report, section)

Adds a `Section` to a `Report`.
It can either be a regular section or a plot section.
"""
function addsection!(report::Report, section::AbstractSection)
    push!(report.sections, section)
end

"""
    addstimer!(report, timeroutput)

Generates a `Section` from the consolue output
of a `TimerOutput` object and adds it to a `SimulationReport`.
"""
function addtimer!(rep::SimulationReport, to::TimerOutput)
    addsection!(rep, Section(title = "Runtime",
        content = "```\n" *
                (@capture_out show(to, sortby = :name)) * "\n" *
                "```"
    ))
end


###
### INCLUDE REPORT STYLES
###

abstract type SimulationReportStyle end

abstract type BatchReportStyle end

# The src/reporting/styles folder contains a dedicated file
# for each SimulationReportStyle.
# If you want to set up a new style, simply add a file to the folder and 
# make sure to define the respective struct there and export it (using the export statement).

# include all Julia files from the "styles"-folder
dir = basefolder() * "/src/reporting/styles"

include.(
    filter(
        contains(r".jl$"),
        readdir(dir; join=true)
    )
)

###
### BATCH RUN REPORTS
###

"""
    BatchReport <: Report

A Type for generating a batch-run simulation report.

# Fields
## Batch Data
- `bd::BatchData`: Batch data object used to generate this report
## Meta Information
- `title::String`: Report title
- `subtitle::String`: Report subtitle
- `author::String`: Report authors
- `date::String`: Simulation execution date (post processing)
- `abstract::String`: Report abstract

## Configuration
- `glossary::Bool`: flag to add or remove glossary with term definitions
- `dpi::Int64`: dots per inch for report plots (default: 300)
- `fontfamily::String`: font family for report (default: Times New)
"""
@with_kw mutable struct BatchReport <: Report

    bd::BatchData

    # Meta Information
    title::String = ""
    subtitle::String = ""
    author::String = ""
    date::String = ""
    abstract::String = ""

    sections::Vector{AbstractSection} = Vector{AbstractSection}()

    # no glossary by default, but can be switched on
    glossary::Bool = false

    # Configurations
    dpi::Int64 = 300 # dots per inch for images in report (Default: 300)
    fontfamily::String = "Times New Roman" # Font Family (Default: Times New Roman)

end

function reportdata(batchReport::BatchReport)
    return(batchReport.bd)
end


"""
    generate(report, directory)

Generates markdown string from a `Report` object including its
nested subsections. The report will be stored as PDF, HTML, and MD
in the provided `directory`. Images are generated and stored in an "/img" subfolder. 
"""
function generate(report::Report, directory::AbstractString)
    
    rd = reportdata(report)

    # generate meta info
    res = String("---\n" *
        "title: $(title(report))\n" *
        "subtitle: $(subtitle(report))\n" *
        "author: $(author(report))\n" *
        "date: $(date(report))\n" *
        "abstract: |\n" *
        "   $(abstract(report))\n" *
        "---\n"
    )
    
    # create image directory
    PATH = directory * "/img/";
    mkpath(PATH)

    # generate sections
    if PARALLEL_REPORT_GENERATION
        # parallel report generation flattens the report sections
        # vector first to then parallelize the generation of 
        # all sections and nested sections sorted by plot type.
        # As most plotting packages have global backends, plots
        # using the same package cannot be parallelized.
        # we can, however, parallelize accross packages (Plots, Vega, GMT, etc...)

        # add all sections to a flat list
        flat_list = Any[]
        for section in report.sections
            append!(flat_list, flatten_sections(section, 1))
        end

        # add index to flat list tuples
        flat_list = [(a, b, index) for (index, (a, b)) in enumerate(flat_list)]

        # extract all "plain" sections (no plots). They can all be done in parallel
        sectns = [Any[s] for s in flat_list if isa(s[1], Section)];
        # find out how many different plot packages are being used
        plotsections = [s for s in flat_list if isa(s[1], PlotSection)]
        plotpackages = map(x -> plotpackage(x[1]), plotsections) |> unique |>
            x ->  filter(sym -> sym != :other, x)
        # generate a vector of tuples for each plotpackage
        plots = map(ppck ->    
            [s for s in flat_list if isa(s[1], PlotSection) && plotpackage(s[1]) == ppck]
            ,plotpackages);

        # filter all plotsections without package annotations
        others = [s for s in flat_list if isa(s[1], PlotSection) && plotpackage(s[1]) == :other];

        # this can be processed in parallel
        proc_par = append!(sectns, plots);
        # this is everything we don't know enough about to do it in parallel
        proc_seq = others

        # temporay result vector
        temp = Vector{String}(undef, flat_list |> length)

        @suppress begin # suppress plotting outputs
            # process parallel sections
            Threads.@threads for sec_arr in proc_par
                for sec in sec_arr
                    # third value of tuple contains position of section in result vector
                    temp[sec[3]] = "\n$(generate_title(sec[1], sec[2])) $(generate_content(sec[1], rd, directory))\n"
                end
            end

            for sec in proc_seq
                temp[sec[3]] = "\n$(generate_title(sec[1], sec[2])) $(generate_content(sec[1], rd, directory))\n"
            end
        end

        # join result array and push to final report
        res *= join(temp)
   
    # NON PARALLEL VARIANT
    else
        # non parallelized legacy report generation    
        for s in sections(report)
            res *= "\n" * generate(s, rd ,directory) * "\n"
        end
    end


    @info "\r$(subinfo("Done"))"

    # add glossary
    if glossary(report)
        BASE_FOLDER = dirname(dirname(pathof(GEMS)))
        res *= "\n" * read(BASE_FOLDER * "/docs/src/glossary.md", String)
    end

    # create directory if if not existing
    if !ispath(directory)
        mkpath(directory)
    end

    # generate markdown file
    mdfilepath = directory * "/report.md"
    open(mdfilepath, "w") do file
        write(file, res)
    end

    # generate PDF
    @suppress begin
        weave(mdfilepath; out_path = directory * "/report.pdf", doctype = "pandoc2pdf", 
        pandoc_options = 
            [
            "--toc", 
            "-f", "markdown-implicit_figures"
            ]
        )
    end
        # generate HTML
    @suppress begin
        BASE_FOLDER = dirname(dirname(pathof(GEMS)))
        weave(mdfilepath; out_path = directory * "/report.pdf", doctype = "pandoc2html",
            pandoc_options = 
            [
                "--toc",
                "--css", BASE_FOLDER * "/src/reporting/css/report_styles.css",
                "-V", "mainfont=Open Sans",
                "-f", "markdown-implicit_figures"
            ]
        )
    end
end

###
### STANDARD REPORT BUILDERS
###

"""
    buildreport(rd::ResultData, config::Dict = Dict())

Initializes and configures a simulation report with the tile, abstract, sections etc. provided in config.
If config is an empty dictionary all available standard sections, plots, and the glossary etc. will be used.
It returns a full `SimulationReport` object which can then be generated using the `generate()` function.
"""
function buildreport(data::Union{ResultData,BatchData}, style::String = "")
    # Determine the style to be used
    if isa(data, ResultData)
        type = SimulationReportStyle
    else
        type = BatchReportStyle
    end
    id = findfirst(x -> occursin(style, x), string.(concrete_subtypes(type)))
    if isnothing(id)
        style = concrete_subtypes(type)[1](data = data)
    else
        style = concrete_subtypes(type)[id](data = data)
    end

    # Create the Report struct
    
    rep = SimulationReport(data = data,
        title = style.title,
        subtitle = style.subtitle,
        author = style.author,
        date = style.date,
        abstract = style.abstract,
        glossary = style.glossary,
        sections = style.sections
    )

    return(rep)
end