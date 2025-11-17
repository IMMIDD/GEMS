@testset "Infections" begin
    test_rng = Xoshiro()

    @testset "Agent-Level" begin

        @testset "Basic Infection" begin
            rs = RandomSampling()

            i = Individual(id = 1, sex = 0, age = 31, household=1)
            p = Pathogen(id = 1, name = "COVID")

            # testing infection routines
            infect!(i, Int16(0), p)

            @test pathogen_id(i) == id(p)
            @test disease_state(i) == 1
            @test infectiousness(i) == 0
            @test number_of_infections(i) == 1
            @test exposed_tick(i) == 0
            @test infectious_tick(i) >= 1
            @test infectious_tick(i) <= 3
            @test removed_tick(i) >= 3
            @test removed_tick(i) <= 9
            @test infected(i)
            @test !infectious(i)

            # set infectiousness (64 as median value of potential range)
            infectiousness!(i, 64)

            @test infected(i)
            @test infectious(i)
            @test infectiousness(i) > 0

            # test recovery
            recover!(i)
            @test disease_state(i) == 0
            @test infectiousness(i) == 0
            @test !infected(i)
            @test !infectious(i)

            # redefine to reset
            i = Individual(id = 1, sex = 0, age = 31, household=1)
            p = Pathogen(id = 1, name = "COVID")
            h = Household(id=1, individuals=[i], contact_sampling_method = rs)
            stngs = SettingsContainer()
            add_type!(stngs, Household)
            add!(stngs, h)
        end

        @testset "Try to infect" begin
            rs = RandomSampling()

            infctr = Individual(id = 1, sex = 0, age = 31, household=1)
            infctd =Individual(id = 2, sex = 0, age = 32, household=1)
            p = Pathogen(id = 1, name = "COVID19")
            h = Household(id=1, individuals=[infctr, infctd], contact_sampling_method = rs)
            stngs = SettingsContainer()
            add_type!(stngs, Household)
            add!(stngs, h)

            # dummy simulation for infections
            sim = Simulation(
                "",
                InfectedFraction(0,p),
                TimesUp(420),
                Population([infctr,infctd]),
                stngs,
                "test"   
            )
            
            # infect with this seed
            Random.seed!(sim.thread_rngs[1], 42)
            @test false == try_to_infect!(infctr, infctd, sim, pathogen(sim), h)
            
            # This seed works
            Random.seed!(sim.thread_rngs[1], 1)
            @test true == try_to_infect!(infctr, infctd, sim, pathogen(sim), h)

            # unable to infect, when already infected
            Random.seed!(sim.main_rng, 1)
            i = Individual(id = 1, sex = 0, age = 31, household = 1)
            infect!(i, Int16(0), p, rng=sim.main_rng)
            @test false == try_to_infect!(infctr, infctd, sim, pathogen(sim), h)

            # unable to infect, when already dead
            i = Individual(id = 1, sex = 0, age = 31, household=1)
            i.dead = true
            @test false == try_to_infect!(infctr, infctd, sim, pathogen(sim), h)

        end
    end

    @testset "Effect of quarantine" begin
        rs = RandomSampling()

        ind1 = Individual(id=1, sex=1, age=42, household=1)
        ind2 = Individual(id=2, sex=1, age=42, household=1)
        h = Household(id=1, individuals=[ind1, ind2], contact_sampling_method = rs)
        gs = GlobalSetting(individuals = [ind1, ind2], contact_sampling_method = rs)
        stngs = SettingsContainer()
        add_types!(stngs, [Household, GlobalSetting])
        add!(stngs, h)
        add!(stngs, gs)
        exposedtick = Int16(0)
        p = Pathogen(id = 1, name = "COVID")

        Random.seed!(test_rng, 123)
        ind1.exposed_tick = exposedtick
        infectiousness!(ind1, 127)
        presymptomatic!(ind1)
        disease_progression!(ind1, p, exposedtick, GEMS.Mild, rng=test_rng)

        progress_disease!(ind1, quarantine_tick(ind1))
        @test isquarantined(ind1)
        sim = Simulation(
                "",
                InfectedFraction(0,p),
                TimesUp(420),
                Population([ind1, ind2]),
                stngs,
                "test"   
            )
        sim.tick = quarantine_tick(ind1)
        # no matter how often we try to spread the infection in the GlobalSetting
        # nothing should happen, because ind1 is not there
        tries = 100
        @test !infected(ind2)
        for i in range(1, tries)
            spread_infection!(gs, sim, p)
        end
        @test !infected(ind2)

        # now sent ind2 in quarantine and nothing should happen as there are no possible contacts
        reset!(ind1)
        reset!(ind2)
        # infect ind1 w/o quarantine
        Random.seed!(test_rng, 123)
        ind1.exposed_tick = exposedtick
        infectiousness!(ind1, 127)
        presymptomatic!(ind1)
        @test infectious(ind1)
        
        # send ind2 home
        ind2.quarantine_tick = 0
        ind2.quarantine_release_tick = 42
        ind2.quarantine_status = GEMS.QUARANTINE_STATE_HOUSEHOLD_QUARANTINE

        @test isquarantined(ind2)
        sim = Simulation(
                "",
                InfectedFraction(0,p),
                TimesUp(420),
                Population([ind1, ind2]),
                stngs,
                "test"   
            )
        sim.tick = quarantine_tick(ind2)
        # no matter how often we try to spread the infection in the GlobalSetting
        # nothing should happen, because ind2 is not there
        tries = 100
        @test !infected(ind2)
        for i in range(1, tries)
            spread_infection!(gs, sim, p)
        end
        @test !infected(ind2)

    end
end