@testset "Reporting" begin

    basefolder = dirname(dirname(pathof(GEMS)))

    # load example simulation to perform tests
    sim = Simulation(basefolder * "/test/testdata/TestConf.toml", basefolder * "/test/testdata/TestPop.csv")
    run!(sim)
    rd = sim |> PostProcessor |> ResultData

    sims = Simulation[]
    for i in 1:5
        sim = Simulation(label="My Experiment")
        push!(sims, sim)
    end

    b = Batch(sims...)
    run!(b)
    bd = BatchData(b)

    @testset "Markdown Conversion" begin

        # escaping
        @test escape_markdown("_*") == "\\_\\*"
        @test savepath("C:\\Test") == "C:/Test"

        # Note: This only checks, if the markdown conversions are strings.
        # In an ideal world, there'd be a package that has a checker,
        # whether a String contains valid markdown syntax, but I didn't find any

        # start conditions
        @test InfectedFraction(0.01, sim |> pathogen) |> markdown |> typeof == String

        # stop criteria
        @test TimesUp(10) |> markdown |> typeof == String

        # pathogens
        @test sim |> pathogen |> markdown |> typeof == String

        # Distributions
        @test Uniform(0, 1) |> markdown |> typeof == String
        @test Poisson(4) |> markdown |> typeof == String

        # Settings SettingsContainer
        @test sim |> settings |> markdown |> typeof == String

        @test GEMS.print_arr([]) == ""
        @test GEMS.print_arr([1, 2]) == "[1, 2]"

        @test markdown([2.0, 3.0]) == "[2, 3]"

        # Test for markdown(Distribution)
        dist = Normal(0, 1)
        md_dist = markdown(dist)
        @test occursin("Normal", md_dist)
        @test occursin("σ", md_dist)  # Checks if parameters appear

        # Test for markdown(SettingsContainer, Simulation)
        sim = Simulation()
        stngs = SettingsContainer()
        md_settings = markdown(stngs, sim)
        @test occursin("| Setting | Number", md_settings)
        @test occursin("Table: Setting Summary", md_settings)

        # Test for markdown(Vaccine)
        dw = DiscreteWaning(7, 30)
        v = Vaccine(id=1, name="Antitest", waning=dw)
        md_vaccine = markdown(v)
        @test occursin("| Property | Value", md_vaccine)
        @test occursin("Antitest", md_vaccine)
        @test occursin("Waning", md_vaccine)

        # Test for markdown(DiscreteWaning)
        md_waning = markdown(dw)
        @test occursin("ticks after vaccination", md_waning)

        # Test for markdown(VaccinationScheduler)
        scheduler = VaccinationScheduler()
        md_scheduler = markdown(scheduler)
        @test occursin("To be implemented.", md_scheduler)
    end

    @testset "Sections" begin

        # sections

        s1 = Section(
            title="First Heading",
            content="Test Content"
        )

        @test s1 |> title == "First Heading"
        @test s1 |> content == "Test Content"

        GEMS.title!(s1, "New Heading")
        content!(s1, "New Content")

        @test s1 |> title == "New Heading"
        @test s1 |> content == "New Content"

        # subsections

        s2 = Section(
            title="Subsection",
            content="Sub Content"
        )
        addsection!(s1, s2)

        @test s1 |> subsections == [s2]

        # plot sections

        tc = TickCases()
        ps = PlotSection(tc)

        @test ps |> plt == tc

        # default generated sections

        @test Section(rd, :Debug) |> typeof == Section
        @test Section(rd, :General) |> typeof == Section
        @test Section(rd, :InputFiles) |> typeof == Section
        @test Section(rd, :Interventions) |> typeof == Section
        @test Section(rd, :Memory) |> typeof == Section
        @test Section(rd, :Model) |> typeof == Section
        @test Section(rd, :Observations) |> typeof == Section
        @test Section(rd, :Overview) |> typeof == Section
        @test Section(rd, :Repo) |> typeof == Section
        @test Section(rd, :Pathogens) |> typeof == Section
        @test Section(rd, :Processor) |> typeof == Section
        @test Section(rd, :Settings) |> typeof == Section
        @test Section(rd, :System) |> typeof == Section
    end


    @testset "Reports" begin

        rep = SimulationReport(
            data=rd,
            title="Test Report",
            author="Tester",
            date=rd |> execution_date,
            abstract="Test Abstract"
        )

        # meta info

        @test rep |> reportdata == rd

        @test rep |> title == "Test Report"
        GEMS.title!(rep, "New Title")
        @test rep |> title == "New Title"

        @test rep |> author == "Tester"
        author!(rep, "New Author")
        @test rep |> author == "New Author"

        @test rep |> date |> typeof == String
        d = now() |> string
        GEMS.date!(rep, d)
        @test rep |> date == d

        @test rep |> abstract == "Test Abstract"
        abstract!(rep, "New Abstract")
        @test rep |> abstract == "New Abstract"

        @test rep |> glossary == false
        glossary!(rep, true)
        @test rep |> glossary == true

        # sections

        s = Section(title="Test Section")
        addsection!(rep, s)
        @test rep |> sections == [s]

        addtimer!(rep, TimerOutput())
        @test rep |> sections |> length == 2

        # styling

        dpi!(rep, 400)
        @test rep |> dpi == 400
        fontfamily!(rep, "Arial")
        @test rep |> fontfamily == "Arial"

    end

    @testset "Plotting" begin
        # array of all available plots
        plts = [
            ActiveDarkFigure()
            #AggregatedSettingAgeContacts(Household)
            CompartmentFill()
            CumulativeCases()
            CumulativeDiseaseProgressions()
            CumulativeIsolations()
            CustomLoggerPlot()
            DetectedCases()
            EffectiveReproduction()
            GenerationTime()
            #HospitalOccupancy()
            HouseholdAttackRate()
            Incidence()
            InfectionDuration()
            InfectionMap()
            InfectiousHistogram()
            LatencyHistogram()
            ObservedReproduction()
            ObservedSerialInterval()
            PopulationPyramid()
            #SettingAgeContacts(Household)
            SettingSizeDistribution()
            SymptomCategories()
            TestPositiveRate()
            TickCases()
            TickCasesBySetting()
            TickTests()
            TimeToDetection()
            TotalTests()
        ]

        # generate each plot
        for p in plts
            @test p |> title |> typeof == String
            @test p |> description |> typeof == String

            description!(p, "TEST")
            @test p |> description == "TEST"
            @test p |> filename |> typeof == String
            @test occursin(r".png$", filename(p)) # filename must end in *.png

            # generate plots (maybe there's a better idea for actual tests here?)
            generate(p, rd)
            println(typeof(p))
            gemsplot(rd)
        end

        @testset "Plots with ResultData-Array" begin
            plts = [
                ActiveDarkFigure()
                CumulativeCases()
                CumulativeIsolations()
                CustomLoggerPlot()
                EffectiveReproduction()
                GenerationTime()
                HouseholdAttackRate()
                InfectionDuration()
                TickCases()
                TotalTests()
            ]
            sim2 = Simulation()
            run!(sim2)
            rd2 = sim |> PostProcessor |> ResultData

            # generate each plot
            for p in plts
                @test p |> title |> typeof == String
                @test p |> description |> typeof == String

                description!(p, "TEST")
                @test p |> description == "TEST"
                @test p |> filename |> typeof == String
                @test occursin(r".png$", filename(p)) # filename must end in *.png

                # generate plots (maybe there's a better idea for actual tests here?)
                generate(p, [rd, rd2])
                splitplot(p, [rd, rd2])
                if typeof(p) != CustomLoggerPlot
                    splitlabel(p, [rd])
                end
            end
        end

        @testset "Scenario Simulation Plots" begin
            p = AggregatedSettingAgeContacts(Household)
            @test settingtype(p) == Household
            p = SettingAgeContacts(Household)
            @test settingtype(p) == Household

            #Isolation and Test Scenario
            scenario = Simulation(label="Scenario")
            PCR_Test = TestType("PCR Test", pathogen(scenario), scenario)
            self_isolation = IStrategy("Self Isolation", scenario)
            add_measure!(self_isolation, SelfIsolation(14))
            testing = IStrategy("Testing", scenario)
            add_measure!(testing, GEMS.Test("Test", PCR_Test, positive_followup=self_isolation))

            trigger = SymptomTrigger(testing)
            add_symptom_trigger!(scenario, trigger)
            run!(scenario)
            rd = scenario |> PostProcessor |> ResultData

            plts = [
                CumulativeIsolations(),
                TestPositiveRate(),
                TimeToDetection(),
                TickTests(),
                TotalTests(),
                ObservedSerialInterval()
            ]

            for p in plts
                @test p |> title |> typeof == String
                @test p |> description |> typeof == String

                description!(p, "TEST")
                @test p |> description == "TEST"
                @test p |> filename |> typeof == String
                @test occursin(r".png$", filename(p)) # filename must end in *.png

                # generate plots (maybe there's a better idea for actual tests here?)
                generate(p, rd)
            end

        end

        @testset "Batch Plots" begin
            #array of all availible batch plots
            plts = [
                #BatchEffectiveReproduction()
                #BatchPopulationPyramid(basefolder * "/test/testdata/TestPop.csv")
                #BatchSettingAgeContacts(Household, basefolder * "/test/testdata/TestPop.csv")
                #BatchTickCases()
                BatchTickIsolations()
                BatchTickTests()
            ]
            # generate each plot
            for p in plts
                @test p |> title |> typeof == String
                @test p |> description |> typeof == String

                description!(p, "TEST")
                @test p |> description == "TEST"
                @test p |> filename |> typeof == String
                @test occursin(r".png$", filename(p)) # filename must end in *.png

                # generate plots (maybe there's a better idea for actual tests here?)
                generate(p, bd)
                gemsplot(bd)
            end
            @testset "Specific Batch Plots" begin
                #Isolation and Test Scenario
                baseline = Simulation(label="Baseline")
                scenario = Simulation(label="Scenario")
                PCR_Test = TestType("PCR Test", pathogen(scenario), scenario)
                self_isolation = IStrategy("Self Isolation", scenario)
                add_measure!(self_isolation, SelfIsolation(14))
                testing = IStrategy("Testing", scenario)
                add_measure!(testing, GEMS.Test("Test", PCR_Test, positive_followup=self_isolation))

                trigger = SymptomTrigger(testing)
                add_symptom_trigger!(scenario, trigger)

                sims = Simulation[baseline, scenario]
                b = Batch(sims...)
                run!(b)
                bd = BatchData(b)
                p = BatchTickIsolations()

                @test p |> title |> typeof == String
                @test p |> description |> typeof == String

                description!(p, "TEST")
                @test p |> description == "TEST"
                @test p |> filename |> typeof == String
                @test occursin(r".png$", filename(p)) # filename must end in *.png

                # generate plots (maybe there's a better idea for actual tests here?)
                #generate(p, bd) not working TODO

                p2 = BatchTickTests()

                @test p2 |> title |> typeof == String
                @test p2 |> description |> typeof == String

                description!(p2, "TEST")
                @test p2 |> description == "TEST"
                @test p2 |> filename |> typeof == String
                @test occursin(r".png$", filename(p2)) # filename must end in *.png

                # generate plots (maybe there's a better idea for actual tests here?)
                #generate(p2, bd) not working
                totalonly!(p2, true)
                @test totalonly(p2)

                TickTests()

            end
        end

    end

    @testset "Custom Report" begin
        # Use specific style
        style = "MinimalSimulationReport"
        rep = buildreport(rd, style)
        @test rep.title == "Minimal Simulation Report"
        @test rep.sections |> length == 3
        # Use default report
        rep = buildreport(rd)
        @test rep.title != "Minimal Simulation Report"
        @test rep.sections |> length == 4
        mutable struct TestReportStyle <: SimulationReportStyle
            data
            title
            subtitle
            author
            date
            sections
            glossary
            abstract
            function TestReportStyle(; data)
                rep = new(data, "Test", "Test", "Test", "Test", [], false, "Test")
                return rep
            end
        end
        rep = buildreport(rd, "TestReportStyle")
        @test rep.title == "Test"
        @test rep.sections |> length == 0
    end

    # @testset "Custom Batch Reporting" begin TODO put back in
    #     bd = batch_test()
    #     # Report generation without any config files, i.e. full report
    #     rep = buildreport(bd)
    #     @test length(rep.sections) == 5
    #     rep = buildreport(bd, "MinimalBatchReport")
    #     @test length(rep.sections) == 3
    #     mutable struct TestBatchReport <: BatchReportStyle
    #         data
    #         title
    #         subtitle
    #         author
    #         date
    #         sections
    #         glossary
    #         abstract
    #         function TestBatchReport(;data)
    #             rep = new(data,"Test","Test","Test","Test",[],false,"Test")
    #             return rep
    #         end
    #     end
    #     rep = buildreport(bd, "TestBatchReport")
    #     @test rep.title == "Test"
    #     @test length(rep.sections) == 0
    # end
    @testset "File Handling" begin

        # temporary testing directory (timestamp for uniqueness)
        BASE_FOLDER = dirname(dirname(pathof(GEMS)))
        directory = BASE_FOLDER * "/test_" * string(datetime2unix(now()))

        rep = rd |> buildreport

        @test rep |> typeof == SimulationReport

        generate(rep, directory)

        # check file existence
        @test isfile(directory * "/report.md")
        @test isfile(directory * "/report.html")
        @test isfile(directory * "/report.pdf")

        # finally, remove all test files
        rm(directory, recursive=true)

    end

    @testset "Maps Tests" begin
        @testset "region_range Tests" begin
            # Test mit normalen Koordinaten
            df = DataFrame(lat=[50, 51, 52], lon=[8, 9, 10])
            bounds = region_range(df)
            expected_bounds = [7.9, 10.1, 49.9, 52.1]
            @test bounds ≈ expected_bounds

            # Test mit nur einem Punkt
            df = DataFrame(lat=[50], lon=[8])
            bounds = region_range(df)
            @test bounds ≈ [8, 8, 50, 50]

            # Test mit gleichen Koordinaten
            df = DataFrame(lat=[50, 50, 50], lon=[8, 8, 8])
            bounds = region_range(df)
            @test bounds ≈ [8, 8, 50, 50]

            # Test mit Extremwerten (Nähe Pole und 180° Meridian)
            df = DataFrame(lat=[-89, 89], lon=[-179, 179])
            bounds = region_range(df)
            expected_bounds = [-180, 180, -90, 90]
            @test bounds == expected_bounds

            # Test mit negativen und positiven Werten
            df = DataFrame(lat=[-10, 10], lon=[-20, 20])
            bounds = region_range(df)
            expected_bounds = [-22.0, 22.0, -11.0, 11.0]
            @test bounds ≈ expected_bounds
        end
        using Test, DataFrames

        #=   @testset "generate_map tests" begin
               dest = joinpath(pwd(), "test_map.png") 

               # Test: Normale Nutzung mit gültigen Koordinaten
               df = DataFrame(lat=[50, 51, 52], lon=[8, 9, 10])
               result = generate_map(df, dest)
               @test result isa GMTWrapper
               @test isfile(dest)  # Datei sollte erstellt worden sein

               # Test: Leeres DataFrame ohne plotempty -> Sollte Fehler werfen
               df_empty = DataFrame(lat=[], lon=[])
               @test_throws "You passed an empty dataframe" generate_map(df_empty, dest)

               # Test: plotempty=True aber ohne region -> Sollte Fehler werfen
               @test_throws "If you force an empty plot, you must specify a region" generate_map(df_empty, dest; plotempty=true)

               # Test: plotempty=True mit definierter region -> Sollte eine leere Karte erzeugen
               region = [7, 11, 49, 53]  # Bounding Box um die Test-Koordinaten
               result = generate_map(df_empty, dest; region=region, plotempty=true)
               @test result isa GMTWrapper
               @test isfile(dest)

               # Test: Nutzung eines spezifischen Regionsbereichs
               custom_region = [7, 11, 49, 53]
               result = generate_map(df, dest; region=custom_region)
               @test result isa GMTWrapper
               @test isfile(dest)

               # Cleanup nach den Tests
               rm(dest; force=true)
           end =#

        @testset "agsmap tests" begin
            # Beispiel AGS-Werte mit exakt 8 Ziffern
            ags_states = [AGS("01000000"), AGS("02000000"), AGS("03000000")]  # Bundesländer (Level 1)
            ags_counties = [AGS("01001000"), AGS("02002000"), AGS("03003000")]  # Landkreise (Level 2)
            ags_municipalities = [AGS("01001001"), AGS("02002002"), AGS("03003003")]  # Gemeinden (Level 3)

            # Test: Normale Nutzung für Bundesländer (Level 1)
            df = DataFrame(ags=ags_states, values=[10, 20, 30])
            result = agsmap(df, 1)
            @test result isa Plots.Plot

            # Test: Normale Nutzung für Landkreise (Level 2)
            df = DataFrame(ags=ags_counties, values=[15, 25, 35])
            result = agsmap(df, 2)
            @test result isa Plots.Plot

            # Test: Normale Nutzung für Gemeinden (Level 3)
            df = DataFrame(ags=ags_municipalities, values=[5, 15, 25])
            result = agsmap(df, 3)
            @test result isa Plots.Plot

            # Test: Falsche Spaltennamen im DataFrame → Sollte Fehler werfen
            df_wrong = DataFrame(id=ags_states, values=[10, 20, 30])
            @test_throws "The first column of the input dataframe must be named 'ags'." agsmap(df_wrong, 1)

            # Test: Erste Spalte ist nicht AGS → Sollte Fehler werfen
            df_wrong_type = DataFrame(ags=["01000000", "02000000", "03000000"], values=[10, 20, 30])
            @test_throws "The first column of the input dataframe must contain a Vector of AGS structs" agsmap(df_wrong_type, 1)

            # Test: Zweite Spalte enthält keine numerischen Werte → Sollte Fehler werfen
            df_wrong_values = DataFrame(ags=ags_states, values=["low", "medium", "high"])
            @test_throws "The second column of the input dataframe must contain a Vector of numeric values" agsmap(df_wrong_values, 1)

            # Test: AGS-Level passt nicht zum Level-Parameter → Sollte Fehler werfen
            @test_throws "The AGSs provided in the input dataframes are not all refering to states (level 1)" agsmap(DataFrame(ags=ags_counties, values=[10, 20, 30]), 1)
            @test_throws "The AGSs provided in the input dataframes are not all refering to counties (level 2)" agsmap(DataFrame(ags=ags_municipalities, values=[10, 20, 30]), 2)
            @test_throws "The AGSs provided in the input dataframes are not all refering to municipalities (level 3)" agsmap(DataFrame(ags=ags_states, values=[10, 20, 30]), 3)

            # Test: Doppelte AGS-Einträge → Sollte Fehler werfen
            df_duplicate = DataFrame(ags=[AGS("01000000"), AGS("01000000"), AGS("02000000")], values=[10, 20, 30])
            @test_throws "All AGS values need to be unique!" agsmap(df_duplicate, 1)

            # Test: Ungültiges Level → Sollte Fehler werfen
            @test_throws "The level must be either 1 (States), 2 (Counties), or 3 (Municipalities)" agsmap(df, 0)
            @test_throws "The level must be either 1 (States), 2 (Counties), or 3 (Municipalities)" agsmap(df, 4)
        end
        @testset "agsmap wrapper tests" begin
            # Beispiel AGS-Werte mit genau 8 Ziffern
            ags_states = [AGS("01000000"), AGS("02000000"), AGS("03000000")]  # Bundesländer (Level 1)
            ags_counties = [AGS("01001000"), AGS("02002000"), AGS("03003000")]  # Landkreise (Level 2)
            ags_municipalities = [AGS("01001001"), AGS("02002002"), AGS("03003003")]  # Gemeinden (Level 3)

            # Test: Automatische Erkennung für Bundesländer
            df_states = DataFrame(ags=ags_states, values=[10, 20, 30])
            result = agsmap(df_states)
            @test result isa Plots.Plot

            # Test: Automatische Erkennung für Landkreise
            df_counties = DataFrame(ags=ags_counties, values=[15, 25, 35])
            result = agsmap(df_counties)
            @test result isa Plots.Plot

            # Test: Automatische Erkennung für Gemeinden
            df_municipalities = DataFrame(ags=ags_municipalities, values=[5, 15, 25])
            result = agsmap(df_municipalities)
            @test result isa Plots.Plot

            # Test: Manuelle Angabe von `level`
            df_mixed = DataFrame(ags=[AGS("01000000"), AGS("02000000")], values=[10, 20])
            result = agsmap(df_mixed, level=1)
            @test result isa Plots.Plot
            @test_throws "The AGSs provided in the input dataframes are not all refering to counties (level 2)" agsmap(df_mixed, level=2)
            @test_throws "The AGSs provided in the input dataframes are not all refering to municipalities (level 3)" agsmap(df_mixed, level=3)


            df_mixed = DataFrame(ags=[AGS("01010000"), AGS("02010000")], values=[10, 20])
            result = agsmap(df_mixed, level=2)
            @test result isa Plots.Plot
            @test_throws "The AGSs provided in the input dataframes are not all refering to states (level 1)" agsmap(df_mixed, level=1)

            df_mixed = DataFrame(ags=[AGS("01010100"), AGS("02010100")], values=[10, 20])
            result = agsmap(df_mixed, level=3)
            @test result isa Plots.Plot
            @test_throws "The AGSs provided in the input dataframes are not all refering to states (level 1)" agsmap(df_mixed, level=1)
            @test_throws "The AGSs provided in the input dataframes are not all refering to counties (level 2)" agsmap(df_mixed, level=2)

            # Test: Spezifische Wrapper-Funktionen
            result = statemap(df_states)
            @test result isa Plots.Plot

            result = countymap(df_counties)
            @test result isa Plots.Plot

            result = municipalitymap(df_municipalities)
            @test result isa Plots.Plot

            # Test: Wrapper mit zusätzlichen Plot-Argumenten
            result = agsmap(df_states, title="State Map", fillcolor=:blue)
            @test result isa Plots.Plot

            result = countymap(df_counties, title="County Map", fillcolor=:green)
            @test result isa Plots.Plot

            result = municipalitymap(df_municipalities, title="Municipality Map", fillcolor=:red)
            @test result isa Plots.Plot
        end
        @testset "prepare_map_df! tests" begin
            # Beispiel AGS-Werte mit genau 8 Ziffern
            ags_states = [AGS("01000000"), AGS("02000000"), AGS("03000000")]  # Bundesländer (Level 1)
            ags_counties = [AGS("01001000"), AGS("02002000"), AGS("03003000")]  # Landkreise (Level 2)
            ags_municipalities = [AGS("01001001"), AGS("02002002"), AGS("03003003")]  # Gemeinden (Level 3)

            # Test: Umwandlung zu Bundesländer-Level
            df_states = DataFrame(ags=ags_municipalities, values=[10, 20, 30])
            prepare_map_df!(df_states, level=1)
            @test all(is_state.(df_states.ags))
            @test length(unique(df_states.ags)) == 3

            # Test: Umwandlung zu Landkreise-Level
            df_counties = DataFrame(ags=ags_municipalities, values=[10, 20, 30])
            prepare_map_df!(df_counties, level=2)
            @test all(is_county.(df_counties.ags))
            @test length(df_counties.ags) == 3

            # Test: Umwandlung zu Gemeinde-Level
            df_municipalities = DataFrame(ags=ags_municipalities, values=[10, 20, 30])
            prepare_map_df!(df_municipalities, level=3)
            @test !(any(is_state.(df_municipalities.ags)))
            @test length(df_municipalities.ags) == 3

            # Test: Fehlermeldung bei falschem Spaltennamen
            df_wrong = DataFrame(id=ags_municipalities, values=[10, 20, 30])
            @test_throws "The first column of the input dataframe must be named 'ags'." prepare_map_df!(df_wrong, level=1)

            # Test: Fehlermeldung bei falschem Datentyp
            df_wrong_type = DataFrame(ags=["01000000", "02000000", "03000000"], values=[10, 20, 30])
            @test_throws "The first column of the input dataframe must contain a Vector of AGS structs" prepare_map_df!(df_wrong_type, level=1)
        end
        @testset "MapPlot Abstract Type Tests" begin
            # Test, ob MapPlot ein Subtyp von ReportPlot ist
            @test MapPlot <: ReportPlot

            # Test, ob eine konkrete Implementierung von MapPlot erforderlich ist
            struct DummyMapPlot <: MapPlot end  # Ein Dummy-Subtyp

            dummy_plot = DummyMapPlot()
            data = Dict("example" => 42)

            @test_throws ErrorException generate(dummy_plot, data)  # Sollte einen Fehler werfen
        end

        @testset "maptypes() Function Test" begin
            expected_maps = [:AgeMap, :AttackRateMap, :CaseFatalityMap, :DummyMapPlot,
                :HouseholdSizeMap, :PopDensityMap, :SinglesMap]

            result = maptypes()

            @test result isa Vector{Symbol}  # Prüft, ob das Ergebnis ein Vektor von Symbolen ist
            @test length(result) == 7  # Prüft, ob genau 7 Elemente enthalten sind
            @test Set(result) == Set(expected_maps)  # Prüft, ob die Elemente übereinstimmen (unabhängig von der Reihenfolge)
        end

        @testset "gemsmap() Function Tests" begin
            # Simulations- und Ergebnisobjekte erstellen
            sim = Simulation()
            rd = sim |> PostProcessor |> ResultData

            # Erwartete Kartentypen
            map_types = [:AgeMap, :AttackRateMap, :CaseFatalityMap,
                :HouseholdSizeMap, :PopDensityMap, :SinglesMap]

            # Test: Funktioniert gemsmap für alle bekannten Kartentypen?
            for map_type in map_types
                if map_type in [:AttackRateMap, :CaseFatalityMap]  # Diese Typen benötigen ResultData
                    result = gemsmap(rd, type=map_type)
                else  # Die restlichen benötigen ein Simulation-Objekt
                    result = gemsmap(sim, type=map_type)
                end

                @test result isa Plots.Plot  # Prüfen, ob das Ergebnis ein Plots.Plot ist
            end

            # Test: Funktioniert die Level-Änderung korrekt?
            result = gemsmap(sim, type=:AgeMap, level=1)
            @test result isa Plots.Plot

            result = gemsmap(sim, type=:AgeMap, level=2)
            @test result isa Plots.Plot

            result = gemsmap(sim, type=:AgeMap, level=3)
            @test result isa Plots.Plot

            # Test: Unbekannter Kartentyp löst Fehler aus
            @test_throws "There's no plot type that matches :UnknownMap" gemsmap(sim, type=:UnknownMap)

            # Test: Plot mit zusätzlichen Argumenten
            result = gemsmap(sim, type=:AgeMap, title="Test Map", clims=(0, 100))
            @test result isa Plots.Plot
        end

        @testset "Map Plots" begin
            # plots with no gelocated data
            plts = [
                AgeMap(),
                HouseholdSizeMap(),
                PopDensityMap(),
                SinglesMap()
            ]
            sim = Simulation()
            for p in plts
                generate(p, sim)
            end
            run!(sim)
            rd = sim |> PostProcessor |> ResultData
            attack_rate_map = AttackRateMap()
            case_fatality_map = CaseFatalityMap()
            generate(attack_rate_map, rd)
            generate(case_fatality_map, rd)

            # plots with geolocated data
            plts = [
                AgeMap(),
                HouseholdSizeMap(),
                PopDensityMap(),
                SinglesMap()
            ]

            sim = Simulation(population="HB")
            for p in plts
                generate(p, sim)
            end
            run!(sim)
            rd = sim |> PostProcessor |> ResultData
            attack_rate_map = AttackRateMap()
            case_fatality_map = CaseFatalityMap()
            generate(attack_rate_map, rd)
            generate(case_fatality_map, rd)
        end

    end

    @testset "Plots Test" begin

        @testset "GMTWrapper Tests" begin
            # Test: GMTWrapper speichert den korrekten Pfad
            wrapper = GMTWrapper("/tmp/test_map.png")
            @test wrapper isa GMTWrapper
            @test wrapper.path_to_map == "/tmp/test_map.png"
        end

        @testset "generate() Function Tests" begin

            struct DummyPlot <: SimulationPlot end

            sim = Simulation()
            run!(sim)
            rd = sim |> PostProcessor |> ResultData

            dummy_plot = DummyPlot()
            @test_throws "generate(...) is not defined for concrete report plot type DummyPlot" generate(dummy_plot, rd)
        end

        @testset "Plot Formatting Functions" begin
            # Test: fontfamily! für Plots.jl
            p = plot(rand(10))
            fontfamily!(p, "Arial")
            @test p.attr[:fontfamily] == "Arial"

            fontfamily!(p, "Times New Roman")
            @test p.attr[:fontfamily] == "Times Roman"

            # Test: fontfamily! für VegaLite (nur println, kein echter Test möglich)
            # vl = VegaLite.VLSpec()
            # @test_logs (:info, "Custom fontfamily cannot be set for VegaLite plots") fontfamily!(vl, "Arial")

            # Test: dpi! für Plots.jl
            dpi!(p, 300)
            @test p.attr[:dpi] == 300

            # Test: dpi! für VegaLite (nur println, kein echter Test möglich)
            # @test_logs (:info, "Custom dpi cannot be set for VegaLite plots") dpi!(vl, 300)

            # TODO: Test: title! für Plots.jl
            GEMS.title!(p, "Test Title")
            GEMS.titlefontsize!(p, 18)
        end

    end

end