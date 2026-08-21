@testset "Logger" begin
    test_rng = Xoshiro()

    @testset "InfectionLogger" begin

        attributes = [
            "infection_id",
            "id_a",
            "id_b",
            "pathogen_id",
            "progression_category",
            "infectiousness_onset",
            "symptom_onset",
            "severeness_onset",
            "critical_onset",
            "critical_offset",
            "severeness_offset",
            "recovery",
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
                pathogen_id = Int8(0),
                progression_category = Symbol(Asymptomatic),
                tick = Int16(0),
                infectiousness_onset = Int16(0),
                symptom_onset = Int16(0),
                severeness_onset = Int16(0),
                critical_onset = Int16(0),
                critical_offset = Int16(0),
                severeness_offset = Int16(0),
                recovery = Int16(0),
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
            infect!(infecter, t, first_pathogen(sim), sim = sim, rng = rng(sim))
            
            # flatten logger internal arrays to a dataframe to check values
            df1 = dataframe(il)
            @test df1.tick[end] == t
            @test df1.id_a[end] == -1
            @test df1.id_b[end] == id(infecter)
            @test df1.progression_category[end] == Symbol(Asymptomatic)
            @test df1.infectiousness_onset[end] >= t+3
            @test df1.symptom_onset[end] == GEMS.DEFAULT_TICK
            @test df1.severeness_onset[end] == GEMS.DEFAULT_TICK
            @test df1.critical_onset[end] == GEMS.DEFAULT_TICK
            @test df1.critical_offset[end] == GEMS.DEFAULT_TICK
            @test df1.severeness_offset[end] == GEMS.DEFAULT_TICK
            @test df1.recovery[end] >= t+10
            @test df1.setting_id[end] == GEMS.DEFAULT_SETTING_ID
            @test df1.setting_type[end] == '?'
            @test df1.lat[end] === NaN32
            @test df1.lon[end] === NaN32
            @test df1.ags[end] == Int32(-1)
            @test df1.source_infection_id[end] == GEMS.DEFAULT_INFECTION_ID

            # infect another agent in a household setting
            t = df1.infectiousness_onset[end]
            infect!(infectee, t, first_pathogen(sim);
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
            @test df2.critical_onset[end] == GEMS.DEFAULT_TICK
            @test df2.critical_offset[end] == GEMS.DEFAULT_TICK
            @test df2.severeness_offset[end] == GEMS.DEFAULT_TICK
            @test df2.recovery[end] >= t+10
            @test df2.setting_id[end] == id(h)
            @test df2.setting_type[end] == 'h'
            @test df2.lat[end] === NaN32
            @test df2.lon[end] === NaN32
            @test df2.ags[end] == Int32(-1)
            @test df2.source_infection_id[end] == df1.infection_id[end]

        end

        @testset "Infecter Index" begin

            # minimal infection record; only a, b and tick matter for the index
            function log_infection!(il, a, b, t)
                log!(il, Int32(a), Int32(b), Int8(1), :Asymptomatic, Int16(t),
                    Int16(0), Int16(0), Int16(0), Int16(0), Int16(0), Int16(0), Int16(0),
                    Int32(0), 'h', Float32(0), Float32(0), Int32(0), Int32(0))
            end

            query(il, a, t0, t1) = get_infections_between(il, Int32(a), Int16(t0), Int16(t1))

            # independent reference implementation: binary-search the tick window in every
            # shard and scan it. This is what the logger did before the index existed and
            # it is deliberately kept here rather than in src, so the indexed path is
            # checked against something that shares none of its code.
            function scan(il, a, t0, t1)
                infecter, start_tick, end_tick = Int32(a), Int16(t0), Int16(t1)
                result = Vector{Int32}()
                for tid in 1:Threads.maxthreadid()
                    first_idx = searchsortedfirst(il.tick[tid], start_tick)
                    last_idx = searchsortedlast(il.tick[tid], end_tick)
                    for i in first_idx:last_idx
                        il.id_a[tid][i] == infecter && push!(result, il.id_b[tid][i])
                    end
                end
                return result
            end

            @testset "Lazy Construction and Backfill" begin
                il = InfectionLogger()

                # infections logged before the first query must still be found
                log_infection!(il, 5, 10, 0)
                log_infection!(il, 5, 11, 1)
                log_infection!(il, 7, 12, 1)
                @test il.infecter_index === nothing

                @test query(il, 5, 0, 5) == Int32[10, 11]
                @test il.infecter_index isa GEMS.InfecterIndex
                @test query(il, 7, 0, 5) == Int32[12]
                @test query(il, 9, 0, 5) == Int32[]
            end

            @testset "Incremental Updates" begin
                il = InfectionLogger()
                log_infection!(il, 5, 10, 0)
                @test query(il, 5, 0, 5) == Int32[10]

                # logged after the index exists, so this goes through register!/_merge_staged!
                log_infection!(il, 5, 11, 2)
                log_infection!(il, 5, 12, 3)
                @test query(il, 5, 0, 5) == Int32[10, 11, 12]
            end

            @testset "Tick Window Boundaries" begin
                il = InfectionLogger()
                for (b, t) in [(10, 0), (11, 2), (12, 4), (13, 6)]
                    log_infection!(il, 5, b, t)
                end

                @test query(il, 5, 2, 4) == Int32[11, 12]     # inclusive both ends
                @test query(il, 5, 3, 3) == Int32[]
                @test query(il, 5, 0, 6) == Int32[10, 11, 12, 13]
                @test query(il, 5, 7, 9) == Int32[]
            end

            @testset "Head Sizing From Declared Range" begin
                # a real population model occupies a slice of a national id space, so
                # minid is far above 1. head must be sized by the range, not by maxid.
                il = InfectionLogger(minid = Int32(72_780_390), maxid = Int32(72_784_389))
                log_infection!(il, 72_780_500, 72_781_000, 0)
                log_infection!(il, 72_780_500, 72_781_001, 1)

                @test query(il, 72_780_500, 0, 5) == Int32[72_781_000, 72_781_001]
                @test length(il.infecter_index.head) == 4000
                @test il.infecter_index.offset == Int32(72_780_390)

                # ids outside the declared range return empty rather than erroring
                @test query(il, 72_780_389, 0, 5) == Int32[]
                @test query(il, 72_784_390, 0, 5) == Int32[]
            end

            @testset "Ids Outside The Index Range" begin
                # a logger with no declared range covers only the ids it was backfilled
                # from; anything beyond that is a mismatch and must not be dropped silently
                il = InfectionLogger()
                log_infection!(il, 5000, 10, 0)
                @test query(il, 5000, 0, 5) == Int32[10]

                log_infection!(il, 500_000, 20, 1)
                @test_throws ArgumentError query(il, 5000, 0, 5)
            end

            @testset "Invalid Infecters" begin
                il = InfectionLogger()
                log_infection!(il, -1, 10, 0)    # seed infection, no infecter
                log_infection!(il, 5, 11, 0)

                @test query(il, -1, 0, 5) == Int32[]
                @test query(il, 0, 0, 5) == Int32[]
                @test query(il, 10_000_000, 0, 5) == Int32[]
                @test query(il, 5, 0, 5) == Int32[11]
            end

            @testset "Equivalence With Reference Scan" begin
                il = InfectionLogger()
                rng = Xoshiro(42)
                next_infectee = 1000
                for t in 0:30
                    for _ in 1:20
                        # unique infectee ids, so tick can be recovered from an id below
                        next_infectee += 1
                        log_infection!(il, rand(rng, 1:50), next_infectee, t)
                    end
                end

                # the indexed path and the full scan must agree on every query
                for a in 1:50, t0 in 0:5:30, t1 in t0:5:30
                    @test sort(query(il, a, t0, t1)) == sort(scan(il, a, t0, t1))
                end

                # and the indexed path returns them in chronological order
                df = dataframe(il)
                ticks = Dict(df.id_b[i] => df.tick[i] for i in eachindex(df.id_b))
                for a in 1:50
                    @test issorted([ticks[b] for b in query(il, a, 0, 30)])
                end
            end

            @testset "Untraced Runs Carry No Index" begin
                sim = Simulation(pop_size = 1000, seed = 7)
                run!(sim, with_progressbar = false)
                @test infectionlogger(sim).infecter_index === nothing
            end

            @testset "Reset Drops The Index" begin
                sim = Simulation(pop_size = 1000, seed = 7)
                run!(sim, with_progressbar = false)

                il = infectionlogger(sim)
                infecter = first(a for a in dataframe(il).id_a if a > 0)
                before = query(il, infecter, -1, tick(sim))
                @test il.infecter_index isa GEMS.InfecterIndex

                GEMS.reset!(sim)
                @test infectionlogger(sim).infecter_index === nothing

                # the rebuilt index on the fresh logger must agree with the fresh scan
                run!(sim, with_progressbar = false)
                il2 = infectionlogger(sim)
                @test sort(query(il2, infecter, -1, tick(sim))) ==
                    sort(scan(il2, Int32(infecter), Int16(-1), tick(sim)))
                @test !isempty(before)
            end
        end

    end

    @testset "VaccinationLogger" begin
        attributes = ["id", "pathogen_id", "tick"]

        @testset "Creation and Basic Functionality" begin
            vl = VaccinationLogger()

            @test vl.last_modified_tick[] == GEMS.DEFAULT_TICK

            for attr in attributes
                @test sum(length, getproperty(vl, Symbol(attr))) == 0
            end

            log!(vl, Int32(0), Int8(0), Int16(0))

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
        attributes = ["id", "pathogen_id", "tick"]

        @testset "Creation and Basic Functionality" begin
            dl = DeathLogger()

            @test dl.last_modified_tick[] == GEMS.DEFAULT_TICK

            for attr in attributes
                @test sum(length, getproperty(dl, Symbol(attr))) == 0
            end

            log!(dl, Int32(0), Int8(0), Int16(0))

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
                        severeness_onset_to_critical_onset = 0,
                        critical_onset_to_critical_offset = 0,
                        critical_offset_to_severeness_offset = 0,
                        severeness_offset_to_recovery = 0,
                        death_probability = 1.0,
                        critical_onset_to_death = 0
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
        loggers = [InfectionLogger(), VaccinationLogger(), DeathLogger(), GEMS.HealthLogger(), PoolTestLogger(), GEMS.TestLogger(), SeroprevalenceLogger()]

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