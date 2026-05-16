export main

"""
    main(configfile::String, population::String, outputdir::String;
        report::Bool = false, csv::Bool = false,
        mod!::Union{Function, Nothing} = nothing,
        customlogger::CustomLogger = CustomLogger(),
        with_progressbar::Bool = true,
        simargs...)

Runs the full simulation pipeline:
- Initializes a `Simulation` from the given config and population
- Runs the simulation
- Exports raw logger data (JLD2, optionally CSV)
- Post-processes into a `ResultData` object and exports it
- Optionally generates a simulation report

# Parameters

- `configfile::String`: Path to the TOML configuration file.
- `population::String`: Path to a population file (CSV or JLD2) **or** a remote population identifier (e.g. `"HB"`, `"NRW"`).
- `outputdir::String`: Path to the output directory (created if absent).
- `report::Bool = false` *(optional)*: Generate a simulation report (`report.md`, and PDF/HTML if pandoc/LaTeX are available).
- `csv::Bool = false` *(optional)*: Export raw logger data as CSV in addition to JLD2.
- `mod!::Union{Function, Nothing} = nothing` *(optional)*: One-argument function applied to the `Simulation` object after construction and before `run!`. Use it to add interventions or adjust parameters programmatically.
- `customlogger::CustomLogger = CustomLogger()` *(optional)*: Custom logger attached to the simulation before running.
- `with_progressbar::Bool = true` *(optional)*: Show a progress bar during the run.
- `simargs...` *(optional)*: Any additional keyword arguments forwarded to `Simulation(...)`, e.g. `settingsfile="..."`, `transmission_rate=0.05`, `stop_criterion=TimesUp(100)`.

# Output structure

```
outputdir/
  config/         copy of the config file
  output/         CSV logger exports (only with csv=true)
  output_JLD2/    raw JLD2 logger exports
  output_processed/  ResultData as JLD2
  runinfo.toml    run metadata
  report.md       simulation report (only with report=true)
```

# Returns
- `ResultData`: the post-processed result object.
"""
function main(configfile::String, population::String, outputdir::String;
    report::Bool = false,
    csv::Bool = false,
    mod!::Union{Function, Nothing} = nothing,
    customlogger::CustomLogger = CustomLogger(),
    with_progressbar::Bool = true,
    simargs...)::ResultData

    printinfo("Starting simulation with $(Threads.nthreads()) threads")

    to = TimerOutput()
    timestamp = now()

    mkpath(outputdir)

    # copy config file
    mkpath(outputdir * "/config")
    configcopy = outputdir * "/config/" * basename(configfile)
    cp(configfile, configcopy, force=true)

    # write run metadata
    ri = Runinfo(timestamp, configcopy, population, "")
    open(outputdir * "/runinfo.toml", "w") do io
        TOML.print(io, data(ri))
    end

    # initialize simulation
    printinfo("Initializing simulation")
    @timeit to "1 Initialization" sim = Simulation(; configfile, population, simargs...)

    # apply optional simulation modifier
    if !isnothing(mod!)
        mod!(sim)
    end

    # attach custom logger
    customlogger!(sim, customlogger)

    # run simulation
    printinfo("Running simulation")
    @timeit to "2 Runtime" run!(sim; with_progressbar)

    if csv
        printinfo("Exporting raw CSV data")
        mkpath(outputdir * "/output")
        @timeit to "3 Data Export" begin
            save(infectionlogger(sim), outputdir * "/output/infections.csv")
            save(deathlogger(sim), outputdir * "/output/deaths.csv")
            save(testlogger(sim), outputdir * "/output/tests.csv")
        end
    end

    printinfo("Exporting raw JLD2 data")
    mkpath(outputdir * "/output_JLD2")
    @timeit to "3 Data Export" begin
        save_JLD2(infectionlogger(sim), outputdir * "/output_JLD2/infections.jld2")
        save_JLD2(deathlogger(sim), outputdir * "/output_JLD2/deaths.jld2")
        save_JLD2(testlogger(sim), outputdir * "/output_JLD2/tests.jld2")
    end

    # post-process
    printinfo("Post processing [parallel: $PARALLEL_POST_PROCESSING; caching: $POST_PROCESSOR_CACHING]")
    @timeit to "4 Post processing" rd = sim |> PostProcessor |>
        x -> ResultData(x, style = get(get(TOML.parsefile(configfile), "PostProcessing", Dict()), "style", ""))

    timer_output!(rd, to)

    printinfo("Exporting processed ResultData")
    @timeit to "3 Data Export" exportJLD(rd, outputdir * "/output_processed")

    # TODO: re-enable once parameters(::Pathogen) is implemented
    # exportJSON(rd, outputdir * "/output_processed")

    if report
        printinfo("Generating report [parallel: $PARALLEL_REPORT_GENERATION]")
        @timeit to "5 Report" rep = buildreport(rd, get(TOML.parsefile(configfile), "reporting", ""))
        addtimer!(rep, to)
        generate(rep, outputdir)
    end

    printinfo("Simulation completed in $(canonicalize(Dates.CompoundPeriod(now() - timestamp)))")

    return rd
end


"""
    main(args; with_progressbar::Bool = true)

CLI entry point. Accepts a string array with:
  1. Path to config file
  2. Path to population file (or remote identifier, e.g. `"HB"`)
  3. Path to base output directory (a timestamped subdirectory is created automatically)
  4. *(optional)* settingsfile path — passed as `settingsfile=args[4]` to `Simulation`

Always generates a report.
"""
function main(args; with_progressbar::Bool = true)
    timestamp = now()
    configfile = args[1]
    population = args[2]
    outputdir = args[3] * "/" * Dates.format(timestamp, "yyyy-mm-dd_HH-MM-SS_sss")
    simargs = length(args) >= 4 ? (settingsfile = args[4],) : NamedTuple()
    return main(configfile, population, outputdir; report=true, with_progressbar, simargs...)
end
