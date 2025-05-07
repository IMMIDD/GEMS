export main, main_r, batch

"""
    main(configfile::String, populationfile::String, outputdir::String;
    settingfile::String="", report::Bool = false, csv::Bool = false,
    popexport::Bool = false, batch::Bool = false, seed = missing, 
    model_validation::Bool = true,  mod!::Function = x -> x, stepmod!::Function = x -> x,
    customlogger::CustomLogger = CustomLogger(), with_progressbar::Bool = true)

Runs the full simulation pipeline, including:
- Initialization (loading config- and population files)
- Model validation
- Running the simulation
- Exporting raw data in provided output folder
- Post processing
- Exporting processed data
- Generating report and exporting it to provided folder (indicated by optional boolean flag `report`. Default is `false`)

# Parameters

- `configfile::String`: Path to the configuration file.
- `populationfile::String`: Path to the population file.
- `outputdir::String`: Path to the output directory.
- `settingfile::String = ""` *(optional)*: Path to the setting file. No setting file is used if default (`""`) is provided.
- `report::Bool = false` *(optional)*: Indicates whether to generate and export a report (default is `false`).
- `csv::Bool = false` *(optional)*: Indicates whether raw data from loggers shall be exported in CSV format
- `popexport::Bool = false` *(optional)*: Indicates whether a CSV of the population shall be exported into the provided result folder. 
- `batch::Bool = false` *(optional)*: Indicates whether the function is being run in batch mode, i.e. data exportation is limited to the resultdata, configfile and runinfo (default is `false`).
- `seed = missing` *(optional)*: Seed value for random number generation (default is `missing`).
- `model_validation::Bool = true` *(optional)*: Indicates whether to perform model validation (default is `true`).
- `mod!::Function = x -> x` *(optional)*: Function for the modding of the simulation object (default is `x -> x`). The function will be applied to the simulation object after its construction and before the model execution.
- `stepmod!::Function = x -> x` *(optional)*: Function for custom logic added to the simulation object in each step (default is `x -> x`). The function will be applied to the simulation object in the end of each simulation step.
- `customlogger::CustomLogger = CustomLogger()` *(optional)*: Can be used to add custom logging mechanics that are being executed each step. Lookup `CustomLogger` docs for more information.
- `with_progressbar::Bool = true` *(optional)*: Flag indicating, if the run should display the `ProgressBar`.

# Output Files

The `main()` function generates multiple folders and files in
the output directory (`outputdir`) if all options are switched on:
- `/config`: Contains a copy of the used config file
- `/img`: Contains plots as .png images generated for the report
- `/output_JLD2`: Contains raw output data of the simulation loggers
- `/output_processed`: Contains the `ResultData` object
- `report.html`: Simulation report in `HTML` format
- `report.md`: Simulation report in `Markdown` format
- `report.pdf`: Simulation report in `PDF` format
- `runinfo.toml`: Simulation run meta data

# Returns
- `ResultData`: Result data object.
"""
function main(configfile::String, populationfile::String, outputdir::String;
    settingfile::String="", report::Bool = false, csv::Bool = false,
    popexport::Bool = false, batch::Bool = false, seed = missing, 
    model_validation::Bool = true,  mod!::Function = x -> x, stepmod!::Function = x -> x,
    customlogger::CustomLogger = CustomLogger(), with_progressbar::Bool = true)
    
    printinfo("Starting simulation with $(Threads.nthreads()) threads") 

    # timer output
    to = TimerOutput()

    timestamp = now()

    #TODO check if files exists, files have the right format and whether output directory is a valid directory
    # if !isdir(outputbasedir) error("Path to output directory invalid!") end

    mkpath(outputdir)

    if !batch
        printinfo("Validating input files") 
        @timeit to "0 Input Validation" validate_input_files(configfile, populationfile, settingfile, outputdir)  # no need to check outputdir if we use mkpath
    end

    # copy config file
    mkpath(outputdir * "/config")
    configcopy = outputdir * "/config/" * basename(configfile)
    cp(configfile, configcopy, force=true)

    # set up runinfo and store TOML
    ri = Runinfo(timestamp, configcopy, populationfile, settingfile)
    open(outputdir * "/runinfo.toml", "w") do io
        TOML.print(io, data(ri))
    end

    # Set simulation seed this will be overwritten if the config file includes a seed
    #if !ismissing(seed)
    #    Random.seed!(seed)
    #end

    # initialize simulation
    printinfo("Initializing simulation")
    @timeit to "1 Initialization" sim = Simulation(configfile, populationfile, settingfile)

    if model_validation
        # validate model
        # @info "Validating Model"  
        @timeit to "2 Model Validation" validate(sim) 
    end

    if !batch && popexport
        # store population model
        mkpath(outputdir * "/population") 
        save(population(sim), outputdir * "/population/population.csv") 
    end

    # fire optional modificators to the simulation object
    if !(mod! === nothing)
        mod!(sim)
    end

    # add custom logger
    customlogger!(sim, customlogger)

    # run simulation
    printinfo("Running simulation")
    @timeit to "3 Runtime" run!(sim, stepmod! = stepmod!, with_progressbar = with_progressbar)
    
    if !batch 
        if csv
            # store output files
            printinfo("Exporting raw CSV data")
            mkpath(outputdir * "/output")
            @timeit to "4 Data Export" begin
                save(infectionlogger(sim), outputdir * "/output/infections.csv")
                #save(logger(vaccine(sim)), outputdir * "/output/vaccinations.csv")
                save(deathlogger(sim), outputdir * "/output/deaths.csv")
                save(testlogger(sim), outputdir * "/output/tests.csv")
            end 
        end

        # Export JLD2 data file
        printinfo("Exporting raw JLD2 data")
        mkpath(outputdir * "/output_JLD2")
        @timeit to "4 Data Export" begin
            save_JLD2(infectionlogger(sim),outputdir * "/output_JLD2/infections.jld2")
            save_JLD2(deathlogger(sim),outputdir * "/output_JLD2/deaths.jld2")
            save_JLD2(testlogger(sim),outputdir * "/output_JLD2/tests.jld2")
        end
    end

    # post processing
    printinfo("Post processing [parallel: $PARALLEL_POST_PROCESSING; caching: $POST_PROCESSOR_CACHING]")
    @info "\r$(subinfo("Importing data from loggers"))"
    @timeit to "5 Post processing" rd = sim |> PostProcessor |> x -> ResultData(x, style = get(get(TOML.parsefile(configfile), "PostProcessing", Dict()), "style", ""))

    # set timer in result data
    timer_output!(rd, to)

    # store result data object
    printinfo("Exporting processed ResultData")
    @timeit to "4 Data Export" exportJLD(rd, outputdir * "/output_processed")
    if !batch
        exportJSON(rd, outputdir * "/output_processed")
        if report
            # build report
            printinfo("Generating report [parallel: $PARALLEL_REPORT_GENERATION]")
            @timeit to "6 Building Report" rep = buildreport(rd, get(TOML.parsefile(configfile), "reporting", ""))
            
            # add timer output to report
            addtimer!(rep, to)

            # generate report file
            #@suppress begin
                generate(rep, outputdir)
           #end
        end
    end

    # print elapsed time
    printinfo("Simulation completed in $(canonicalize(Dates.CompoundPeriod(now() - timestamp)))")

    # return result data object
    return(rd)
end


"""
    main_r(configfile::String, popidentifier::String, outputdir::String;
        report::Bool = false, csv::Bool = false, popexport::Bool = false,
        batch::Bool = false, seed = missing, model_validation::Bool = true,
        mod!::Function = x -> x, stepmod!::Function = x -> x,
        customlogger::CustomLogger = CustomLogger())

The "_r" suffix is for remote!

A wrapper for the `main()`-function to specify population- and setting files
using a `popidentifier`. Downloads the specified files from the population file server
(currently on Münster University Sciebo Cloud) and store them locally. If a local
copy is already available, the download will be skipped. Identifiers can be
German state abbreviations (e.g. "NRW"), depending on the availability of the 
respective population files on the server.

For further documentation of the arguments and inner workings, please look up the
`main()` functions documentation.

# Returns
- `ResultData`: Result data object.
"""
function main_r(configfile::String, popidentifier::String, outputdir::String;
    report::Bool = false, csv::Bool = false, popexport::Bool = false,
    batch::Bool = false, seed = missing, model_validation::Bool = true,
    mod!::Function = x -> x, stepmod!::Function = x -> x,
    customlogger::CustomLogger = CustomLogger(), with_progressbar::Bool = true)

    # obtain population and setting file from remote location or local folder
    (populationfile, settingfile) = obtain_remote_files(popidentifier)

    # run common main function
    return(
        main(
            configfile, populationfile, outputdir,
            settingfile = settingfile,
            report = report, csv = csv, popexport = popexport,
            batch = batch, seed = seed, model_validation = model_validation,
            mod! = mod!, stepmod! = stepmod!,
            customlogger = customlogger,
            with_progressbar = with_progressbar
        )
    )
end


"""

    main(args)

Outer main()-function to run GEMS simulation from console.
Provide parameters as String array in this order:
 - Path to config file
 - Path to population file
 - Path to output directory
 - Path to setting file (optional)

This function calls the _inner main()-function_.
"""
function main(args; with_progressbar::Bool = true)

    timestamp = now()

    configfile = args[1] # path to config file
    populationfile = args[2] # path to population file
    outputbasedir = args[3] # path to output directory
    if length(args) > 4
        settingfile = args[4] # path to setting file
    else
        settingfile = ""
    end

    # generate output folder
    outputdir = outputbasedir * "/" * Dates.format(timestamp, "yyyy-mm-dd_HH-MM-SS_sss")

    # call inner main
    return(
        main(configfile, populationfile, outputdir, settingfile = settingfile, report = true, with_progressbar = with_progressbar)
    )
end