@testset "Infections" begin
    
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
            Random.seed!(42)
            @test false == try_to_infect!(infctr, infctd, sim, pathogen(sim), h)
            
            # This seed works
            Random.seed!(1)
            @test true == try_to_infect!(infctr, infctd, sim, pathogen(sim), h)

            # unable to infect, when already infected
            Random.seed!(1)
            i = Individual(id = 1, sex = 0, age = 31, household = 1)
            infect!(i, Int16(0), p)
            @test false == try_to_infect!(infctr, infctd, sim, pathogen(sim), h)

            # unable to infect, when already dead
            i = Individual(id = 1, sex = 0, age = 31, household=1)
            i.dead = true
            @test false == try_to_infect!(infctr, infctd, sim, pathogen(sim), h)

            # Test the specific transmission functions
            @testset "Transmission Function" begin
                @testset "Base Transmission" begin
                    constTrans = Dict(
                        "type" => "ConstantTransmissionRate",
                        "parameters" => Dict(
                            "transmission_rate" => 0.533
                        )
                    )
                    sim |> pathogen |> x -> transmission_function!(x, constTrans |> create_transmission_function)
                    @test transmission_probability(sim |> pathogen |> transmission_function, infctr, infctd, h, Int16(1)) == 0.533
                end
                @testset "Age Dependent Transmission" begin
                    ageDepTrans = Dict(
                        "type" => "AgeDependentTransmissionRate",
                        "parameters" => Dict(
                            "ageGroups" => [[0,31], [32,36]],
                            "ageTransmissions" => [[0.0,0.0], [1,0.0]],
                            "distribution" => "Normal",
                            "transmission_rate" => [0.25, 0.0]
                        )
                    )
                    sim |> pathogen |> x -> transmission_function!(x, ageDepTrans |> create_transmission_function)
                    # Test if age category of the infected agent is correctly identified and transmission rate is used
                    @test transmission_probability(sim |> pathogen |> transmission_function, infctr, infctd, h, Int16(1)) == 1
                    @test transmission_probability(sim |> pathogen |> transmission_function, infctd, infctr, h, Int16(1)) == 0
                    i = Individual(id = 1, sex = 0, age = 37, household = 1)
                    @test transmission_probability(sim |> pathogen |> transmission_function, infctr, i, h, Int16(1)) == 0.25
                end
                @testset "Constant Transmission" begin
                    sexDepTrans = Dict(
                        "type" => "ConstantTransmissionRate",
                        "parameters" => Dict(
                            "transmission_rate" => 0.2
                        )
                    )
                    sim |> pathogen |> x -> transmission_function!(x, sexDepTrans |> create_transmission_function)

                    @test transmission_probability(sim |> pathogen |> transmission_function, infctr, infctd, h, Int16(1)) == 0.2
                    @test transmission_probability(sim |> pathogen |> transmission_function, infctd, infctr, h, Int16(1)) == 0.2
                end

            end
        end
    end

    #=
    THESE TESTS ARE CURRENTLY NOT WORKING CORRECTLY AS THEY WERE DESIGNED TO TEST THE INFECTION DYNAMIK ON A SPECIFIC SEED FOR A FIXED INFECTION DYNAMIK.

    UNTIL A NEW ROBUST TESTING SZENARIO FOR STOCHASTIC PROCESSES (AS "try_to_infect()" IS ONE) IS IMPLEMENTED, THESE TESTS WILL BE SUSPENDED.

    THIS IS NECESSARY AS THE CURRENT IMPLEMENTATION OF "spread_infection()" ALLOWS FOR DIFFERENT SAMPLING PROCEDURES THAT HAVE INFLUENCE ON THE RESULT OF "try_to_infect!()", SO THESE TESTS AREN'T ROBUST. 
    @testset "Setting-Level" begin
        #initial infectant
        i = Individual(id = 42, age = 21, sex = 0, household=1)
        #other individuals in the household
        indis = [Individual(id = j, age = 18, sex = 1, household=1) for j in range(0,10)]
        push!(indis, i)
        h = Household(id = 1, individuals = indis)

        gs = GlobalSetting(individuals = indis)

        stngs = SettingsContainer()
        add_types!(stngs, [Household, GlobalSetting])
        add!(stngs, h)
        add!(stngs, gs)

        p = Pathogen(id = 1, name = "Test", time_to_recovery=Uniform(8,12))
        time_tick = Int16(32)

        # dummy simulation for infections
        sim = Simulation(tick = time_tick, start_condition = InfectedFraction(0,p), stop_criterion = TimesUp(420), population = Population(individuals = indis), settings = stngs)

        Random.seed!(42)
        # infect one and set setting as active
        infect!(i, tick(sim), pathogen(sim))
        activate!(h)
        @test isactive(h)

        # read out update ticks and a "safe" tick
        inf_tick = infectious_tick(i)
        safe_tick = inf_tick - Int16(1)
        rec_tick = removed_tick(i)

        # first test before the infectious tick
        Random.seed!(42)     
        sim.tick = safe_tick
        p_logger = logger(pathogen(sim))
        @test length(p_logger.tick) == 1 # only the initial infection is registered

        # update all agents before spreading the infection
        for indiv in individuals(population(sim))    
            update_individual!(indiv, tick(sim), sim)
        end
        spread_infection!(h, sim, pathogen(sim))
        @test length(p_logger.tick) == 1 # still only the initial infection is registered
        @test length([i for i in individuals(h, sim) if infected(i)]) == 1
        @test infectiousness(i) == 0
        @test isactive(h) # Setting should still be active although noone is infectious

        # now test on the infectious tick and the update
        Random.seed!(42)
        sim.tick = inf_tick
        # update all agents before spreading the infection
        for indiv in individuals(population(sim))    
            update_individual!(indiv, tick(sim), sim)
        end
        spread_infection!(h, sim, pathogen(sim))
        @test infectiousness(i) > 0
        @test length([i for i in individuals(h, sim) if infected(i)]) > 1
        @test length(p_logger.tick) > 1
    
        new_infected_ids = p_logger.id_b[2:end]
        new_infected = [ind for ind in individuals(population(sim)) if id(ind) in new_infected_ids]

        # test the infection process          
        @test length(new_infected)!=0
        for ind in new_infected
            @test infected(ind)
            @test exposed_tick(ind) == inf_tick
            @test infectious_tick(ind) >= inf_tick
            @test removed_tick(ind) >= inf_tick
        end

        # now test for recovery update
        indis = [Individual(id = j, age = 18, sex = 1) for j in range(0,10)]
        push!(indis, i)
        # h = Household(id = 1, individuals = indis)
        # mark_infected!(h, i)

        h.individuals = indis

        Random.seed!(42)
        sim.tick = rec_tick

        l = length(p_logger.tick) # number of logs before spread_infection

        @test isactive(h) # setting should be active before spread of infection
        # update all agents before spreading the infection
        for indiv in individuals(population(sim))    
            update_individual!(indiv, tick(sim), sim)
        end
        spread_infection!(h, sim, pathogen(sim)) 
        # test the update step
        @test disease_state(i) == 0
        @test infectiousness(i) == 0
        # test the infection process          
        @test length(p_logger.tick) == l # no new infections so same number of logs!
        @test length([i for i in individuals(h, sim) if infected(i)]) == 0
        @test !isactive(h) # setting should be deactivated without infected individuals
    end
    =#
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

        Random.seed!(123)
        ind1.exposed_tick = exposedtick
        infectiousness!(ind1, 127)
        presymptomatic!(ind1)
        disease_progression!(ind1, p, exposedtick, GEMS.Mild)

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
        Random.seed!(123)
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