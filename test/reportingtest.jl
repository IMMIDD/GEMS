@testset "Reporting" begin
    
    basefolder = dirname(dirname(pathof(GEMS)))

    # load example simulation to perform tests
    sim = Simulation(basefolder * "/test/testdata/TestConf.toml", basefolder * "/test/testdata/TestPop.csv")
    run!(sim)
    rd = sim |> PostProcessor |> ResultData

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
        @test Uniform(0,1) |> markdown |> typeof == String
        @test Poisson(4) |> markdown |> typeof == String

        # Settings SettingsContainer
        @test sim |> settings |> markdown |> typeof == String#
        
    end
    
    @testset "Sections" begin

        # sections

        s1 = Section(
            title = "First Heading",
            content = "Test Content"
        )

        @test s1 |> title == "First Heading"
        @test s1 |> content == "Test Content"

        GEMS.title!(s1, "New Heading")
        content!(s1, "New Content")

        @test s1 |> title == "New Heading"
        @test s1 |> content == "New Content"

        # subsections

        s2 = Section(
            title = "Subsection",
            content = "Sub Content"
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
            data = rd,
            title = "Test Report",
            author = "Tester",
            date = rd |> execution_date,
            abstract = "Test Abstract"
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

        s = Section(title = "Test Section")
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
            PopulationPyramid(),
            # SettingAgeContacts(Household), # (superseded by AggregatedSettingAgeContacts)
            # SettingAgeContacts(GlobalSetting),
            AggregatedSettingAgeContacts(Household),
            TickCases(),
            CumulativeCases(),
            SymptomCategories(),
            LatencyHistogram(),
            InfectiousHistogram(),
            EffectiveReproduction(),
            Incidence()
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
            function TestReportStyle(;data)
                rep = new(data,"Test","Test","Test","Test",[],false,"Test")
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
end