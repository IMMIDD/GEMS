@testset "Disease Progression" begin
    @testset "Sampling Times" begin
        p = Pathogen(   
            id = 1,
            name = "COVID",
            infection_rate = Uniform(0,1),
            transmission_function = ConstantTransmissionRate(),
            mild_death_rate = Uniform(0,0.005),
            severe_death_rate= Uniform(0,0.1),
            critical_death_rate = Uniform(0,0.1),
            
            hospitalization_rate = Uniform(0, 0.1),
            ventilation_rate = Uniform(0, 0.1),
            icu_rate = Uniform(0, 0.1),
            
            onset_of_symptoms = Uniform(2,3),
            onset_of_severeness = Uniform(2,3),
            infectious_offset = Uniform(0,1),
            time_to_hospitalization = Uniform(1,4),
            time_to_icu = Uniform(1,2),

            time_to_recovery = Uniform(5,6),
            length_of_stay = Uniform(6,7)
        )
        ind = Individual(id = 1, age = 18, sex = 1)
        ind2 = Individual(id = 2, age = 55, sex = 1)
        house = Household(id = 1, individuals = [ind, ind2], contact_sampling_method = RandomSampling())

        # draw values
        @test 0 <= transmission_probability(p.transmission_function, ind, ind2, house, Int16(1)) <= 1
        @test 0 <= sample_mild_death_rate(p, ind) <= 0.005
        @test 0 <= sample_severe_death_rate(p, ind) <= 0.1
        @test 0 <= sample_critical_death_rate(p, ind) <= 0.1

        @test 0 <= sample_hospitalization_rate(p, ind) <= 0.1
        @test 0 <= sample_ventilation_rate(p, ind) <= 0.1
        @test 0 <= sample_icu_rate(p, ind) <= 0.1

        @test 0 <= sample_infectious_offset(p, ind) <= 1
        @test 5 <= sample_time_to_recovery(p, ind) <= 6
        @test 2 <= sample_onset_of_symptoms(p, ind) <= 3
        @test 2 <= sample_onset_of_severeness(p, ind) <= 3
        @test 1 <= sample_time_to_hospitalization(p, ind) <= 4
        @test 1 <= sample_time_to_icu(p, ind) <= 2
        @test 6 <= sample_length_of_stay(p, ind) <= 7
    end

    @testset "DiseaseProgressionStrat" begin
        # Test for wrong DiseaseProgressionStrat
        dict = Dict(
            "age_groups" => ["0-40", "40-80"],
            "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
            "stratification_matrix" => [[1, 0, 0, 0], [0.3, 0.3, 0.3, 0.1], [0.1, 0.2, 0.3, 0.4]]
        )
        # missing an age group
        @test_throws ErrorException("Provided age groups and the stratification matrix"*
            " don't match in dimensions as there are 2 age groups, but only 3 rows in"*
            " the stratification matrix."
            ) DiseaseProgressionStrat(dict)

        dict["age_groups"] = ["0-40", "40-80", "80+"]
        dict["disease_compartments"] = ["Asymptomatic", "Mild", "Severe"]
        dict["stratification_matrix"] = [[1, 0, 0], [0.3, 0.3, 0.3, 0.1], [0.1, 0.2, 0.7]]

        # second row has too many columns
        @test_throws ErrorException("Provided disease compartments and the stratification"*
            " matrix don't match in dimensions as there are 3 age groups, but only 4"
            *" columns in the stratification matrix in row 2."
            ) DiseaseProgressionStrat(dict)

        dict["disease_compartments"] = ["Asymptomatic", "Mild", "Severe", "Critical"]
        dict["stratification_matrix"] = [[1, 0, 0, 0], [0.3, 0.3, 0.3, 0.1], [0.1, 0.2, 0.3, 0.3]]

        # third row doesnt add up to 1
        @test_throws ErrorException(
            "Provided stratification matrix for disease progression is NOT stochastic! "*
            "Sum of entries in row 3 don't sum up to 1, but to "*
            string(sum([0.1, 0.2, 0.3, 0.3]))*"."
            ) DiseaseProgressionStrat(dict)

    end

    @testset "Estimate Final Status" begin
        i1 = Individual(id = 1, age = 70, sex = 1)
        dict = Dict(
            "age_groups" => ["0-40", "40-80", "80+"],
            "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
            "stratification_matrix" => [[1.0, 0.0, 0.0, 0.0], [0.3, 0.3, 0.3, 0.1], [0.1, 0.2, 0.3, 0.4]]
        )
        dpr = DiseaseProgressionStrat(dict)

        Random.seed!(42)
        @test GEMS.Severe == estimate_disease_progression(dpr, i1)
        @test GEMS.Mild == estimate_disease_progression(dpr, i1)
    end

    @testset "Progressions" begin
        ind = Individual(id = 1, age = 42, sex = 0)
        exposedtick = Int16(0)
        p = Pathogen(
            id = 1,
            name = "COVID",
            infection_rate = Uniform(0,1),
            mild_death_rate = Uniform(0.029,0.03),
            severe_death_rate= Uniform(0.19,0.2),
            critical_death_rate = Uniform(0,0.1),
            
            hospitalization_rate = Uniform(0, 0.1),
            ventilation_rate = Uniform(0, 0.1),
            icu_rate = Uniform(0, 0.1),
            
            onset_of_symptoms = Uniform(2,3),
            onset_of_severeness = Uniform(2,3),
            infectious_offset = Uniform(0,1),
            time_to_hospitalization = Uniform(1,4),
            time_to_icu = Uniform(1,2),

            time_to_recovery = Uniform(5,6),
            length_of_stay = Uniform(7,8)
        )

        @testset "Asymptomatic" begin
            reset!(ind)
            disease_progression!(ind, p, exposedtick, GEMS.Asymptomatic)
            @test symptom_category(ind) == GEMS.SYMPTOM_CATEGORY_ASYMPTOMATIC
            # test unset times
            @test onset_of_symptoms(ind) == GEMS.DEFAULT_TICK
            @test onset_of_severeness(ind) == GEMS.DEFAULT_TICK
            @test hospitalized_tick(ind) == GEMS.DEFAULT_TICK
            @test ventilation_tick(ind) == GEMS.DEFAULT_TICK
            @test icu_tick(ind) == GEMS.DEFAULT_TICK
            @test death_tick(ind) == GEMS.DEFAULT_TICK
            # test set Times
            @test infectious_tick(ind) >= 0
            @test removed_tick(ind) >= infectious_tick(ind)
        end
        @testset "Mild" begin
            reset!(ind)
            Random.seed!(0127)
            disease_progression!(ind, p, exposedtick, GEMS.Mild)
            @test symptom_category(ind) == GEMS.SYMPTOM_CATEGORY_MILD
            # test unset times
            @test onset_of_severeness(ind) == GEMS.DEFAULT_TICK
            @test hospitalized_tick(ind) == GEMS.DEFAULT_TICK
            @test ventilation_tick(ind) == GEMS.DEFAULT_TICK
            @test icu_tick(ind) == GEMS.DEFAULT_TICK
            # test set Times
            @test infectious_tick(ind) >= 0
            @test onset_of_symptoms(ind) >= infectious_tick(ind)
            @test removed_tick(ind) > onset_of_symptoms(ind)
            @test death_tick(ind) == removed_tick(ind) # dies on this seed with this mild death reate
            # and now a seed where he doesnt die
            reset!(ind)
            Random.seed!(42)
            disease_progression!(ind, p, exposedtick, GEMS.Mild)
            @test death_tick(ind) == GEMS.DEFAULT_TICK
        end
        @testset "Severe" begin
            reset!(ind)
            Random.seed!(6)
            disease_progression!(ind, p, exposedtick, GEMS.Severe)
            @test symptom_category(ind) == GEMS.SYMPTOM_CATEGORY_SEVERE
            # test unset times
            @test ventilation_tick(ind) == GEMS.DEFAULT_TICK
            @test icu_tick(ind) == GEMS.DEFAULT_TICK
            # test set Times
            @test infectious_tick(ind) >= 0
            @test onset_of_symptoms(ind) >= infectious_tick(ind)
            @test onset_of_severeness(ind) > onset_of_symptoms(ind)
            @test removed_tick(ind) > onset_of_severeness(ind)
            
            # TODO test death and hospitalization + length of stay
            # death without hospitalization on this seed
            @test death_tick(ind) == removed_tick(ind)
            @test hospitalized_tick(ind) == GEMS.DEFAULT_TICK

            # no death
            reset!(ind)
            Random.seed!(1234)
            disease_progression!(ind, p, exposedtick, GEMS.Severe)
            @test death_tick(ind) == GEMS.DEFAULT_TICK
            @test hospitalized_tick(ind) == GEMS.DEFAULT_TICK

            # hopsitalized and no death
            p.hospitalization_rate = Uniform(0.98, 0.99)
            reset!(ind)
            Random.seed!(1234)
            disease_progression!(ind, p, exposedtick, GEMS.Severe)
            @test death_tick(ind) == GEMS.DEFAULT_TICK
            @test hospitalized_tick(ind) >= onset_of_severeness(ind)
            @test hospitalized_tick(ind) + minimum(length_of_stay(p)) <= removed_tick(ind) <= hospitalized_tick(ind) + maximum(length_of_stay(p))
            # @test quarantine_tick(ind) == hospitalized_tick(ind)
            # @test quarantine_release_tick(ind) == removed_tick(ind)

            # hospitalized and death
            reset!(ind)
            Random.seed!(42)
            disease_progression!(ind, p, exposedtick, GEMS.Severe)
            @test hospitalized_tick(ind) >= onset_of_severeness(ind)
            @test hospitalized_tick(ind) + minimum(length_of_stay(p)) <= removed_tick(ind) <= hospitalized_tick(ind) + maximum(length_of_stay(p))
            #@test quarantine_tick(ind) == hospitalized_tick(ind)
            #@test quarantine_release_tick(ind) == removed_tick(ind)
            @test death_tick(ind) == removed_tick(ind)
        end
       
        @testset "Critical" begin
            reset!(ind)
            Random.seed!(42)
            disease_progression!(ind, p, exposedtick, GEMS.Critical)
            @test symptom_category(ind) == GEMS.SYMPTOM_CATEGORY_CRITICAL
            # no death, no ventilation, no icu
            @test infectious_tick(ind) >= 0
            @test onset_of_symptoms(ind) >= infectious_tick(ind)
            @test onset_of_severeness(ind) > onset_of_symptoms(ind)
            @test hospitalized_tick(ind) >= onset_of_severeness(ind)
            @test removed_tick(ind) > onset_of_severeness(ind)
            @test hospitalized_tick(ind) + minimum(length_of_stay(p)) <= removed_tick(ind) <= hospitalized_tick(ind) + maximum(length_of_stay(p))
            # @test quarantine_tick(ind) == hospitalized_tick(ind)
            # @test quarantine_release_tick(ind) == removed_tick(ind)
            @test death_tick(ind) == GEMS.DEFAULT_TICK
            @test ventilation_tick(ind) == GEMS.DEFAULT_TICK
            @test icu_tick(ind) == GEMS.DEFAULT_TICK

            # death, but nothing else
            reset!(ind)
            Random.seed!(6)
            disease_progression!(ind, p, exposedtick, GEMS.Critical)
            @test death_tick(ind) == removed_tick(ind) 

            # ventilation no death
            p.ventilation_rate = Uniform(0.98,0.99)
            reset!(ind)
            Random.seed!(42)
            disease_progression!(ind, p, exposedtick, GEMS.Critical)
            @test ventilation_tick(ind) == hospitalized_tick(ind)
            @test death_tick(ind) == GEMS.DEFAULT_TICK
            @test icu_tick(ind) == GEMS.DEFAULT_TICK

            # ventilation and death
            reset!(ind)
            Random.seed!(312)
            disease_progression!(ind, p, exposedtick, GEMS.Critical)
            @test ventilation_tick(ind) == hospitalized_tick(ind)
            @test death_tick(ind) == removed_tick(ind) 
            @test icu_tick(ind) == GEMS.DEFAULT_TICK

            # ICU no death
            p.icu_rate = Uniform(0.98, 0.99)
            reset!(ind)
            Random.seed!(42)
            disease_progression!(ind, p, exposedtick, GEMS.Critical)
            @test ventilation_tick(ind) == hospitalized_tick(ind)
            @test death_tick(ind) == GEMS.DEFAULT_TICK
            @test removed_tick(ind) >= icu_tick(ind) >= ventilation_tick(ind)

            # ICU and death
            p.critical_death_rate = Uniform(0.98,0.99)
            reset!(ind)
            Random.seed!(42)
            disease_progression!(ind, p, exposedtick, GEMS.Critical)
            @test ventilation_tick(ind) == hospitalized_tick(ind)
            @test death_tick(ind) == removed_tick(ind)
            @test removed_tick(ind) >= icu_tick(ind) >= ventilation_tick(ind)
        end
    end
    @testset "Agent-Level Updates" begin
        p = Pathogen(id = 1, name = "Test")
        exposedtick = Int16(0)
        indiv = Individual(id=1, sex=1, age=40)
        
        @testset "Asymptomatic" begin
            reset!(indiv)
            # infect individual
            indiv.exposed_tick = exposedtick
            indiv.disease_state = GEMS.DISEASE_STATE_PRESYMPTOMATIC
            indiv.number_of_infections += 1
            indiv.pathogen_id = id(p)

            Random.seed!(1234)
            disease_progression!(indiv, p, exposedtick, GEMS.Asymptomatic)

            for tick in range(exposedtick, removed_tick(indiv)-Int16(1))
                progress_disease!(indiv, tick)
                if tick < infectious_tick(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
                    @test exposed(indiv)
                    @test !infectious(indiv)
                end
                if infectious_tick(indiv) <= tick < removed_tick(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
                    @test !exposed(indiv)
                    @test infectious(indiv)
                end
            end
        end

        @testset "Mild" begin
            reset!(indiv)
            # infect individual
            indiv.exposed_tick = exposedtick
            indiv.disease_state = GEMS.DISEASE_STATE_PRESYMPTOMATIC
            indiv.number_of_infections += 1
            indiv.pathogen_id = id(p)

            Random.seed!(1234)
            disease_progression!(indiv, p, exposedtick, GEMS.Mild)

            for tick in range(exposedtick, removed_tick(indiv)-Int16(1))
                progress_disease!(indiv, tick)
                if tick < infectious_tick(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
                    @test exposed(indiv)
                    @test !infectious(indiv)
                end
                if infectious_tick(indiv) <= tick < onset_of_symptoms(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
                    @test !exposed(indiv)
                    @test infectious(indiv)
                end
                if onset_of_symptoms(indiv) <= tick < removed_tick(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_SYMPTOMATIC
                    @test infectious(indiv)
                end
            end
        end

        @testset "Severe" begin
            reset!(indiv)
            # infect individual
            indiv.exposed_tick = exposedtick
            indiv.disease_state = GEMS.DISEASE_STATE_PRESYMPTOMATIC
            indiv.number_of_infections += 1
            indiv.pathogen_id = id(p)

            # should hospitalize
            p.hospitalization_rate = Uniform(0.98, 0.99)
            Random.seed!(42)
            disease_progression!(indiv, p, exposedtick, GEMS.Severe)

            for tick in range(exposedtick, removed_tick(indiv)-Int16(1))
                progress_disease!(indiv, tick)
                if tick < infectious_tick(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
                    @test exposed(indiv)
                    @test !infectious(indiv)
                end
                if infectious_tick(indiv) <= tick < onset_of_symptoms(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
                    @test !exposed(indiv)
                    @test infectious(indiv)
                end
                if onset_of_symptoms(indiv) <= tick < onset_of_severeness(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_SYMPTOMATIC
                    @test infectious(indiv)
                end
                if onset_of_severeness(indiv) <= tick
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_SEVERE
                    @test infectious(indiv)
                end
                if hospitalized_tick(indiv) <= tick
                    @test hospitalized(indiv)
                end
            end
        end

        @testset "Critical" begin
            reset!(indiv)
            # infect individual
            indiv.exposed_tick = exposedtick
            indiv.disease_state = GEMS.DISEASE_STATE_PRESYMPTOMATIC
            indiv.number_of_infections += 1
            indiv.pathogen_id = id(p)

            # should do ICU and Ventilation
            p.icu_rate = Uniform(0.98, 0.99)
            p.ventilation_rate = Uniform(0.98,0.99)

            Random.seed!(42)
            disease_progression!(indiv, p, exposedtick, GEMS.Critical)
            for tick in range(exposedtick, removed_tick(indiv)-Int16(1))
                progress_disease!(indiv, tick)
                if tick < infectious_tick(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
                    @test exposed(indiv)
                    @test !infectious(indiv)
                end
                if infectious_tick(indiv) <= tick < onset_of_symptoms(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
                    @test !exposed(indiv)
                    @test infectious(indiv)
                end
                if onset_of_symptoms(indiv) <= tick < onset_of_severeness(indiv)
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_SYMPTOMATIC
                    @test infectious(indiv)
                end
                if onset_of_severeness(indiv) <= tick
                    @test disease_state(indiv) == GEMS.DISEASE_STATE_SEVERE
                    @test infectious(indiv)
                end
                if hospitalized_tick(indiv) <= tick
                    @test hospitalized(indiv)
                end
                if ventilation_tick(indiv) <= tick < icu_tick(indiv)
                    @test ventilated(indiv)
                end
                if icu_tick(indiv) <= tick
                    @test icu(indiv)
                end
            end
        end

        @testset "Update during step!" begin
            reset!(indiv)
            inf_frac = InfectedFraction(0.05, p)
            times_up = TimesUp(120)
            sim = Simulation(
                "",
                inf_frac,
                times_up,
                Population([indiv]),
                SettingsContainer(),
                "test"   
            )
            sim.pathogen = p    

            # test if individual updates 
            indiv.disease_state = GEMS.DISEASE_STATE_PRESYMPTOMATIC
            indiv.exposed_tick = 1
            indiv.infectious_tick = 5
            indiv.onset_of_symptoms = 7
            indiv.removed_tick = 20
            indiv.death_tick = 20
            indiv.symptom_category = GEMS.SYMPTOM_CATEGORY_MILD # mild disease (but it still will die)

            # go to infectious
            sim.tick = Int16(5)
            update_individual!(indiv, tick(sim), sim)
            @test infectiousness(indiv) > 0
            @test presymptomatic(indiv)
            @test length(deathlogger(sim).id) == 0
            @test !dead(indiv)

            sim.tick = Int16(7)
            update_individual!(indiv, tick(sim), sim)
            @test infectiousness(indiv) > 0
            @test symptomatic(indiv)
            @test length(deathlogger(sim).id) == 0
            @test !dead(indiv)

            sim.tick = Int16(20)
            update_individual!(indiv, tick(sim), sim)
            @test infectiousness(indiv) == 0
            @test indiv.disease_state == 0
            @test !infected(indiv)
            @test length(deathlogger(sim).id) == 1
            @test dead(indiv)

            # now test if nothing happens, when the individuals is not infected
            reset!(indiv)
            sim = Simulation(
                "",
                inf_frac,
                times_up,
                Population([indiv]),
                SettingsContainer(),
                "test"   
            )
            sim.pathogen = p  

            # dont set disease state! The disease state determines, if we count indiv as infected
            indiv.exposed_tick = 1
            indiv.infectious_tick = 5
            indiv.onset_of_symptoms = 7
            indiv.removed_tick = 20
            indiv.death_tick = 20
            indiv.symptom_category = GEMS.SYMPTOM_CATEGORY_MILD # mild disease (but it still will die)
            @test !infected(indiv)
            @test length(deathlogger(sim).id) == 0
            sim.tick = Int16(20)
            update_individual!(indiv, tick(sim), sim)
            @test !dead(indiv)
            @test length(deathlogger(sim).id) == 0
        end
    end

    # @testset "Self-Quarantine" begin
    #     ind = Individual(id = 1, age = 42, sex = 0)
    #     exposedtick = Int16(0)
    #     p = Pathogen(id = 1, name = "COVID", self_quarantine_rate=Uniform(0.99,0.999))

    #     Random.seed!(123)
    #     ind.exposed_tick = exposedtick
    #     presymptomatic!(ind)
    #     disease_progression!(ind, p, exposedtick, GEMS.Mild)
    #     @test quarantine_tick(ind) == onset_of_symptoms(ind) != GEMS.DEFAULT_TICK
    #     @test quarantine_release_tick(ind) == removed_tick(ind) != GEMS.DEFAULT_TICK
    #     @test quarantine_status(ind) == GEMS.QUARANTINE_STATE_NO_QUARANTINE

        
    #     progress_disease!(ind, quarantine_tick(ind)+Int16(1))
    #     @test quarantine_status(ind) == GEMS.QUARANTINE_STATE_HOUSEHOLD_QUARANTINE
    # end
end