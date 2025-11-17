@testset "Infections" begin
    test_rng = Xoshiro()

    @testset "Agent-Level" begin

        @testset "Disease Progression" begin
            dp = DiseaseProgression(
                exposure = Int16(1),
                infectiousness_onset = Int16(2),
                symptom_onset = Int16(3),
                severeness_onset = Int16(4),
                hospital_admission = Int16(5),
                icu_admission = Int16(6),
                icu_discharge = Int16(7),
                ventilation_admission = Int16(8),
                ventilation_discharge = Int16(9),
                hospital_discharge = Int16(10),
                severeness_offset = Int16(11),
                recovery = Int16(12),
            )

            i = Individual(id = 1, sex = 0, age = 31)
            GEMS.set_progression!(i, dp)

            # check if everything was set correctly
            @test exposure(i) == 1
            @test infectiousness_onset(i) == 2
            @test symptom_onset(i) == 3
            @test severeness_onset(i) == 4
            @test hospital_admission(i) == 5
            @test icu_admission(i) == 6
            @test icu_discharge(i) == 7
            @test ventilation_admission(i) == 8
            @test ventilation_discharge(i) == 9
            @test hospital_discharge(i) == 10
            @test severeness_offset(i) == 11
            @test recovery(i) == 12
            @test death(i) == GEMS.DEFAULT_TICK

            # check state functions
            # infected
            @test !infected(i, Int16(0)) # before
            @test infected(i, Int16(3)) # during
            @test !infected(i, Int16(13)) # after

            # infectious
            @test !infectious(i, Int16(1)) # before
            @test infectious(i, Int16(3)) # during
            @test !infectious(i, Int16(12)) # after

            # exposed
            @test !exposed(i, Int16(0)) # before
            @test exposed(i, Int16(1)) # during
            @test !exposed(i, Int16(2)) # after

            #presymptomatic
            @test !presymptomatic(i, Int16(0)) # before
            @test presymptomatic(i, Int16(2)) # during
            @test !presymptomatic(i, Int16(3)) # after

            # symptomatic
            @test !symptomatic(i, Int16(2)) # before
            @test symptomatic(i, Int16(4)) # during
            @test symptomatic(i, Int16(6)) # during
            @test symptomatic(i, Int16(8)) # during
            @test symptomatic(i, Int16(10)) # during
            @test !symptomatic(i, Int16(13)) # after

            # asymptomatic
            @test !asymptomatic(i, Int16(0)) # before
            @test !asymptomatic(i, Int16(4)) # during
            @test !asymptomatic(i, Int16(12)) # after

            # severe
            @test !severe(i, Int16(3)) # before
            @test severe(i, Int16(5)) # during
            @test !severe(i, Int16(12)) # after

            # mild
            @test !mild(i, Int16(2)) # before
            @test mild(i, Int16(3)) # during
            @test !mild(i, Int16(4)) # after
            @test mild(i, Int16(11)) # after severeness offset
            @test !mild(i, Int16(12)) # after recovery

            # hospitalized
            @test !hospitalized(i, Int16(4)) # before
            @test hospitalized(i, Int16(6)) # during
            @test !hospitalized(i, Int16(11)) # after

            # ICU
            @test !icu(i, Int16(5)) # before
            @test icu(i, Int16(6)) # during
            @test !icu(i, Int16(10)) # after    

            # ventilated
            @test !ventilated(i, Int16(7)) # before
            @test ventilated(i, Int16(8)) # during
            @test !ventilated(i, Int16(10)) # after

            # recovered
            @test !recovered(i, Int16(0)) # before infection
            @test !recovered(i, Int16(11)) # before
            @test recovered(i, Int16(12)) # at recovery
            @test recovered(i, Int16(13)) # after

            # dead
            @test !dead(i, Int16(0)) # before infection
            @test !dead(i, Int16(12)) # before death

            # death progression
            dp_death = DiseaseProgression(
                exposure = Int16(1),
                infectiousness_onset = Int16(2),
                symptom_onset = Int16(3),
                death = Int16(5),
            )
            j = Individual(id = 2, sex = 0, age = 31)
            GEMS.set_progression!(j, dp_death)
            @test !dead(j, Int16(4)) # before death
            @test dead(j, Int16(5)) # at death
            @test dead(j, Int16(6)) # after death

            # asymptomatic progression
            dp_asymp = DiseaseProgression(
                exposure = Int16(1),
                infectiousness_onset = Int16(2),
                recovery = Int16(7),
            )
            k = Individual(id = 3, sex = 0, age = 31)
            GEMS.set_progression!(k, dp_asymp)
            @test !asymptomatic(k, Int16(0)) # before
            @test asymptomatic(k, Int16(3)) # during
            @test !asymptomatic(k, Int16(8)) # after
        end
        
        @testset "Basic Infection" begin
            
            # ASYMPTOMATIC PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Asymptomatic(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_recovery = Poisson(7)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())

            @test -1 < exposure(i) <= infectiousness(i) <= recovery(i)
            # everything else should be -1
            @test symptom_onset(i) == GEMS.DEFAULT_TICK
            @test severeness_onset(i) == GEMS.DEFAULT_TICK
            @test hospital_admission(i) == GEMS.DEFAULT_TICK
            @test icu_admission(i) == GEMS.DEFAULT_TICK
            @test icu_discharge(i) == GEMS.DEFAULT_TICK
            @test ventilation_admission(i) == GEMS.DEFAULT_TICK
            @test ventilation_discharge(i) == GEMS.DEFAULT_TICK
            @test hospital_discharge(i) == GEMS.DEFAULT_TICK
            @test severeness_offset(i) == GEMS.DEFAULT_TICK
            @test death(i) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet
            
            # SYPMTOMATIC PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Symptomatic(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_symptom_onset = Poisson(2),
                    symptom_onset_to_recovery = Poisson(7)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())

            @test -1 < exposure(i) <= infectiousness(i) <= symptom_onset(i) <= recovery(i)
            # everything else should be -1
            @test severeness_onset(i) == GEMS.DEFAULT_TICK
            @test hospital_admission(i) == GEMS.DEFAULT_TICK
            @test icu_admission(i) == GEMS.DEFAULT_TICK
            @test icu_discharge(i) == GEMS.DEFAULT_TICK
            @test ventilation_admission(i) == GEMS.DEFAULT_TICK
            @test ventilation_discharge(i) == GEMS.DEFAULT_TICK
            @test hospital_discharge(i) == GEMS.DEFAULT_TICK
            @test severeness_offset(i) == GEMS.DEFAULT_TICK
            @test death(i) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet


            # HOSPITALIZED PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Hospitalized(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_symptom_onset = Poisson(1),
                    symptom_onset_to_severeness_onset = Poisson(1),
                    severeness_onset_to_hospital_admission = Poisson(2),
                    hospital_admission_to_hospital_discharge = Poisson(7),
                    hospital_discharge_to_severeness_offset = Poisson(3),
                    severeness_offset_to_recovery = Poisson(4)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            @test -1 < exposure(i) <= infectiousness(i) <= symptom_onset(i) <= severeness_onset(i) <= hospital_admission(i) <= hospital_discharge(i) <= severeness_offset(i) <= recovery(i)

            # everyhting else should be -1
            @test icu_admission(i) == GEMS.DEFAULT_TICK
            @test icu_discharge(i) == GEMS.DEFAULT_TICK
            @test ventilation_admission(i) == GEMS.DEFAULT_TICK
            @test ventilation_discharge(i) == GEMS.DEFAULT_TICK
            @test death(i) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet

            # CRITICAL PROGRESSION
            # no death
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Critical(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_symptom_onset = Poisson(1),
                    symptom_onset_to_severeness_onset = Poisson(1),
                    severeness_onset_to_hospital_admission = Poisson(2),
                    hospital_admission_to_icu_admission = Poisson(2),
                    icu_admission_to_icu_discharge = Poisson(7),
                    icu_discharge_to_hospital_discharge = Poisson(7),
                    hospital_discharge_to_severeness_offset = Poisson(3),
                    severeness_offset_to_recovery = Poisson(4),
                    icu_admission_to_death = Poisson(10),
                    death_probability = 0.0
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            @test -1 < exposure(i) <= infectiousness(i) <= symptom_onset(i) <= severeness_onset(i) <= hospital_admission(i) <= icu_admission(i) <= icu_discharge(i) <= hospital_discharge(i) <= severeness_offset(i) <= recovery(i)
            # everyhting else should be -1
            @test ventilation_admission(i) == GEMS.DEFAULT_TICK
            @test ventilation_discharge(i) == GEMS.DEFAULT_TICK
            # death should be -1
            @test death(i) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet

            # CRITICAL PROGRESSION
            # with death
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Critical(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_symptom_onset = Poisson(1),
                    symptom_onset_to_severeness_onset = Poisson(1),
                    severeness_onset_to_hospital_admission = Poisson(2),
                    hospital_admission_to_icu_admission = Poisson(2),
                    icu_admission_to_icu_discharge = Poisson(7),
                    icu_discharge_to_hospital_discharge = Poisson(7),
                    hospital_discharge_to_severeness_offset = Poisson(3),
                    severeness_offset_to_recovery = Poisson(4),
                    icu_admission_to_death = Poisson(10),
                    death_probability = 1.0
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            @test -1 < exposure(i) <= infectiousness(i) <= symptom_onset(i) <= severeness_onset(i) <= hospital_admission(i) <= icu_admission(i) <= icu_discharge(i) <= hospital_discharge(i) <= severeness_offset(i) <= death(i)

            # everyhting else should be -1
            @test ventilation_admission(i) == GEMS.DEFAULT_TICK
            @test ventilation_discharge(i) == GEMS.DEFAULT_TICK
            @test recovery(i) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet
        end

    end
    @testset "Infection Dynamics" begin

        @testset "Try to Infect" begin
            # helper function to spawn a custom test simulation
            function custom_test_sim()
                # create test population with two individuals in the same household
                pop = DataFrame(
                    id = [1,2],
                    sex = [0,0],
                    age = [31,32],
                    household = [1,1]
                )

                # create a pathogen with an asymptomatic progression
                # that has concrete time steps and a definite infection probability
                p = Pathogen(
                    name = "TestPathogen",
                    progressions = [Asymptomatic(
                        exposure_to_infectiousness_onset = 1, # discrete time points
                        infectiousness_onset_to_recovery = 7)],
                    transmission_function = ConstantTransmissionRate(transmission_rate = 1.0) # definite infection
                )

                return Simulation(population = Population(pop), pathogen = p, infected_fraction = 0.0)
            end
            
            # TRY TO INFECT INFECTER-INFECTEE (should work)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), pathogen(sim), rng = Xoshiro())
            step!(sim)

            @test try_to_infect!(infecter, infectee, sim, pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infectee already infected)
            @test !try_to_infect!(infecter, infectee, sim, pathogen(sim), households(sim)[1])
        
            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infectee dead)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            dead!(infectee, true)
            infect!(infecter, Int16(0), pathogen(sim), rng = Xoshiro())
            step!(sim)
            @test !try_to_infect!(infecter, infectee, sim, pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infectee hospitalized)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            hospitalized!(infectee, true)
            infect!(infecter, Int16(0), pathogen(sim), rng = Xoshiro())
            step!(sim)
            @test !try_to_infect!(infecter, infectee, sim, pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infecter dead)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), pathogen(sim), rng = Xoshiro())
            dead!(infecter, true)
            step!(sim)
            @test !try_to_infect!(infecter, infectee, sim, pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infecter hospitalized)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), pathogen(sim), rng = Xoshiro())
            step!(sim)
            hospitalized!(infecter, true)
            @test !try_to_infect!(infecter, infectee, sim, pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infecter not infected
            # prepare test sim (susceptible + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            @test_throws ArgumentError !try_to_infect!(infecter, infectee, sim, pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - pathogen with zero transmission function)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            pathogen(sim).transmission_function = ConstantTransmissionRate(transmission_rate = 0.0)
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), pathogen(sim), rng = Xoshiro())
            step!(sim)
            @test !try_to_infect!(infecter, infectee, sim, pathogen(sim), households(sim)[1])
        end

        @testset "Household Only Infections" begin
            sim_base = Simulation(pop_size = 1000,
                seed = 1234)

            run!(sim_base)
            rd_base = ResultData(sim_base)

            # in a base simulation, infections should occur also in non-household settings
            @test infections(rd_base).setting_type |> unique |> length > 1

            
            sim = Simulation(pop_size = 1000,
                seed = 1234,
                household_contacts = 3.0,
                office_contacts = 0.0,
                school_class_contacts = 0.0)
            run!(sim)
            rd = ResultData(sim)

            # only household infections should have occurred
            @test infections(rd) |>
                df -> df[df.setting_type .!= 'h' .&& df.tick .> 0, :] |> nrow == 0
        end
        @testset "No Hospital Infections" begin
            # all infections should immediately lead to hospitalization
            # no infections should occur in the population, as all infected are hospitalized
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Hospitalized(
                    exposure_to_infectiousness_onset = 1,
                    infectiousness_onset_to_symptom_onset = 0,
                    symptom_onset_to_severeness_onset = 0,
                    severeness_onset_to_hospital_admission = 0,
                    hospital_admission_to_hospital_discharge = 7,
                    hospital_discharge_to_severeness_offset = 0,
                    severeness_offset_to_recovery = 0
            )])

            sim = Simulation(pop_size = 1000, pathogen = p)
            run!(sim)
            rd = ResultData(sim)

            # no infections should have occurred in the population
            @test infections(rd) |>
                df -> df[df.tick .> 0, :] |> nrow == 0
        end

        @testset "Quarantine Effect on Infections" begin
            
            sim = Simulation(
                pop_size = 10_000,
                transmission_rate = 1.0)

            # put all infected in quarantine
            for i in individuals(sim)
                if infected(i)
                    i.quarantine_tick = sim.tick
                    i.quarantine_release_tick = sim.tick + 1000
                    i.quarantine_status = GEMS.QUARANTINE_STATE_HOUSEHOLD_QUARANTINE
                end
            end

            run!(sim)
            rd = ResultData(sim)

            # the initial infected should only infect household members
            @test infections(rd) |>
                df -> df[df.source_infection_id .<= 0, :] |>
                df -> select(df, :infection_id)  |>
                df -> innerjoin(df, select(infections(rd), :source_infection_id, :setting_type), on = (:infection_id => :source_infection_id)) |>
                df -> df[(df.setting_type .!= 'h'), :] |> nrow == 0

        end
    end
end