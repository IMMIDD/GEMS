@testset "Logger" begin
    test_rng = Xoshiro()

    @testset "InfectionLogger" begin

        attributes = [
            "infection_id",
            "id_a",
            "id_b",
            "progression_category",
            "infectiousness_onset",
            "symptom_onset",
            "severeness_onset",
            "hospital_admission",
            "hospital_discharge",
            "icu_admission",
            "icu_discharge",
            "ventilation_admission",
            "ventilation_discharge",
            "severeness_offset",
            "recovery",
            "death",
            "tick",
            "setting_id",
            "setting_type",
            "lat",
            "lon",
            "ags",
            "source_infection_id",
        ]

        @testset "Creation and Basic Functionality" begin
            il = InfectionLogger()

            # logger works with single row vectors, so they should all be empty
            for attr in attributes
                @test length(getproperty(il, Symbol(attr))) == 0
            end

            log!(
                logger = il,
                a = Int32(0),
                b = Int32(0),
                progression_category = Symbol(Asymptomatic),
                tick = Int16(0),
                infectiousness_onset = Int16(0),
                symptom_onset = Int16(0),
                severeness_onset = Int16(0),
                hospital_admission = Int16(0),
                hospital_discharge = Int16(0),
                icu_admission = Int16(0),
                icu_discharge = Int16(0),
                ventilation_admission = Int16(0),
                ventilation_discharge = Int16(0),
                severeness_offset = Int16(0),
                recovery = Int16(0),
                death = Int16(0),
                setting_id = Int32(0),
                setting_type = 'h',
                lat = Float32(0),
                lon = Float32(0),
                ags = Int32(0),
                source_infection_id = Int32(0)
            )

            # check if logged correctly
            for attr in attributes
                @test length(getproperty(il, Symbol(attr))) == 1
            end

            # conversion to dataframe
            df = dataframe(il)
            @test typeof(df) <: DataFrame
            for attr in attributes
                @test length(getproperty(df, Symbol(attr))) == 1
            end

            # this should not work
            @test_throws MethodError log!(il, a = Int32(0)) # missing required arguments
            
        end

        @testset "Logging Infections" begin
            sim = Simulation(pop_size = 1000, infected_fraction = 0.0,
                pathogen = Pathogen(
                    name = "TestPathogen",
                    progressions = [Asymptomatic(
                        exposure_to_infectiousness_onset = 3,
                        infectiousness_onset_to_recovery = 7,
                    )]
            ))

            infecter = (sim|>population|>individuals)[1]
            infectee = (sim|>population|>individuals)[2]

            t = Int16(100)
            il = infectionlogger(sim)
            h = household(infectee, sim)

            # infect one agent
            infect!(infecter, t, pathogen(sim), sim = sim, rng = rng(sim))
            
            @test il.tick[end] == t
            @test il.id_a[end] == -1
            @test il.id_b[end] == id(infecter)
            @test il.progression_category[end] == Symbol(Asymptomatic)
            @test il.infectiousness_onset[end] >= t+3
            @test il.symptom_onset[end] == GEMS.DEFAULT_TICK
            @test il.severeness_onset[end] == GEMS.DEFAULT_TICK
            @test il.hospital_admission[end] == GEMS.DEFAULT_TICK
            @test il.hospital_discharge[end] == GEMS.DEFAULT_TICK
            @test il.icu_admission[end] == GEMS.DEFAULT_TICK
            @test il.icu_discharge[end] == GEMS.DEFAULT_TICK
            @test il.ventilation_admission[end] == GEMS.DEFAULT_TICK
            @test il.ventilation_discharge[end] == GEMS.DEFAULT_TICK
            @test il.severeness_offset[end] == GEMS.DEFAULT_TICK
            @test il.recovery[end] >= t+10
            @test il.death[end] == GEMS.DEFAULT_TICK
            @test il.setting_id[end] == GEMS.DEFAULT_SETTING_ID
            @test il.setting_type[end] == '?'
            @test il.lat[end] === NaN32
            @test il.lon[end] === NaN32
            @test il.ags[end] == Int32(-1)
            @test il.source_infection_id[end] == GEMS.DEFAULT_INFECTION_ID

            # infect another agent in a household setting
            t = il.infectiousness_onset[end]
            infect!(infectee, t, pathogen(sim);
                sim=sim,
                rng=rng(sim),
                infecter_id=id(infecter),
                setting_id=id(h),
                setting_type=settingchar(h),
                source_infection_id = il.infection_id[end])

            @test il.tick[end] == t
            @test il.id_a[end] == id(infecter)
            @test il.id_b[end] == id(infectee)
            @test il.progression_category[end] == Symbol(Asymptomatic)
            @test il.infectiousness_onset[end] >= t+3
            @test il.symptom_onset[end] == GEMS.DEFAULT_TICK
            @test il.severeness_onset[end] == GEMS.DEFAULT_TICK
            @test il.hospital_admission[end] == GEMS.DEFAULT_TICK
            @test il.hospital_discharge[end] == GEMS.DEFAULT_TICK
            @test il.icu_admission[end] == GEMS.DEFAULT_TICK
            @test il.icu_discharge[end] == GEMS.DEFAULT_TICK
            @test il.ventilation_admission[end] == GEMS.DEFAULT_TICK
            @test il.ventilation_discharge[end] == GEMS.DEFAULT_TICK
            @test il.severeness_offset[end] == GEMS.DEFAULT_TICK
            @test il.recovery[end] >= t+10
            @test il.death[end] == GEMS.DEFAULT_TICK
            @test il.setting_id[end] == id(h)
            @test il.setting_type[end] == 'h'
            @test il.lat[end] === NaN32
            @test il.lon[end] === NaN32
            @test il.ags[end] == Int32(-1)
            @test il.source_infection_id[end] == il.infection_id[end-1]

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
            # simulation with 100 infected individuals who will all die
            sim = Simulation(pop_size = 1000, infected_fraction = 0.1,
                pathogen = Pathogen(
                    name = "TestPathogen",
                    progressions = [GEMS.Critical(
                        exposure_to_infectiousness_onset = 1,
                        infectiousness_onset_to_symptom_onset = 0,
                        symptom_onset_to_severeness_onset = 0,
                        severeness_onset_to_hospital_admission = 0,
                        hospital_admission_to_icu_admission = 0,
                        icu_admission_to_icu_discharge = 0,
                        icu_discharge_to_hospital_discharge = 0,
                        hospital_discharge_to_severeness_offset = 0,
                        severeness_offset_to_recovery = 0,
                        icu_admission_to_death = 0,
                        death_probability = 1.0
                    )]
            ))

            # exactly 100 persons should be infected
            inds = individuals(sim) |>
                i -> i[is_infected.(i)]
            n_inf = length(inds)
            @test n_inf == 100

            # death logger should be empty
            dl = deathlogger(sim)
            @test length(dl.id) == 0

            # run simulation
            run!(sim)

            # now everybody should be dead
            @test sum(is_dead.(inds)) == n_inf 

            # all deaths should have been logged
            @test length(dl.id) == n_inf
        end
    end

    @testset "Saving Loggerfiles" begin
        # Create logger and log a known infection
        loggers = [InfectionLogger(), VaccinationLogger(), DeathLogger(), PoolTestLogger(), GEMS.TestLogger(), SeroprevalenceLogger()]

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