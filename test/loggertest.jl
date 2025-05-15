@testset "Logger" begin
    test_rng = Xoshiro()

    @testset "InfectionLogger" begin

        attributes = [
            "id_a",
            "id_b",
            "infectious_tick",
            "removed_tick",
            "tick",
            "setting_id",
            "setting_type"
        ]

        @testset "Creation and Basic Functionality" begin
            il = InfectionLogger()

            # logger works with single row vectors, so they should all be empty
            for attr in attributes
                @test length(getproperty(il, Symbol(attr))) == 0
            end

            log!(il,
                Int32(0), # individual a
                Int32(0), # individual b
                Int16(0), # tick
                Int16(0), # infectious tick
                Int16(0), # symptoms tick
                Int16(0), # severeness tick
                Int16(0), # hospital tick
                Int16(0), # icu tick
                Int16(0), # ventilation tick
                Int16(0), # removed tick
                Int16(0), # death tick
                Int8(0), # symptom category
                Int32(0), # setting id
                Char(0), # setting type
                Float32(0), # lat
                Float32(0), # lon
                Int32(0), # ags
                Int32(0) # source infection id
            )

            for attr in attributes
                @test length(getproperty(il, Symbol(attr))) == 1
                # looks weird, but does the job
                @test getproperty(il, Symbol(attr))[1] == typeof(getproperty(il, Symbol(attr))[1])(0)
            end

            # conversion to dataframe
            df = dataframe(il)
            @test typeof(df) <: DataFrame
            for attr in attributes
                @test length(getproperty(df, Symbol(attr))) == 1
                # looks weird, but does the job
                @test getproperty(df, Symbol(attr))[1] == typeof(getproperty(df, Symbol(attr))[1])(0)
            end

        end

        @testset "Logging Infections" begin
            BASE_FOLDER = dirname(dirname(pathof(GEMS)))
            sim = Simulation(BASE_FOLDER * "/test/testdata/NoInfections.toml")

            infecter = (sim|>population|>individuals)[1]
            infectee = (sim|>population|>individuals)[2]

            t = Int16(100)
            il = infectionlogger(sim)
            h = household(infectee, sim)

            infect!(infecter, t, pathogen(sim), sim=sim)

            @test il.tick[end] == t
            @test il.id_a[end] == -1
            @test il.id_b[end] == id(infecter)
            @test il.removed_tick[end] > t
            @test il.infectious_tick[end] >= t
            @test il.setting_id[end] == GEMS.DEFAULT_SETTING_ID
            @test il.setting_type[end] == '?'

            t = il.infectious_tick[end]

            infect!(infectee, t, pathogen(sim); sim=sim, infecter_id=id(infecter), setting_id=id(h), setting_type=settingchar(h))
            @test il.tick[end] == t
            @test il.id_a[end] == id(infecter)
            @test il.id_b[end] == id(infectee)
            @test il.removed_tick[end] > t
            @test il.infectious_tick[end] >= t
            @test il.setting_id[end] == id(h)
            @test il.setting_type[end] == 'h'

        end

    end

    @testset "VaccinationLogger" begin
        attributes = ["id", "tick"]

        @testset "Creation and Basic Functionality" begin
            vl = VaccinationLogger()

            for attr in attributes
                @test length(getproperty(vl, Symbol(attr))) == 0
            end

            log!(vl, Int32(0), Int16(0))

            for attr in attributes
                @test length(getproperty(vl, Symbol(attr))) == 1
                # looks weird, but does the job
                @test getproperty(vl, Symbol(attr))[1] == typeof(getproperty(vl, Symbol(attr))[1])(0)
            end

            # conversion to dataframe
            df = dataframe(vl)
            @test typeof(df) <: DataFrame
            for attr in attributes
                @test length(getproperty(df, Symbol(attr))) == 1
                # looks weird, but does the job
                @test getproperty(df, Symbol(attr))[1] == typeof(getproperty(df, Symbol(attr))[1])(0)
            end
        end

        # @testset "Logging Vaccinations" begin
        #     ind1 = Individual(id=1, age=18, sex=0)
        #     ind2 = Individual(id=2, age=20, sex=1)
        #     vacc = Vaccine(id=1, name="Test")
        #     vl = logger(vacc)

        #     vaccinate!(ind1, vacc, Int16(21))
        #     vaccinate!(ind2, vacc, Int16(42))

        #     @test vl.id[end-1] == Int32(1)
        #     @test vl.id[end] == Int32(2)
        #     @test vl.tick[end-1] == Int16(21)
        #     @test vl.tick[end] == Int16(42) 
        # end
    end

    @testset "DeathLogger" begin
        attributes = ["id", "tick"]

        @testset "Creation and Basic Functionality" begin
            dl = DeathLogger()

            for attr in attributes
                @test length(getproperty(dl, Symbol(attr))) == 0
            end

            log!(dl, Int32(0), Int16(0))

            for attr in attributes
                @test length(getproperty(dl, Symbol(attr))) == 1
                # looks weird, but does the job
                @test getproperty(dl, Symbol(attr))[1] == typeof(getproperty(dl, Symbol(attr))[1])(0)
            end

            # conversion to dataframe
            df = dataframe(dl)
            @test typeof(df) <: DataFrame
            for attr in attributes
                @test length(getproperty(df, Symbol(attr))) == 1
                # looks weird, but does the job
                @test getproperty(df, Symbol(attr))[1] == typeof(getproperty(df, Symbol(attr))[1])(0)
            end
        end

        @testset "Logging Deaths" begin
            # TODO 
            rs = RandomSampling()

            p = Pathogen(id=1, name="Test")
            exposedtick = Int16(0)
            indiv = Individual(id=42, sex=1, age=40)

            indiv.exposed_tick = exposedtick
            indiv.disease_state = 1
            indiv.number_of_infections += 1
            indiv.pathogen_id = id(p)

            Random.seed!(test_rng, 1234)
            disease_progression!(indiv, p, exposedtick, GEMS.Mild, rng=test_rng)

            # doesn't matter if indiv would have survived, we will kill it nonetheless
            indiv.death_tick = 1

            h = Household(id=1, individuals=[indiv], contact_sampling_method=rs)
            stngs = SettingsContainer()
            add_type!(stngs, Household)
            add!(stngs, h)
            sim = Simulation(
                "",
                InfectedFraction(0, p),
                TimesUp(420),
                Population([indiv]),
                stngs,
                "test"
            )

            for i in individuals(h, sim)
                update_individual!(i, Int16(1), sim)
            end
            @test dead(indiv)
            dl = deathlogger(sim)
            @test dl.id[end] == Int32(42)
            @test dl.tick[end] == Int16(1)
        end
    end

    @testset "Saving Loggerfiles" begin
        # Create logger and log a known infection
        loggers = [InfectionLogger(), VaccinationLogger(), DeathLogger(), PoolTestLogger(), GEMS.TestLogger()]

        for logger in loggers
            # Save to a temp file
            path = tempname() * ".csv"
            GEMS.save(logger, path)

            # Check file exists
            @test isfile(path)

            # Load back in
            df_written = CSV.read(path, DataFrame)

            # Check that it matches dataframe(logger)
            expected_df = dataframe(logger)
            @test df_written == expected_df

            # Cleanup
            rm(path; force=true)
        end
        for logger in loggers
            # Save to a temporary JLD2 file
            path = tempname() * ".jld2"
            save_JLD2(logger, path)

            @test isfile(path)

            # Cleanup
            rm(path; force=true)
        end
        for logger in loggers
            @test length(logger) == 0
        end
        logger = QuarantineLogger()
        @test length(logger) == 0
        custom_logger = CustomLogger()
        @test length(custom_logger) == 0
    end
end