@testset "Disease Progression" begin

    @testset "Internal Logic" begin
        # THINGS THAT SHOULD WORK
        
        # asymptomatic progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            recovery = 31
        )

        # mild symptomatic progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            recovery = 34
        )

        # severe symptomatic progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            severeness_offset = 40,
            recovery = 45
        )

        # hospitalized progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            hospital_discharge = 50,
            severeness_offset = 51,
            recovery = 55
        )

        # icu'd progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            icu_discharge = 60,
            hospital_discharge = 65,
            severeness_offset = 66,
            recovery = 70
        )

        # ventilated progression
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            ventilation_admission = 45,
            ventilation_discharge = 70,
            icu_discharge = 75,
            hospital_discharge = 80,
            severeness_offset = 81,
            recovery = 85
        )

        # death
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            death = 70,
            severeness_offset = 70
        )

        # death in ICU
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            death = 70,
            severeness_offset = 70,
            icu_discharge = 70,
            hospital_discharge = 70
        )

        # ventilation throughout ICU
        DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            ventilation_admission = 40,
            icu_admission = 45,
            icu_discharge = 60,
            ventilation_discharge = 65,
            hospital_discharge = 70,
            severeness_offset = 71,
            recovery = 75
        )

        # THINGS THAT SHOULD NOT WORK
        @test_throws ArgumentError DiseaseProgression()

        # no exposure
        @test_throws ArgumentError DiseaseProgression(
            infectiousness_onset = 25,
            recovery = 31
        )
        # no recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25
        )

        # no infectiousness onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            recovery = 31
        )

        # recovery before infectiousness onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            recovery = 24
        )

        # severeness onset before symptom onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 24,
            severeness_offset = 32,
            recovery = 34
        )

        # severeness offset before severeness onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            severeness_offset = 29,
            recovery = 34
        )

        # hospital admission before severeness onset
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 29,
            hospital_discharge = 50,
            severeness_offset = 51,
            recovery = 55
        )

        # hospital discharge before hospital admission
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            hospital_discharge = 34,
            severeness_offset = 51,
            recovery = 55
        )

        # icu admission before hospital admission
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 34,
            icu_discharge = 60,
            hospital_discharge = 65,
            severeness_offset = 66,
            recovery = 70
        )

        # icu discharge before icu admission
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            icu_discharge = 39,
            hospital_discharge = 65,
            severeness_offset = 66,
            recovery = 70
        )

        # death without symptoms
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            death = 29,
        )

        # symptom onset after death or recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 27,
            death = 26,
        )
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 27,
            recovery = 26,
        )

        # severeness onset after death or recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 28,
            death = 27,
        )
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 28,
            recovery = 27,
        )

        # hospital admission after death or recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 36,
            death = 35,
        )
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 36,
            recovery = 35,
        )

        # icu admission after death or recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 41,
            death = 40,
        )
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 41,
            recovery = 40,
        )

        # ventilation admission after death or recovery
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            ventilation_admission = 46,
            death = 45,
        )
        @test_throws ArgumentError DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            ventilation_admission = 46,
            recovery = 45,
        )
        
    end

    @testset "Getter & Setter" begin
        dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            ventilation_admission = 45,
            ventilation_discharge = 70,
            icu_discharge = 75,
            hospital_discharge = 80,
            severeness_offset = 81,
            recovery = 85
        )

        @test exposure(dp) == 23
        @test infectiousness_onset(dp) == 25
        @test symptom_onset(dp) == 26
        @test severeness_onset(dp) == 30
        @test hospital_admission(dp) == 35
        @test icu_admission(dp) == 40
        @test ventilation_admission(dp) == 45
        @test ventilation_discharge(dp) == 70
        @test icu_discharge(dp) == 75
        @test hospital_discharge(dp) == 80
        @test severeness_offset(dp) == 81
        @test recovery(dp) == 85

        dp = DiseaseProgression(
            exposure = 10,
            infectiousness_onset = 12,
            symptom_onset = 13,
            death = 20,
        )

        @test death(dp) == 20
    end

    @testset "States" begin
        dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 27,
            severeness_onset = 30,
            hospital_admission = 35,
            icu_admission = 40,
            ventilation_admission = 45,
            ventilation_discharge = 70,
            icu_discharge = 75,
            hospital_discharge = 80,
            severeness_offset = 81,
            recovery = 85
        )

        a_dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            recovery = 31
        )

        d_dp = DiseaseProgression(
            exposure = 23,
            infectiousness_onset = 25,
            symptom_onset = 26,
            death = 70,
        )
        

        # infected
        @test infected(dp, Int16(25)) == true
        @test infected(dp, Int16(22)) == false # before
        @test infected(dp, Int16(86)) == false # after

        # infectious
        @test infectious(dp, Int16(27)) == true
        @test infectious(dp, Int16(24)) == false # before
        @test infectious(dp, Int16(86)) == false # after

        # asymptomatic
        @test asymptomatic(dp, Int16(24)) == false
        @test asymptomatic(dp, Int16(28)) == false

        @test asymptomatic(a_dp, Int16(26)) == true
        @test asymptomatic(a_dp, Int16(22)) == false # before
        @test asymptomatic(a_dp, Int16(32)) == false # after


        # pre-symptomatic
        @test presymptomatic(dp, Int16(26)) == true
        @test presymptomatic(dp, Int16(22)) == false # before
        @test presymptomatic(dp, Int16(28)) == false # after

        @test presymptomatic(a_dp, Int16(24)) == false # asympptomatic can never be presymptomatic

        # symptomatic
        @test symptomatic(dp, Int16(28)) == true
        @test symptomatic(dp, Int16(32)) == true # also true with severe symptoms
        @test symptomatic(dp, Int16(22)) == false # before
        @test symptomatic(dp, Int16(86)) == false # after

        @test symptomatic(a_dp, Int16(26)) == false # asymptomatic can never be symptomatic

        # mild
        @test mild(dp, Int16(28)) == true
        @test mild(dp, Int16(31)) == false # with severe symptoms
        @test mild(dp, Int16(25)) == false # before

        @test mild(a_dp, Int16(26)) == false # asymptomatic can never be mild

        # severe
        @test severe(dp, Int16(31)) == true
        @test severe(dp, Int16(29)) == false # before
        @test severe(dp, Int16(82)) == false # after

        @test severe(a_dp, Int16(26)) == false # asymptomatic can never be severe

        # hospitalized
        @test hospitalized(dp, Int16(36)) == true
        @test hospitalized(dp, Int16(34)) == false # before
        @test hospitalized(dp, Int16(81)) == false # after

        @test hospitalized(a_dp, Int16(26)) == false # asymptomatic can never be hospitalized

        # icu
        @test icu(dp, Int16(41)) == true
        @test icu(dp, Int16(39)) == false # before
        @test icu(dp, Int16(76)) == false # after

        @test icu(a_dp, Int16(26)) == false # asymptomatic can never be in icu

        # ventilated
        @test ventilated(dp, Int16(46)) == true
        @test ventilated(dp, Int16(44)) == false # before
        @test ventilated(dp, Int16(71)) == false # after

        @test ventilated(a_dp, Int16(26)) == false # asymptomatic can never be ventilated

        # recovered
        @test recovered(dp, Int16(86)) == true
        @test recovered(dp, Int16(84)) == false # before

        @test recovered(a_dp, Int16(32)) == true
        @test recovered(a_dp, Int16(30)) == false # before

        # dead
        @test dead(dp, Int16(86)) == false
        @test dead(dp, Int16(84)) == false # before

        @test dead(d_dp, Int16(71)) == true
        @test dead(d_dp, Int16(69)) == false # before
    end

    # @testset "Sampling Times" begin
    #     p = Pathogen(   
    #         id = 1,
    #         name = "COVID",
    #         infection_rate = Uniform(0,1),
    #         transmission_function = ConstantTransmissionRate(),
    #         mild_death_rate = Uniform(0,0.005),
    #         severe_death_rate= Uniform(0,0.1),
    #         critical_death_rate = Uniform(0,0.1),
            
    #         hospitalization_rate = Uniform(0, 0.1),
    #         ventilation_rate = Uniform(0, 0.1),
    #         icu_rate = Uniform(0, 0.1),
            
    #         onset_of_symptoms = Uniform(2,3),
    #         onset_of_severeness = Uniform(2,3),
    #         infectious_offset = Uniform(0,1),
    #         time_to_hospitalization = Uniform(1,4),
    #         time_to_icu = Uniform(1,2),

    #         time_to_recovery = Uniform(5,6),
    #         length_of_stay = Uniform(6,7)
    #     )
    #     ind = Individual(id = 1, age = 18, sex = 1)
    #     ind2 = Individual(id = 2, age = 55, sex = 1)
    #     house = Household(id = 1, individuals = [ind, ind2], contact_sampling_method = RandomSampling())

    #     # draw values
    #     @test 0 <= transmission_probability(p.transmission_function, ind, ind2, house, Int16(1)) <= 1
    #     @test 0 <= sample_mild_death_rate(p, ind) <= 0.005
    #     @test 0 <= sample_severe_death_rate(p, ind) <= 0.1
    #     @test 0 <= sample_critical_death_rate(p, ind) <= 0.1

    #     @test 0 <= sample_hospitalization_rate(p, ind) <= 0.1
    #     @test 0 <= sample_ventilation_rate(p, ind) <= 0.1
    #     @test 0 <= sample_icu_rate(p, ind) <= 0.1

    #     @test 0 <= sample_infectious_offset(p, ind) <= 1
    #     @test 5 <= sample_time_to_recovery(p, ind) <= 6
    #     @test 2 <= sample_onset_of_symptoms(p, ind) <= 3
    #     @test 2 <= sample_onset_of_severeness(p, ind) <= 3
    #     @test 1 <= sample_time_to_hospitalization(p, ind) <= 4
    #     @test 1 <= sample_time_to_icu(p, ind) <= 2
    #     @test 6 <= sample_length_of_stay(p, ind) <= 7
    # end

    # @testset "DiseaseProgressionStrat" begin
    #     # Test for wrong DiseaseProgressionStrat
    #     dict = Dict(
    #         "age_groups" => ["0-40", "40-80"],
    #         "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
    #         "stratification_matrix" => [[1, 0, 0, 0], [0.3, 0.3, 0.3, 0.1], [0.1, 0.2, 0.3, 0.4]]
    #     )
    #     # missing an age group
    #     @test_throws ErrorException("Provided age groups and the stratification matrix"*
    #         " don't match in dimensions as there are 2 age groups, but only 3 rows in"*
    #         " the stratification matrix."
    #         ) DiseaseProgressionStrat(dict)

    #     dict["age_groups"] = ["0-40", "40-80", "80+"]
    #     dict["disease_compartments"] = ["Asymptomatic", "Mild", "Severe"]
    #     dict["stratification_matrix"] = [[1, 0, 0], [0.3, 0.3, 0.3, 0.1], [0.1, 0.2, 0.7]]

    #     # second row has too many columns
    #     @test_throws ErrorException("Provided disease compartments and the stratification"*
    #         " matrix don't match in dimensions as there are 3 age groups, but only 4"
    #         *" columns in the stratification matrix in row 2."
    #         ) DiseaseProgressionStrat(dict)

    #     dict["disease_compartments"] = ["Asymptomatic", "Mild", "Severe", "Critical"]
    #     dict["stratification_matrix"] = [[1, 0, 0, 0], [0.3, 0.3, 0.3, 0.1], [0.1, 0.2, 0.3, 0.3]]

    #     # third row doesnt add up to 1
    #     @test_throws ErrorException(
    #         "Provided stratification matrix for disease progression is NOT stochastic! "*
    #         "Sum of entries in row 3 don't sum up to 1, but to "*
    #         string(sum([0.1, 0.2, 0.3, 0.3]))*"."
    #         ) DiseaseProgressionStrat(dict)

    # end

    # @testset "Estimate Final Status" begin
    #     i1 = Individual(id = 1, age = 70, sex = 1)
    #     dict = Dict(
    #         "age_groups" => ["0-40", "40-80", "80+"],
    #         "disease_compartments" => ["Asymptomatic", "Mild", "Severe", "Critical"],
    #         "stratification_matrix" => [[1.0, 0.0, 0.0, 0.0], [0.3, 0.3, 0.3, 0.1], [0.1, 0.2, 0.3, 0.4]]
    #     )
    #     dpr = DiseaseProgressionStrat(dict)

    #     Random.seed!(42)
    #     @test GEMS.Severe == estimate_disease_progression(dpr, i1)
    #     @test GEMS.Mild == estimate_disease_progression(dpr, i1)
    # end

    # @testset "Progressions" begin
    #     ind = Individual(id = 1, age = 42, sex = 0)
    #     exposedtick = Int16(0)
    #     p = Pathogen(
    #         id = 1,
    #         name = "COVID",
    #         infection_rate = Uniform(0,1),
    #         mild_death_rate = Uniform(0.029,0.03),
    #         severe_death_rate= Uniform(0.19,0.2),
    #         critical_death_rate = Uniform(0,0.1),
            
    #         hospitalization_rate = Uniform(0, 0.1),
    #         ventilation_rate = Uniform(0, 0.1),
    #         icu_rate = Uniform(0, 0.1),
            
    #         onset_of_symptoms = Uniform(2,3),
    #         onset_of_severeness = Uniform(2,3),
    #         infectious_offset = Uniform(0,1),
    #         time_to_hospitalization = Uniform(1,4),
    #         time_to_icu = Uniform(1,2),

    #         time_to_recovery = Uniform(5,6),
    #         length_of_stay = Uniform(7,8)
    #     )

    #     @testset "Asymptomatic" begin
    #         reset!(ind)
    #         disease_progression!(ind, p, exposedtick, GEMS.Asymptomatic)
    #         @test symptom_category(ind) == GEMS.SYMPTOM_CATEGORY_ASYMPTOMATIC
    #         # test unset times
    #         @test onset_of_symptoms(ind) == GEMS.DEFAULT_TICK
    #         @test onset_of_severeness(ind) == GEMS.DEFAULT_TICK
    #         @test hospitalized_tick(ind) == GEMS.DEFAULT_TICK
    #         @test ventilation_tick(ind) == GEMS.DEFAULT_TICK
    #         @test icu_tick(ind) == GEMS.DEFAULT_TICK
    #         @test death_tick(ind) == GEMS.DEFAULT_TICK
    #         # test set Times
    #         @test infectious_tick(ind) >= 0
    #         @test removed_tick(ind) >= infectious_tick(ind)
    #     end
    #     @testset "Mild" begin
    #         reset!(ind)
    #         Random.seed!(0127)
    #         disease_progression!(ind, p, exposedtick, GEMS.Mild)
    #         @test symptom_category(ind) == GEMS.SYMPTOM_CATEGORY_MILD
    #         # test unset times
    #         @test onset_of_severeness(ind) == GEMS.DEFAULT_TICK
    #         @test hospitalized_tick(ind) == GEMS.DEFAULT_TICK
    #         @test ventilation_tick(ind) == GEMS.DEFAULT_TICK
    #         @test icu_tick(ind) == GEMS.DEFAULT_TICK
    #         # test set Times
    #         @test infectious_tick(ind) >= 0
    #         @test onset_of_symptoms(ind) >= infectious_tick(ind)
    #         @test removed_tick(ind) > onset_of_symptoms(ind)
    #         @test death_tick(ind) == removed_tick(ind) # dies on this seed with this mild death reate
    #         # and now a seed where he doesnt die
    #         reset!(ind)
    #         Random.seed!(42)
    #         disease_progression!(ind, p, exposedtick, GEMS.Mild)
    #         @test death_tick(ind) == GEMS.DEFAULT_TICK
    #     end
    #     @testset "Severe" begin
    #         reset!(ind)
    #         Random.seed!(6)
    #         disease_progression!(ind, p, exposedtick, GEMS.Severe)
    #         @test symptom_category(ind) == GEMS.SYMPTOM_CATEGORY_SEVERE
    #         # test unset times
    #         @test ventilation_tick(ind) == GEMS.DEFAULT_TICK
    #         @test icu_tick(ind) == GEMS.DEFAULT_TICK
    #         # test set Times
    #         @test infectious_tick(ind) >= 0
    #         @test onset_of_symptoms(ind) >= infectious_tick(ind)
    #         @test onset_of_severeness(ind) > onset_of_symptoms(ind)
    #         @test removed_tick(ind) > onset_of_severeness(ind)
            
    #         # TODO test death and hospitalization + length of stay
    #         # death without hospitalization on this seed
    #         @test death_tick(ind) == removed_tick(ind)
    #         @test hospitalized_tick(ind) == GEMS.DEFAULT_TICK

    #         # no death
    #         reset!(ind)
    #         Random.seed!(1234)
    #         disease_progression!(ind, p, exposedtick, GEMS.Severe)
    #         @test death_tick(ind) == GEMS.DEFAULT_TICK
    #         @test hospitalized_tick(ind) == GEMS.DEFAULT_TICK

    #         # hopsitalized and no death
    #         p.hospitalization_rate = Uniform(0.98, 0.99)
    #         reset!(ind)
    #         Random.seed!(1234)
    #         disease_progression!(ind, p, exposedtick, GEMS.Severe)
    #         @test death_tick(ind) == GEMS.DEFAULT_TICK
    #         @test hospitalized_tick(ind) >= onset_of_severeness(ind)
    #         @test hospitalized_tick(ind) + minimum(length_of_stay(p)) <= removed_tick(ind) <= hospitalized_tick(ind) + maximum(length_of_stay(p))
    #         # @test quarantine_tick(ind) == hospitalized_tick(ind)
    #         # @test quarantine_release_tick(ind) == removed_tick(ind)

    #         # hospitalized and death
    #         reset!(ind)
    #         Random.seed!(42)
    #         disease_progression!(ind, p, exposedtick, GEMS.Severe)
    #         @test hospitalized_tick(ind) >= onset_of_severeness(ind)
    #         @test hospitalized_tick(ind) + minimum(length_of_stay(p)) <= removed_tick(ind) <= hospitalized_tick(ind) + maximum(length_of_stay(p))
    #         #@test quarantine_tick(ind) == hospitalized_tick(ind)
    #         #@test quarantine_release_tick(ind) == removed_tick(ind)
    #         @test death_tick(ind) == removed_tick(ind)
    #     end
       
    #     @testset "Critical" begin
    #         reset!(ind)
    #         Random.seed!(42)
    #         disease_progression!(ind, p, exposedtick, GEMS.Critical)
    #         @test symptom_category(ind) == GEMS.SYMPTOM_CATEGORY_CRITICAL
    #         # no death, no ventilation, no icu
    #         @test infectious_tick(ind) >= 0
    #         @test onset_of_symptoms(ind) >= infectious_tick(ind)
    #         @test onset_of_severeness(ind) > onset_of_symptoms(ind)
    #         @test hospitalized_tick(ind) >= onset_of_severeness(ind)
    #         @test removed_tick(ind) > onset_of_severeness(ind)
    #         @test hospitalized_tick(ind) + minimum(length_of_stay(p)) <= removed_tick(ind) <= hospitalized_tick(ind) + maximum(length_of_stay(p))
    #         # @test quarantine_tick(ind) == hospitalized_tick(ind)
    #         # @test quarantine_release_tick(ind) == removed_tick(ind)
    #         @test death_tick(ind) == GEMS.DEFAULT_TICK
    #         @test ventilation_tick(ind) == GEMS.DEFAULT_TICK
    #         @test icu_tick(ind) == GEMS.DEFAULT_TICK

    #         # death, but nothing else
    #         reset!(ind)
    #         Random.seed!(6)
    #         disease_progression!(ind, p, exposedtick, GEMS.Critical)
    #         @test death_tick(ind) == removed_tick(ind) 

    #         # ventilation no death
    #         p.ventilation_rate = Uniform(0.98,0.99)
    #         reset!(ind)
    #         Random.seed!(42)
    #         disease_progression!(ind, p, exposedtick, GEMS.Critical)
    #         @test ventilation_tick(ind) >= hospitalized_tick(ind) || ventilation_tick(ind) == -1
    #         @test death_tick(ind) == GEMS.DEFAULT_TICK
    #         @test icu_tick(ind) == GEMS.DEFAULT_TICK

    #         # ventilation and death
    #         reset!(ind)
    #         Random.seed!(13)
    #         disease_progression!(ind, p, exposedtick, GEMS.Critical)
    #         @test ventilation_tick(ind) >= hospitalized_tick(ind) || ventilation_tick(ind) == -1
    #         @test death_tick(ind) == removed_tick(ind) 
    #         @test icu_tick(ind) == GEMS.DEFAULT_TICK

    #         # ICU no death
    #         p.icu_rate = Uniform(0.98, 0.99)
    #         reset!(ind)
    #         Random.seed!(42)
    #         disease_progression!(ind, p, exposedtick, GEMS.Critical)
    #         @test ventilation_tick(ind) >= hospitalized_tick(ind) || ventilation_tick(ind) == -1
    #         @test death_tick(ind) == GEMS.DEFAULT_TICK
    #         @test removed_tick(ind) >= ventilation_tick(ind) >= icu_tick(ind)

    #         # ICU and death
    #         p.critical_death_rate = Uniform(0.98,0.99)
    #         reset!(ind)
    #         Random.seed!(42)
    #         disease_progression!(ind, p, exposedtick, GEMS.Critical)
    #         @test ventilation_tick(ind) >= hospitalized_tick(ind) || ventilation_tick(ind) == -1
    #         @test death_tick(ind) == removed_tick(ind)
    #         @test removed_tick(ind) >= ventilation_tick(ind) >= icu_tick(ind)
    #     end
    # end
    # @testset "Agent-Level Updates" begin
    #     p = Pathogen(id = 1, name = "Test")
    #     exposedtick = Int16(0)
    #     indiv = Individual(id=1, sex=1, age=40)
        
    #     @testset "Asymptomatic" begin
    #         reset!(indiv)
    #         # infect individual
    #         indiv.exposed_tick = exposedtick
    #         indiv.disease_state = GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #         indiv.number_of_infections += 1
    #         indiv.pathogen_id = id(p)

    #         Random.seed!(1234)
    #         disease_progression!(indiv, p, exposedtick, GEMS.Asymptomatic)

    #         for tick in range(exposedtick, removed_tick(indiv)-Int16(1))
    #             progress_disease!(indiv, tick)
    #             if tick < infectious_tick(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #                 @test exposed(indiv)
    #                 @test !infectious(indiv)
    #             end
    #             if infectious_tick(indiv) <= tick < removed_tick(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #                 @test !exposed(indiv)
    #                 @test infectious(indiv)
    #             end
    #         end
    #     end

    #     @testset "Mild" begin
    #         reset!(indiv)
    #         # infect individual
    #         indiv.exposed_tick = exposedtick
    #         indiv.disease_state = GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #         indiv.number_of_infections += 1
    #         indiv.pathogen_id = id(p)

    #         Random.seed!(1234)
    #         disease_progression!(indiv, p, exposedtick, GEMS.Mild)

    #         for tick in range(exposedtick, removed_tick(indiv)-Int16(1))
    #             progress_disease!(indiv, tick)
    #             if tick < infectious_tick(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #                 @test exposed(indiv)
    #                 @test !infectious(indiv)
    #             end
    #             if infectious_tick(indiv) <= tick < onset_of_symptoms(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #                 @test !exposed(indiv)
    #                 @test infectious(indiv)
    #             end
    #             if onset_of_symptoms(indiv) <= tick < removed_tick(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_SYMPTOMATIC
    #                 @test infectious(indiv)
    #             end
    #         end
    #     end

    #     @testset "Severe" begin
    #         reset!(indiv)
    #         # infect individual
    #         indiv.exposed_tick = exposedtick
    #         indiv.disease_state = GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #         indiv.number_of_infections += 1
    #         indiv.pathogen_id = id(p)

    #         # should hospitalize
    #         p.hospitalization_rate = Uniform(0.98, 0.99)
    #         Random.seed!(42)
    #         disease_progression!(indiv, p, exposedtick, GEMS.Severe)

    #         for tick in range(exposedtick, removed_tick(indiv)-Int16(1))
    #             progress_disease!(indiv, tick)
    #             if tick < infectious_tick(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #                 @test exposed(indiv)
    #                 @test !infectious(indiv)
    #             end
    #             if infectious_tick(indiv) <= tick < onset_of_symptoms(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #                 @test !exposed(indiv)
    #                 @test infectious(indiv)
    #             end
    #             if onset_of_symptoms(indiv) <= tick < onset_of_severeness(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_SYMPTOMATIC
    #                 @test infectious(indiv)
    #             end
    #             if onset_of_severeness(indiv) <= tick
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_SEVERE
    #                 @test infectious(indiv)
    #             end
    #             if hospitalized_tick(indiv) <= tick
    #                 @test hospitalized(indiv)
    #             end
    #         end
    #     end

    #     @testset "Critical" begin
    #         reset!(indiv)
    #         # infect individual
    #         indiv.exposed_tick = exposedtick
    #         indiv.disease_state = GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #         indiv.number_of_infections += 1
    #         indiv.pathogen_id = id(p)

    #         # should do ICU and Ventilation
    #         p.icu_rate = Uniform(0.98, 0.99)
    #         p.ventilation_rate = Uniform(0.98,0.99)

    #         Random.seed!(42)
    #         disease_progression!(indiv, p, exposedtick, GEMS.Critical)
    #         for tick in range(exposedtick, removed_tick(indiv)-Int16(1))
    #             progress_disease!(indiv, tick)
    #             if tick < infectious_tick(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #                 @test exposed(indiv)
    #                 @test !infectious(indiv)
    #             end
    #             if infectious_tick(indiv) <= tick < onset_of_symptoms(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #                 @test !exposed(indiv)
    #                 @test infectious(indiv)
    #             end
    #             if onset_of_symptoms(indiv) <= tick < onset_of_severeness(indiv)
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_SYMPTOMATIC
    #                 @test infectious(indiv)
    #             end
    #             if onset_of_severeness(indiv) <= tick
    #                 @test disease_state(indiv) == GEMS.DISEASE_STATE_SEVERE
    #                 @test infectious(indiv)
    #             end
    #             if hospitalized_tick(indiv) <= tick
    #                 @test hospitalized(indiv)
    #             end
    #             if ventilation_tick(indiv) <= tick < icu_tick(indiv)
    #                 @test ventilated(indiv)
    #             end
    #             if icu_tick(indiv) <= tick
    #                 @test icu(indiv)
    #             end
    #         end
    #     end

    #     @testset "Update during step!" begin
    #         reset!(indiv)
    #         inf_frac = InfectedFraction(0.05, p)
    #         times_up = TimesUp(120)
    #         sim = Simulation(
    #             "",
    #             inf_frac,
    #             times_up,
    #             Population([indiv]),
    #             SettingsContainer(),
    #             "test"   
    #         )
    #         sim.pathogen = p    

    #         # test if individual updates 
    #         indiv.disease_state = GEMS.DISEASE_STATE_PRESYMPTOMATIC
    #         indiv.exposed_tick = 1
    #         indiv.infectious_tick = 5
    #         indiv.onset_of_symptoms = 7
    #         indiv.removed_tick = 20
    #         indiv.death_tick = 20
    #         indiv.symptom_category = GEMS.SYMPTOM_CATEGORY_MILD # mild disease (but it still will die)

    #         # go to infectious
    #         sim.tick = Int16(5)
    #         update_individual!(indiv, tick(sim), sim)
    #         @test infectiousness(indiv) > 0
    #         @test presymptomatic(indiv)
    #         @test length(deathlogger(sim).id) == 0
    #         @test !dead(indiv)

    #         sim.tick = Int16(7)
    #         update_individual!(indiv, tick(sim), sim)
    #         @test infectiousness(indiv) > 0
    #         @test symptomatic(indiv)
    #         @test length(deathlogger(sim).id) == 0
    #         @test !dead(indiv)

    #         sim.tick = Int16(20)
    #         update_individual!(indiv, tick(sim), sim)
    #         @test infectiousness(indiv) == 0
    #         @test indiv.disease_state == 0
    #         @test !infected(indiv)
    #         @test length(deathlogger(sim).id) == 1
    #         @test dead(indiv)

    #         # now test if nothing happens, when the individuals is not infected
    #         reset!(indiv)
    #         sim = Simulation(
    #             "",
    #             inf_frac,
    #             times_up,
    #             Population([indiv]),
    #             SettingsContainer(),
    #             "test"   
    #         )
    #         sim.pathogen = p  

    #         # dont set disease state! The disease state determines, if we count indiv as infected
    #         indiv.exposed_tick = 1
    #         indiv.infectious_tick = 5
    #         indiv.onset_of_symptoms = 7
    #         indiv.removed_tick = 20
    #         indiv.death_tick = 20
    #         indiv.symptom_category = GEMS.SYMPTOM_CATEGORY_MILD # mild disease (but it still will die)
    #         @test !infected(indiv)
    #         @test length(deathlogger(sim).id) == 0
    #         sim.tick = Int16(20)
    #         update_individual!(indiv, tick(sim), sim)
    #         @test !dead(indiv)
    #         @test length(deathlogger(sim).id) == 0
    #     end
    # end

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