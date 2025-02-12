using Documenter, GEMS
# using Documenter.DocChecks

using DataFrames, TimerOutputs
DocMeta.setdocmeta!(GEMS, :DocTestSetup, :(using GEMS); recursive=true, warn = false) # activate GEMS for all "jldoctests"

# tbd check for docstring completeness
# 296 docstrings not included in the manual
# DocChecks.checkdocs(GEMS)
# GEMS.getundocumented


makedocs(
    sitename = "GEMS.jl",
    modules  = [GEMS],
    remotes = nothing,
    format   = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true"),
    highlightsig = true,
    pages    = [
        # Start - Overview, Intro, installation, configuration
        "Home" => "index.md", #TODO add What's New? but only show later when there are actually new features added
        # Background - basis model, model setup & structs
        "Base Model" => [
            "Population" => "base-population.md",
            "Contacts" => "base-contacts.md",
            "Disease" => "base-disease.md",
            "Interventions" => "TriSM.md",
        ],
        # running simulations - step by step guide, tutorials
        "Running Simulations" => [ #cf Wiki
            "Tutorials" => "tut_Intro.md",
            "1 - Getting Started" => "tut_gettingstarted.md",
            "2 - Exploring Models" => "tut_exploring.md",
            "3 - Plotting" =>"tut_plotting.md",
            "4 - Running Batches" => "tut_batches.md",
            "5 - Creating Populations" => "tut_pops.md",
            "6 - Advanced Parameterization" => "tut_configfiles.md",
            "7 - Logging & Post-Processing" => "tut_postprocessing.md",
            "8 - Reporting" => "tut_reporting.md",
            "9 - Modeling Interventions" =>"tut_npi.md",
            "10 - Modeling Behavior" =>"tut_behavior.md",
            "11 - Contact Structures" =>"tut_contacts.md",
            "12 - Infections & Immunity" =>"tut_infections.md",
            "Cheat Sheet" =>"cheat-sheet.md"
        ],
        "Config Files" => "config-files.md",
        # modules/API - docstrings and functions
        "API" => [
            "Overview" => "docstrings-overview.md",
            #"Analysis" => "api_analysis.md", #TODO delete?
            "Batch Runs" => "api_batch.md",
            #"Constants" => "api_constants.md", #TODO delete?
            "Contacts" => "api_contacts.md",
            "Individuals" => "api_individuals.md",
            "Infections and Immunity" => "api_infections.md", #TODO I would merge this with the simulation or the pathogen section
            "Interventions" => "api_interventions.md",
            "Logger" => "api_logger.md",
            "Mapping" => "api_mapping.md", #TODO merge mapping and movie?
            "Misc" => "api_misc.md",
            "Movie" => "api_movie.md",
            "Pathogens" => "api_pathogens.md",
            "Plotting" => "api_plotting.md",
            "Population" => "api_population.md",
            "Post Processing" => "api_postproc.md",
            "Reporting" => "api_reporting.md",
            "Result Data" => "api_resultdata.md",
            "Settings" => "api_settings.md",
            "Simulation" => "api_simulation.md",
        ],
        # Folders in repo
        "Package Structure" => "package-structure.md", #TODO add markdowns from READMEs in Repo?
        # Contribution - style guides, working with git, change log, license
        "Contributing to GEMS" => "contributing-guide.md",
        # FAQ
        "FAQ" => "faq-page.md",
        # Glossary
        "Glossary" => "glossary.md",
    ];
    warnonly = true
)

deploydocs(;
    repo = "github.com/IMMIDD/GEMS.git",
    versions = ["stable" => "main", "v#.#", "dev" => "development"],
    push_preview = true
)
