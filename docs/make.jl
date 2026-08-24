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
        "Installation" => "installation.md",
        # Background - basis model, model setup & structs
        "Base Model" => [
            "Population" => "base-population.md",
            "Contacts" => "base-contacts.md",
            "Disease" => "base-disease.md",
            "Interventions" => "TriSM.md",
            "Default Parameters" => "base-config.md",
            "Tutorials" => "tut_Intro.md"
        ],
        # running simulations - step by step guide, tutorials
        "Running Simulations" => [ #cf Wiki
            "1 - Getting Started" => "tut_gettingstarted.md",
            "2 - Exploring Models" => "tut_exploring.md",
            "3 - Creating Populations" => "tut_pops.md",
            "4 - Configuring Diseases" =>"tut_diseases.md",
            "5 - Modeling Interventions" => "tut_npi.md",
            "6 - Running Batches" => "tut_batches.md",
            "7 - Calibration" => "tut_calibration.md",
            "8 - Logging & Post-Processing" => "tut_postprocessing.md",
            "9 - Plotting" =>"tut_plotting.md",
            "10 - Advanced Parameterization" => "tut_configfiles.md"
        ],
        "Config Files" => "config-files.md",
        # modules/API - docstrings and functions
        "API" => [
            "Overview" => "docstrings-overview.md",
            "Batches" => "api_batch.md",
            "Contacts" => "api_contacts.md",
            "Individuals" => "api_individuals.md",
            "Infections and Immunity" => "api_infections.md",
            "Interventions" => "api_interventions.md",
            "Logger" => "api_logger.md",
            "Mapping" => "api_mapping.md",
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
        # Contribution - style guides, working with git, change log, license
        "Contributing to GEMS" => "contributing-guide.md",
        # Changelog
        "Changelog" => "changelog.md",
        # FAQ
        "FAQ" => "faq-page.md",
        # Glossary
        "Glossary" => "glossary.md",
    ];
    warnonly = true
)

deploydocs(;
    repo = "github.com/IMMIDD/GEMS.git",
    versions = ["stable" => "v^", "v#.#.#", "v#.#.#-#", "dev" => "main"],
    push_preview = true
)
