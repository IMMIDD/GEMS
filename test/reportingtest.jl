@testset "Reporting" begin

    basefolder = dirname(dirname(pathof(GEMS)))

    # load example simulation to perform tests
    # sim = Simulation(
    #     configfile = joinpath(basefolder, "test/testdata/TestConf.toml"),
    #     population = joinpath(basefolder, "test/testdata/TestPop.csv")
    # )
    sim = Simulation(pop_size = 1000, infected_fraction = 0.1)
    run!(sim)
    rd = sim |> PostProcessor |> ResultData

    sims = Simulation[]
    for i in 1:5
        sim = Simulation(pop_size = 1000, label="My Experiment")
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
        @test InfectedFraction(fraction = 0.01) |> markdown |> typeof == String

        # stop criteria
        @test TimesUp(limit = 10) |> markdown |> typeof == String

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
        addsection!(s1, [s2])

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

        # default generated sections for batches

        @test Section(bd, :BatchInfo) |> typeof == Section
        @test Section(bd, :Runtime) |> typeof == Section
        @test Section(bd, :Allocations) |> typeof == Section
        @test Section(bd, :Resources) |> typeof == Section

        @testset "Flatten Sections Tests" begin
            # Create sections and subsections
            subsub_section = Section(title="Subsubsection", content="Content 3")
            sub_section = Section(title="Subsection", content="Content 2", subsections=[subsub_section])
            main_section = Section(title="Main Section", content="Content 1", subsections=[sub_section])

            # Run flatten_sections on the main section
            result = GEMS.flatten_sections(main_section, 0)

            # Check that all sections appear in the result with correct depth
            @test length(result) == 3
            @test result[1][1] == main_section && result[1][2] == 0  # Main section at depth 0
            @test result[2][1] == sub_section && result[2][2] == 1   # Subsection at depth 1
            @test result[3][1] == subsub_section && result[3][2] == 2  # Subsubsection at depth 2

            # Test empty section (should return just itself with depth 0)
            empty_section = Section(title="Empty")
            empty_result = GEMS.flatten_sections(empty_section, 0)
            @test length(empty_result) == 1
            @test empty_result[1][1] == empty_section && empty_result[1][2] == 0
        end

    end


    @testset "Reports" begin

        rep = SimulationReport(
            data=rd,
            title="Test Report",
            author="Tester",
            date=rd |> execution_date,
            abstract="Test Abstract",
            subtitle="Test Subtitle"
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

        @test rep |> subtitle == "Test Subtitle"
        subtitle!(rep, "New Subtitle")
        @test rep |> subtitle == "New Subtitle"

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
            HospitalOccupancy()
            HouseholdAttackRate()
            Incidence()
            IncubationHistogram()
            InfectionDuration()
            InfectionMap()
            InfectiousHistogram()
            LatencyHistogram()
            ObservedReproduction()
            ObservedSerialInterval()
            PopulationPyramid()
            #SettingAgeContacts(Household)
            SettingSizeDistribution()
            ProgressionCategories()
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
            rd2 = sim2 |> PostProcessor |> ResultData

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
                #if typeof(p) != CustomLoggerPlot
                #   splitlabel(p, [rd])
                #end
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
        @testset "Seroprevalence-Testing-Plot" begin
            seroprevalence_testing = Simulation()
            seroprevalence_test = SeroprevalenceTestType("Seroprevalence Test", pathogen(seroprevalence_testing), seroprevalence_testing)
            testing = IStrategy("Testing", seroprevalence_testing)
            add_measure!(testing, GEMS.Test("Test", seroprevalence_test))
            trigger = ITickTrigger(testing, switch_tick=Int16(1), interval=Int16(1))
            add_tick_trigger!(seroprevalence_testing, trigger)
            run!(seroprevalence_testing)
            rd = ResultData(seroprevalence_testing)
            sim = Simulation()
            run!(sim)
            rd2 = ResultData(sim)
            p1 = generate(TickSeroTests(), rd; detailed=true)
            p2 = generate(TickSeroTests(), rd)
            p3 = generate(TickSeroTests(), rd2)
            @test p1 isa Plots.Plot
            @test p2 isa Plots.Plot
            @test p3 isa Plots.Plot
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

    @testset "Custom Batch Reporting" begin
        # Report generation without any config files, i.e. full report
        rep = buildreport(bd)
        @test length(rep.sections) == 3
        mutable struct TestBatchReport <: BatchReportStyle
            data
            title
            subtitle
            author
            date
            sections
            glossary
            abstract
            function TestBatchReport(; data)
                rep = new(data, "Test", "Test", "Test", "Test", [], false, "Test")
                return rep
            end
        end
        rep = buildreport(bd, "TestBatchReport")
        @test rep.title == "Test"
        @test length(rep.sections) == 0
    end

    @testset "File Handling" begin

        # temporary testing directory (timestamp for uniqueness)
        BASE_FOLDER = dirname(dirname(pathof(GEMS)))
        directory = BASE_FOLDER * "/test_" * string(datetime2unix(now()))

        rep = rd |> buildreport

        @test rep |> typeof == SimulationReport

        #generate(rep, directory)

        # check file existence
        #@test isfile(directory * "/report.md")
        #@test isfile(directory * "/report.html")
        #@test isfile(directory * "/report.pdf")

        # finally, remove all test files
        #rm(directory, recursive=true)

    end

    @testset "Maps Tests" begin
        @testset "region_range Tests" begin
            # Test with normal coordinates
            df = DataFrame(lat=[50, 51, 52], lon=[8, 9, 10])
            bounds = region_range(df)
            expected_bounds = [7.9, 10.1, 49.9, 52.1]
            @test bounds ≈ expected_bounds

            # Test with a single point
            df = DataFrame(lat=[50], lon=[8])
            bounds = region_range(df)
            @test bounds ≈ [8, 8, 50, 50]

            # Test with same coordinates
            df = DataFrame(lat=[50, 50, 50], lon=[8, 8, 8])
            bounds = region_range(df)
            @test bounds ≈ [8, 8, 50, 50]

            # Test with extreme values
            df = DataFrame(lat=[-89, 89], lon=[-179, 179])
            bounds = region_range(df)
            expected_bounds = [-180, 180, -90, 90]
            @test bounds == expected_bounds

            # Test with positive and negative values
            df = DataFrame(lat=[-10, 10], lon=[-20, 20])
            bounds = region_range(df)
            expected_bounds = [-22.0, 22.0, -11.0, 11.0]
            @test bounds ≈ expected_bounds
        end

        #= @testset "generate_map tests" begin
              dest = basefolder * "/test_map.png"

              # Test with normal coordinates
              df = DataFrame(lat=[50, 51, 52], lon=[8, 9, 10])
              result = generate_map(df, dest)
              @test result isa GMTWrapper
              @test isfile(dest)  # file should be generated

              # Test: empty DataFrame -> should throw an error
              df_empty = DataFrame(lat=[], lon=[])
              @test_throws "You passed an empty dataframe" generate_map(df_empty, dest)

              # Test: plotempty =True without region -> should throw an error
              @test_throws "If you force an empty plot, you must specify a region" generate_map(df_empty, dest; plotempty=true)

              # Test: plotempty=True with a defined region -> should generate an empty map
              region = [7, 11, 49, 53]  # Bounding Box for the Test-coordinates
              result = generate_map(df_empty, dest; region=region, plotempty=true)
              @test result isa GMTWrapper
              @test isfile(dest)

              # Test with a specific region
              custom_region = [7, 11, 49, 53]
              result = generate_map(df, dest; region=custom_region)
              @test result isa GMTWrapper
              @test isfile(dest)

              # Cleanup after Tests
              rm(dest; force=true)
          end =#

        @testset "agsmap tests" begin
            # Example AGS-Values with exact 8 Numbers
            ags_states = [AGS("01000000"), AGS("02000000"), AGS("03000000")]  # States (Level 1)
            ags_counties = [AGS("01001000"), AGS("02002000"), AGS("03003000")]  # counties (Level 2)
            ags_municipalities = [AGS("01001001"), AGS("02002002"), AGS("03003003")]  # municipalities (Level 3)

            # Test: normal usage for states (Level 1)
            df = DataFrame(ags=ags_states, values=[10, 20, 30])
            result = agsmap(df)
            @test result isa Plots.Plot

             # Test: normal usage for counties (Level 2)
            df = DataFrame(ags=ags_counties, values=[15, 25, 35])
            result = agsmap(df)
            @test result isa Plots.Plot

             # Test: normal usage for municipalities (Level 3)
            df = DataFrame(ags=ags_municipalities, values=[5, 15, 25])
            result = agsmap(df)
            @test result isa Plots.Plot

            # Test: wrong columns in the DataFrame → Should throw an error
            df_wrong = DataFrame(id=ags_states, values=[10, 20, 30])
            @test_throws "The first column of the input dataframe must be named 'ags'." agsmap(df_wrong)

            # Test: First column is not AGS → Should throw an error
            df_wrong_type = DataFrame(ags=["01000000", "02000000", "03000000"], values=[10, 20, 30])
            @test_throws "The first column of the input dataframe must contain a Vector of AGS structs" agsmap(df_wrong_type)

            # Test: Second column does not contain numeric values → Should throw an error
            df_wrong_values = DataFrame(ags=ags_states, values=["low", "medium", "high"])
            @test_throws "The second column of the input dataframe must contain a Vector of numeric values" agsmap(df_wrong_values)

            # Test: double AGS-values → Should throw an error
            df_duplicate = DataFrame(ags=[AGS("01000000"), AGS("01000000"), AGS("02000000")], values=[10, 20, 30])
            @test_throws "All AGS values need to be unique!" agsmap(df_duplicate)

        end
        @testset "agsmap wrapper tests" begin
            # Example AGS-values with exact 8 Numbers
            ags_states = [AGS("01000000"), AGS("02000000"), AGS("03000000")]  # states (Level 1)
            ags_counties = [AGS("01001000"), AGS("02002000"), AGS("03003000")]  # counties (Level 2)
            ags_municipalities = [AGS("01001001"), AGS("02002002"), AGS("03003003")]  # municipalities (Level 3)

            # Test: Automatic detection of states
            df_states = DataFrame(ags=ags_states, values=[10, 20, 30])
            result = agsmap(df_states)
            @test result isa Plots.Plot

            # Test: Automatic detection of counties
            df_counties = DataFrame(ags=ags_counties, values=[15, 25, 35])
            result = agsmap(df_counties)
            @test result isa Plots.Plot

            # Test: Automatic detection of municipalities
            df_municipalities = DataFrame(ags=ags_municipalities, values=[5, 15, 25])
            result = agsmap(df_municipalities)
            @test result isa Plots.Plot

            #JoPo: TODO: This needs rework as we now enabled agsmap to take mixed levels and adjust them automatically

            # Test: Manual specification of level
            # df_mixed = DataFrame(ags=[AGS("01000000"), AGS("02000000")], values=[10, 20])
            # result = agsmap(df_mixed, level=1)
            # @test result isa Plots.Plot
            # @test_throws "The AGSs provided in the input dataframes are not all refering to counties (level 2)" agsmap(df_mixed, level=2)
            # @test_throws "The AGSs provided in the input dataframes are not all refering to municipalities (level 3)" agsmap(df_mixed, level=3)


            # df_mixed = DataFrame(ags=[AGS("01010000"), AGS("02010000")], values=[10, 20])
            # result = agsmap(df_mixed, level=2)
            # @test result isa Plots.Plot
            # @test_throws "The AGSs provided in the input dataframes are not all refering to states (level 1)" agsmap(df_mixed, level=1)

            # df_mixed = DataFrame(ags=[AGS("01010100"), AGS("02010100")], values=[10, 20])
            # result = agsmap(df_mixed, level=3)
            # @test result isa Plots.Plot
            # @test_throws "The AGSs provided in the input dataframes are not all refering to states (level 1)" agsmap(df_mixed, level=1)
            # @test_throws "The AGSs provided in the input dataframes are not all refering to counties (level 2)" agsmap(df_mixed, level=2)

            # # Test: specific Wrapper-Functions
            # result = statemap(df_states)
            # @test result isa Plots.Plot

            # result = countymap(df_counties)
            # @test result isa Plots.Plot

            # result = municipalitymap(df_municipalities)
            # @test result isa Plots.Plot

            # # Test: Wrapper with additional Plot-arguments
            # result = agsmap(df_states, title="State Map", fillcolor=:blue)
            # @test result isa Plots.Plot

            # result = countymap(df_counties, title="County Map", fillcolor=:green)
            # @test result isa Plots.Plot

            # result = municipalitymap(df_municipalities, title="Municipality Map", fillcolor=:red)
            # @test result isa Plots.Plot
        end
        @testset "prepare_map_df! tests" begin
            # Example AGS-values with exact 8 Numbers
            ags_states = [AGS("01000000"), AGS("02000000"), AGS("03000000")]  # States (Level 1)
            ags_counties = [AGS("01001000"), AGS("02002000"), AGS("03003000")]  # counties (Level 2)
            ags_municipalities = [AGS("01001001"), AGS("02002002"), AGS("03003003")]  # municipalities (Level 3)

            # Test: Change to State-Level
            df_states = DataFrame(ags=ags_municipalities, values=[10, 20, 30])
            prepare_map_df!(df_states, level=1)
            @test all(is_state.(df_states.ags))
            @test length(unique(df_states.ags)) == 3

            # Test: Change to counties-Level
            df_counties = DataFrame(ags=ags_municipalities, values=[10, 20, 30])
            prepare_map_df!(df_counties, level=2)
            @test all(is_county.(df_counties.ags))
            @test length(df_counties.ags) == 3

            # Test: Change to municipalities-Level
            df_municipalities = DataFrame(ags=ags_municipalities, values=[10, 20, 30])
            prepare_map_df!(df_municipalities, level=3)
            @test !(any(is_state.(df_municipalities.ags)))
            @test length(df_municipalities.ags) == 3

            # Test: error for wrong column name
            df_wrong = DataFrame(id=ags_municipalities, values=[10, 20, 30])
            @test_throws "The first column of the input dataframe must be named 'ags'." prepare_map_df!(df_wrong, level=1)

            # Test: error for wrong datatype
            df_wrong_type = DataFrame(ags=["01000000", "02000000", "03000000"], values=[10, 20, 30])
            @test_throws "The first column of the input dataframe must contain a Vector of AGS structs" prepare_map_df!(df_wrong_type, level=1)
        end
        @testset "MapPlot Abstract Type Tests" begin
            # Test, if MapPlot ein Subtype of ReportPlot
            @test MapPlot <: ReportPlot

            # Test, if an implementation of MapPlot is necessary
            struct DummyMapPlot <: MapPlot end  # Dummy-Subtype

            dummy_plot = DummyMapPlot()
            data = Dict("example" => 42)

            @test_throws ErrorException generate(dummy_plot, data)  # → Should throw an error
        end

        @testset "maptypes() Function Test" begin
            expected_maps = [:AgeMap, :AttackRateMap, :CaseFatalityMap, :DummyMapPlot,
                :HouseholdSizeMap, :PopDensityMap, :SinglesMap]

            result = maptypes()

            @test result isa Vector{Symbol}  # Prüft, ob das Ergebnis ein Vektor von Symbolen ist
            # JoPo: This is no a good test as it will crash as soon as somebody adds a new map type...
            #@test length(result) == 7  # Prüft, ob genau 7 Elemente enthalten sind
            # JoPo: See above...
            #@test Set(result) == Set(expected_maps)  # Prüft, ob die Elemente übereinstimmen (unabhängig von der Reihenfolge)
        end

        @testset "gemsmap() Function Tests" begin
            # Simulations- and ResultData- Objects
            sim = Simulation()
            rd = sim |> PostProcessor |> ResultData

            # expected maptypes
            map_types = [:AgeMap, :AttackRateMap, :CaseFatalityMap,
                :HouseholdSizeMap, :PopDensityMap, :SinglesMap]

            # Test: gemsmap for all known maptypes
            for map_type in map_types
                if map_type in [:AttackRateMap, :CaseFatalityMap]
                    result = gemsmap(rd, type=map_type)
                else
                    result = gemsmap(sim, type=map_type)
                end

                @test result isa Plots.Plot  # check if result is a Plots.Plot
            end

            # Test: change of level correct?
            result = gemsmap(sim, type=:AgeMap, level=1)
            @test result isa Plots.Plot

            result = gemsmap(sim, type=:AgeMap, level=2)
            @test result isa Plots.Plot

            result = gemsmap(sim, type=:AgeMap, level=3)
            @test result isa Plots.Plot

            # Test: unknown plot types throws an error
            @test_throws "There's no plot type that matches :UnknownMap" gemsmap(sim, type=:UnknownMap)

            # Test: Plot with additional arguments
            result = gemsmap(sim, type=:AgeMap, title="Test Map", clims=(0, 100))
            @test result isa Plots.Plot
        end

        @testset "Map Plots" begin
            
            sim_maps = [
                :AgeMap,
                :ElderlyMap,
                :HouseholdSizeMap,
                :KidsMap,
                :MultiGenHouseholdMap,
                :PopDensityMap,
                :SinglesMap
            ]

            rd_maps = [
                :AttackRateMap,
                :CaseFatalityMap,
                :R0Map,
                :WeeklyIncidenceMap
            ]

            # generate each map without geolocated data
            # this should (at least) not crash
            sim = Simulation()
            (m -> gemsmap(sim, type = m)).(sim_maps) |>
                plts -> @test all(p -> p isa Plots.Plot, plts)
            run!(sim)
            rd = ResultData(sim)
            (m -> gemsmap(rd, type = m)).(rd_maps) |>
                plts -> @test all(p -> p isa Plots.Plot, plts)

            # generate each map with geolocated data
            sim_HB = Simulation(population="HB")            
            (m -> gemsmap(sim_HB, type = m)).(sim_maps) |>
                plts -> @test all(p -> p isa Plots.Plot, plts)
            run!(sim_HB)
            rd_HB = ResultData(sim_HB)
            (m -> gemsmap(rd_HB, type = m)).(rd_maps) |>
                plts -> @test all(p -> p isa Plots.Plot, plts)
        end

    end

    @testset "Plots Test" begin

        @testset "GMTWrapper Tests" begin
            # Test: GMTWrapper saves the correct path
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
            # Test: fontfamily! for Plots.jl
            p = plot(rand(10))
            fontfamily!(p, "Arial")
            @test p.attr[:fontfamily] == "Arial"

            fontfamily!(p, "Times New Roman")
            @test p.attr[:fontfamily] == "Times Roman"

            # Test: dpi! for Plots.jl
            dpi!(p, 300)
            @test p.attr[:dpi] == 300

            # TODO: Test: title! for Plots.jl
            GEMS.title!(p, "Test Title")
            GEMS.titlefontsize!(p, 18)
        end

    end

end
#=
@testset "Movie Tests" begin
    @testset "steps function" begin
        @test GEMS.steps(3, 10) ≈ [10.25, 10.5, 10.75]
        @test GEMS.steps(0, 5) == []
    end

    @testset "generate_frame creates image file" begin
        df_coords = DataFrame(lat=[52.52, 48.13], lon=[13.405, 11.582], show=[true, true])
        active_inf = DataFrame(time=[0.0, 1.0], count=[0.0, 2.0])
        region = [10.0, 15.0, 45.0, 55.0]  # lon_min, lon_max, lat_min, lat_max
        plot_xmax = 10
        plot_ymax = 5
        xlabel = "Days"

        mktempdir() do dir
            path = joinpath(dir, "frame_test.png")
            result = GEMS.generate_frame(df_coords, path, region, active_inf, plot_xmax, plot_ymax, xlabel)

            @test isfile(path)
            @test result isa GMTWrapper

            img = load(path)
            @test size(img)[1] > 0
            @test size(img)[2] > 0
        end
    end
end =#