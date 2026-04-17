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

            # test new last_modified_tick attribute initialization
            @test il.last_modified_tick[] == GEMS.DEFAULT_TICK

            # logger works with Vector of Vectors now, check if total length is 0
            for attr in attributes
                @test sum(length, getproperty(il, Symbol(attr))) == 0
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

            # test that last_modified_tick was updated by the log! function
            @test il.last_modified_tick[] == Int16(0)

            # check if logged correctly across all threads
            for attr in attributes
                @test sum(length, getproperty(il, Symbol(attr))) == 1
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
            
            # flatten logger internal arrays to a dataframe to check values
            df1 = dataframe(il)
            @test df1.tick[end] == t
            @test df1.id_a[end] == -1
            @test df1.id_b[end] == id(infecter)
            @test df1.progression_category[end] == Symbol(Asymptomatic)
            @test df1.infectiousness_onset[end] >= t+3
            @test df1.symptom_onset[end] == GEMS.DEFAULT_TICK
            @test df1.severeness_onset[end] == GEMS.DEFAULT_TICK
            @test df1.hospital_admission[end] == GEMS.DEFAULT_TICK
            @test df1.hospital_discharge[end] == GEMS.DEFAULT_TICK
            @test df1.icu_admission[end] == GEMS.DEFAULT_TICK
            @test df1.icu_discharge[end] == GEMS.DEFAULT_TICK
            @test df1.ventilation_admission[end] == GEMS.DEFAULT_TICK
            @test df1.ventilation_discharge[end] == GEMS.DEFAULT_TICK
            @test df1.severeness_offset[end] == GEMS.DEFAULT_TICK
            @test df1.recovery[end] >= t+10
            @test df1.death[end] == GEMS.DEFAULT_TICK
            @test df1.setting_id[end] == GEMS.DEFAULT_SETTING_ID
            @test df1.setting_type[end] == '?'
            @test df1.lat[end] === NaN32
            @test df1.lon[end] === NaN32
            @test df1.ags[end] == Int32(-1)
            @test df1.source_infection_id[end] == GEMS.DEFAULT_INFECTION_ID

            # infect another agent in a household setting
            t = df1.infectiousness_onset[end]
            infect!(infectee, t, pathogen(sim);
                sim=sim,
                rng=rng(sim),
                infecter_id=id(infecter),
                setting_id=id(h),
                setting_type=settingchar(h),
                source_infection_id = df1.infection_id[end])

            df2 = dataframe(il)
            @test df2.tick[end] == t
            @test df2.id_a[end] == id(infecter)
            @test df2.id_b[end] == id(infectee)
            @test df2.progression_category[end] == Symbol(Asymptomatic)
            @test df2.infectiousness_onset[end] >= t+3
            @test df2.symptom_onset[end] == GEMS.DEFAULT_TICK
            @test df2.severeness_onset[end] == GEMS.DEFAULT_TICK
            @test df2.hospital_admission[end] == GEMS.DEFAULT_TICK
            @test df2.hospital_discharge[end] == GEMS.DEFAULT_TICK
            @test df2.icu_admission[end] == GEMS.DEFAULT_TICK
            @test df2.icu_discharge[end] == GEMS.DEFAULT_TICK
            @test df2.ventilation_admission[end] == GEMS.DEFAULT_TICK
            @test df2.ventilation_discharge[end] == GEMS.DEFAULT_TICK
            @test df2.severeness_offset[end] == GEMS.DEFAULT_TICK
            @test df2.recovery[end] >= t+10
            @test df2.death[end] == GEMS.DEFAULT_TICK
            @test df2.setting_id[end] == id(h)
            @test df2.setting_type[end] == 'h'
            @test df2.lat[end] === NaN32
            @test df2.lon[end] === NaN32
            @test df2.ags[end] == Int32(-1)
            @test df2.source_infection_id[end] == df1.infection_id[end]

        end

    end

    @testset "VaccinationLogger" begin
        attributes = ["id", "tick"]

        @testset "Creation and Basic Functionality" begin
            vl = VaccinationLogger()

            @test vl.last_modified_tick[] == GEMS.DEFAULT_TICK

            for attr in attributes
                @test sum(length, getproperty(vl, Symbol(attr))) == 0
            end

            log!(vl, Int32(0), Int16(0))
            
            # test that last_modified_tick was updated by the log! function
            @test vl.last_modified_tick[] == Int16(0)

            # Use dataframe to flatten arrays for tests
            df_vl = dataframe(vl)
            for attr in attributes
                @test length(getproperty(df_vl, Symbol(attr))) == 1
                # looks weird, but does the job
                @test getproperty(df_vl, Symbol(attr))[1] == typeof(getproperty(df_vl, Symbol(attr))[1])(0)
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

    end

    @testset "DeathLogger" begin
        attributes = ["id", "tick"]

        @testset "Creation and Basic Functionality" begin
            dl = DeathLogger()

            @test dl.last_modified_tick[] == GEMS.DEFAULT_TICK

            for attr in attributes
                @test sum(length, getproperty(dl, Symbol(attr))) == 0
            end

            log!(dl, Int32(0), Int16(0))

            # test that last_modified_tick was updated by the log! function
            @test dl.last_modified_tick[] == Int16(0)

            df_dl = dataframe(dl)
            for attr in attributes
                @test length(getproperty(df_dl, Symbol(attr))) == 1
                # looks weird, but does the job
                @test getproperty(df_dl, Symbol(attr))[1] == typeof(getproperty(df_dl, Symbol(attr))[1])(0)
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

            # death logger should be empty (use length() function)
            dl = deathlogger(sim)
            @test length(dl) == 0

            # run simulation
            run!(sim)

            # now everybody should be dead
            @test sum(is_dead.(inds)) == n_inf 

            # all deaths should have been logged
            @test length(dl) == n_inf
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