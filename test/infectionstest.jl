import GEMS: try_to_infect!, spread_infection!, update_individual!, get_containers!, dead!,
    push_infection!, push_immunity!, update_immunity!, _SlotRemoval

@testset "Infections" begin
    test_rng = Xoshiro()

    @testset "Agent-Level" begin

        @testset "Disease Progression" begin
            dp = DiseaseProgression(
                exposure = Int16(1),
                infectiousness_onset = Int16(2),
                symptom_onset = Int16(3),
                severeness_onset = Int16(4),
                critical_onset = Int16(5),
                critical_offset = Int16(8),
                severeness_offset = Int16(11),
                recovery = Int16(12),
            )

            pid = Int8(1)
            reg = InfectionRegistry()
            i = Individual(id = 1, sex = 0, age = 31)
            set_progression!(i, dp, pid)

            # check if everything was set correctly
            @test exposure(i, reg, pid) == 1
            @test infectiousness_onset(i, reg, pid) == 2
            @test symptom_onset(i, reg, pid) == 3
            @test severeness_onset(i, reg, pid) == 4
            @test critical_onset(i, reg, pid) == 5
            @test critical_offset(i, reg, pid) == 8
            @test severeness_offset(i, reg, pid) == 11
            @test recovery(i, reg, pid) == 12
            # death is host-level, not per-pathogen-registry
            @test i.death == GEMS.DEFAULT_TICK

            # check state functions
            # infected
            @test !infected(i, reg, pid, Int16(0)) # before
            @test infected(i, reg, pid, Int16(3)) # during
            @test !infected(i, reg, pid, Int16(13)) # after

            # infectious
            @test !infectious(i, reg, pid, Int16(1)) # before
            @test infectious(i, reg, pid, Int16(3)) # during
            @test !infectious(i, reg, pid, Int16(12)) # after

            # exposed
            @test !exposed(i, reg, pid, Int16(0)) # before
            @test exposed(i, reg, pid, Int16(1)) # during
            @test !exposed(i, reg, pid, Int16(2)) # after

            #presymptomatic
            @test !presymptomatic(i, reg, pid, Int16(0)) # before
            @test presymptomatic(i, reg, pid, Int16(2)) # during
            @test !presymptomatic(i, reg, pid, Int16(3)) # after

            # symptomatic
            @test !symptomatic(i, reg, pid, Int16(2)) # before
            @test symptomatic(i, reg, pid, Int16(4)) # during
            @test symptomatic(i, reg, pid, Int16(6)) # during
            @test symptomatic(i, reg, pid, Int16(8)) # during
            @test symptomatic(i, reg, pid, Int16(10)) # during
            @test !symptomatic(i, reg, pid, Int16(13)) # after

            # asymptomatic
            @test !asymptomatic(i, reg, pid, Int16(0)) # before
            @test !asymptomatic(i, reg, pid, Int16(4)) # during
            @test !asymptomatic(i, reg, pid, Int16(12)) # after

            # severe
            @test !severe(i, reg, pid, Int16(3)) # before
            @test severe(i, reg, pid, Int16(5)) # during
            @test !severe(i, reg, pid, Int16(12)) # after

            # mild
            @test !mild(i, reg, pid, Int16(2)) # before
            @test mild(i, reg, pid, Int16(3)) # during
            @test !mild(i, reg, pid, Int16(4)) # after
            @test mild(i, reg, pid, Int16(11)) # after severeness offset
            @test !mild(i, reg, pid, Int16(12)) # after recovery

            # critical
            @test !critical(i, reg, pid, Int16(4)) # before
            @test critical(i, reg, pid, Int16(6)) # during
            @test !critical(i, reg, pid, Int16(8)) # after

            # recovered
            @test !recovered(i, reg, pid, Int16(0)) # before infection
            @test !recovered(i, reg, pid, Int16(11)) # before
            @test recovered(i, reg, pid, Int16(12)) # at recovery
            @test recovered(i, reg, pid, Int16(13)) # after

            # dead (host-level flag, not tick-parameterized)
            @test !is_dead(i)
            @test i.death == GEMS.DEFAULT_TICK

            # death (host-level; set directly, not via DiseaseProgression)
            j = Individual(id = 2, sex = 0, age = 31)
            j.death = Int16(5)
            @test !is_dead(j) # flag not yet set by dead!
            dead!(j, true)
            @test is_dead(j)
            @test j.death == Int16(5)

            # asymptomatic progression
            dp_asymp = DiseaseProgression(
                exposure = Int16(1),
                infectiousness_onset = Int16(2),
                recovery = Int16(7),
            )
            k = Individual(id = 3, sex = 0, age = 31)
            set_progression!(k, dp_asymp, pid)
            @test !asymptomatic(k, reg, pid, Int16(0)) # before
            @test asymptomatic(k, reg, pid, Int16(3)) # during
            @test !asymptomatic(k, reg, pid, Int16(8)) # after

            @testset "progress_disease! Overflow" begin
                # With INFECTIONS_CACHE_SIZE = 1, a second simultaneous infection goes into the
                # registry linked list.  progress_disease! must process those overflow nodes too.
                p1 = Pathogen(id=1, name="P1")
                p2 = Pathogen(id=2, name="P2")
                pths = (p1, p2)

                # active path: both infections active in the overflow window
                reg_a = InfectionRegistry()
                i_a = Individual(id=10, sex=0, age=30)
                push_infection!(reg_a, i_a, Int8(1), Int32(1),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(20)))
                push_infection!(reg_a, i_a, Int8(2), Int32(2),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(20)))
                buf_a = _SlotRemoval[]
                progress_disease!(i_a, reg_a, pths, buf_a, Int16(5), test_rng)
                @test isinfected(i_a)
                @test isinfectious(i_a)

                # recovery path: overflow infection reaches its recovery tick
                reg_r = InfectionRegistry()
                i_r = Individual(id=11, sex=0, age=30)
                push_infection!(reg_r, i_r, Int8(1), Int32(3),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(5)))
                push_infection!(reg_r, i_r, Int8(2), Int32(4),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(5)))
                buf_r = _SlotRemoval[]
                progress_disease!(i_r, reg_r, pths, buf_r, Int16(10), test_rng)
                @test !isinfected(i_r)
                @test !isempty(buf_r) # overflow node staged for removal

                # death path: overflow infection triggers death (covers _process_death! overflow)
                # death is host-level now, so it's set directly rather than via DiseaseProgression
                reg_d = InfectionRegistry()
                i_d = Individual(id=12, sex=0, age=30)
                push_infection!(reg_d, i_d, Int8(1), Int32(5),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(30)))
                push_infection!(reg_d, i_d, Int8(2), Int32(6),
                    DiseaseProgression(exposure=Int16(1), infectiousness_onset=Int16(2), recovery=Int16(30)))
                i_d.death = Int16(5)
                i_d.killing_pathogen_id = Int8(2)
                buf_d = _SlotRemoval[]
                progress_disease!(i_d, reg_d, pths, buf_d, Int16(10), test_rng)
                @test isdead(i_d)
                @test !isempty(buf_d) # both cache and overflow nodes staged for removal
            end

            @testset "update_immunity! Overflow" begin
                # With IMMUNITY_CACHE_SIZE = 1, a second immunity state spills into the registry.
                p1 = Pathogen(id=1, name="P1")
                p2 = Pathogen(id=2, name="P2")
                pths = (p1, p2)

                ireg = ImmunityRegistry()
                i_imm = Individual(id=20, sex=0, age=30)
                push_immunity!(ireg, i_imm, Int8(1), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
                push_immunity!(ireg, i_imm, Int8(2), GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))

                # overflow node must be reachable; update_immunity! should not error
                i_imm.needs_immunity_update = true
                update_immunity!(i_imm, ireg, pths, Int16(10), test_rng)
                @test !i_imm.needs_immunity_update # FullImmunity is stable → flag cleared
            end
        end

        @testset "Basic Infection" begin
            # per-infection disease-progression scheduling only; host-level care/death
            # (hospital/icu/ventilation/death) is a HealthProgression concern, covered in
            # healthprogressiontest.jl
            reg = InfectionRegistry()

            # ASYMPTOMATIC PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Asymptomatic(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_recovery = Poisson(7)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            pid_p = id(p)

            @test -1 < exposure(i, reg, pid_p) <= infectiousness_onset(i, reg, pid_p) <= recovery(i, reg, pid_p)
            # everything else should be -1
            @test symptom_onset(i, reg, pid_p) == GEMS.DEFAULT_TICK
            @test severeness_onset(i, reg, pid_p) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet

            # SYMPTOMATIC PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Symptomatic(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_symptom_onset = Poisson(2),
                    symptom_onset_to_recovery = Poisson(7)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            pid_p = id(p)

            @test -1 < exposure(i, reg, pid_p) <= infectiousness_onset(i, reg, pid_p) <= symptom_onset(i, reg, pid_p) <= recovery(i, reg, pid_p)
            # everything else should be -1
            @test severeness_onset(i, reg, pid_p) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet

            # SEVERE PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Severe(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_symptom_onset = Poisson(1),
                    symptom_onset_to_severeness_onset = Poisson(1),
                    severeness_onset_to_severeness_offset = Poisson(7),
                    severeness_offset_to_recovery = Poisson(4)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            pid_p = id(p)
            @test -1 < exposure(i, reg, pid_p) <= infectiousness_onset(i, reg, pid_p) <= symptom_onset(i, reg, pid_p) <= severeness_onset(i, reg, pid_p) <= severeness_offset(i, reg, pid_p) <= recovery(i, reg, pid_p)
            # everything else should be -1
            @test critical_onset(i, reg, pid_p) == GEMS.DEFAULT_TICK
            @test critical_offset(i, reg, pid_p) == GEMS.DEFAULT_TICK
            @test infected(i) # should be infected
            @test !infectious(i) # but not infectious yet

            # CRITICAL PROGRESSION
            i = Individual(id = 1, sex = 0, age = 31)
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Critical(
                    exposure_to_infectiousness_onset = Poisson(3),
                    infectiousness_onset_to_symptom_onset = Poisson(1),
                    symptom_onset_to_severeness_onset = Poisson(1),
                    severeness_onset_to_critical_onset = Poisson(2),
                    critical_onset_to_critical_offset = Poisson(7),
                    critical_offset_to_severeness_offset = Poisson(3),
                    severeness_offset_to_recovery = Poisson(4)
            )])
            infect!(i, Int16(0), p, rng = Xoshiro())
            pid_p = id(p)
            @test -1 < exposure(i, reg, pid_p) <= infectiousness_onset(i, reg, pid_p) <= symptom_onset(i, reg, pid_p) <= severeness_onset(i, reg, pid_p) <= critical_onset(i, reg, pid_p) <= critical_offset(i, reg, pid_p) <= severeness_offset(i, reg, pid_p) <= recovery(i, reg, pid_p)
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
                    id = 1,
                    name = "TestPathogen",
                    progressions = [Asymptomatic(
                        exposure_to_infectiousness_onset = 0, # infectiousness_onset = tick+1+0 = 1
                        infectiousness_onset_to_recovery = 7)],
                    transmission_function = ConstantTransmissionRate(transmission_rate = 1.0) # definite infection
                )

                return Simulation(population = Population(pop), pathogens = (p,), infected_fraction = 0.0)
            end
            
            # TRY TO INFECT INFECTER-INFECTEE (should work)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)

            @test try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infectee already infected)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])
        
            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infectee dead)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            dead!(infectee, true)
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infectee hospitalized)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infectee.hospital_admission = Int16(0); infectee.hospital_discharge = Int16(100)
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infecter dead)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            dead!(infecter, true)
            step!(sim)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infecter hospitalized)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)
            infecter.hospital_admission = Int16(0); infecter.hospital_discharge = Int16(100)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - infecter not infected
            # prepare test sim (susceptible + susceptible in same household)
            sim = custom_test_sim()
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            @test_throws ArgumentError !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])

            # TRY TO INFECT INFECTER-INFECTEE (should NOT work - pathogen with zero transmission function)
            # prepare test sim (infected + susceptible in same household)
            sim = custom_test_sim()
            first_pathogen(sim).transmission_function = ConstantTransmissionRate(transmission_rate = 0.0)
            infecter = individuals(sim)[1]
            infectee = individuals(sim)[2]
            infect!(infecter, Int16(0), first_pathogen(sim), rng = Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)
            @test !try_to_infect!(infecter, infectee, sim, first_pathogen(sim), households(sim)[1])
        end

        @testset "Household Only Infections" begin
            sim_base = Simulation(pop_size = 1000,
                infected_fraction = 0.1,
                seed = 1234)

            run!(sim_base)
            rd_base = ResultData(sim_base)

            # in a base simulation, infections should occur also in non-household settings
            @test infections(rd_base).setting_type |> unique |> length > 1

            
            sim = Simulation(pop_size = 1000,
                seed = 1234,
                infected_fraction = 0.1,
                household_contacts = 3.0,
                office_contacts = 0.0,
                school_class_contacts = 0.0)
            run!(sim)
            rd = ResultData(sim)

            # only household infections should have occurred
            @test infections(rd) |>
                df -> df[df.setting_type .!= 'h' .&& df.tick .> 0, :] |> nrow == 0
        end

        @testset "No Severe Out-Household Infections" begin
            sim = Simulation(pop_size = 10_000)
            run!(sim)
            rd = ResultData(sim)

            # no severe infections should have occurred in non-household settings

            # get all infections that became severe at some point
            sev_ifns = infections(rd) |>
                df -> df[df.severeness_onset .>= 0, :]

            # get all infections that occurred outside the household
            out_hh_infs = infections(rd) |>
                df -> df[df.setting_type .!= 'h', :]

            # get infections that were caused by a person who had severe symptoms at some point in time
            @test innerjoin(
                select(sev_ifns, :infection_id, :severeness_onset, :severeness_offset),
                select(out_hh_infs, :source_infection_id, :tick),
                on = (:infection_id => :source_infection_id)
            ) |>
            # filter for infections that occured while the source infection was severe (should be none)
            df -> df[df.severeness_onset .<= df.tick .< df.severeness_offset, :] |>
            nrow == 0

        
        end
        @testset "No Hospital Infections" begin
            # all infections should immediately lead to hospitalization
            # no infections should occur in the population, as all infected are hospitalized
            p = Pathogen(
                name = "TestPathogen",
                progressions = [Severe(
                    exposure_to_infectiousness_onset = 0,
                    infectiousness_onset_to_symptom_onset = 0,
                    symptom_onset_to_severeness_onset = 0,
                    severeness_onset_to_severeness_offset = 7,
                    severeness_offset_to_recovery = 0,
                    hospital_probability = 1.0,
                    severeness_onset_to_hospital_admission = 0,
                    hospital_admission_to_hospital_discharge = 7
            )])

            sim = Simulation(pop_size = 1000, pathogen = p, infected_fraction = 0.1)
            run!(sim)
            rd = ResultData(sim)

            # no infections should have occurred in the population
            @test infections(rd) |>
                df -> df[df.tick .> 0, :] |> nrow == 0
        end

        @testset "Quarantine Effect on Infections" begin
            
            sim = Simulation(
                pop_size = 10_000,
                infected_fraction = 0.01,
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