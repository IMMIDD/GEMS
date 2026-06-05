@testset "Pathogens" begin

    # building blocks for tests
    sim = Simulation(pop_size = 1000)

    # distributions
    poi1 = Poisson(1)
    poi2 = Poisson(2)
    poi3 = Poisson(3)
    poi4 = Poisson(4)
    poi5 = Poisson(5)
    poi7 = Poisson(7)
    poi10 = Poisson(10)
    poi15 = Poisson(15)
    poi20 = Poisson(20)

    # progressions
    pr_asymp = Asymptomatic(
        exposure_to_infectiousness_onset = poi2,
        infectiousness_onset_to_recovery = poi5
    )

    pr_sympt = Symptomatic(
        exposure_to_infectiousness_onset = poi2,
        infectiousness_onset_to_symptom_onset = poi1,
        symptom_onset_to_recovery = poi7
    )

    pr_sev = Severe(
        exposure_to_infectiousness_onset = poi2,
        infectiousness_onset_to_symptom_onset = poi1,
        symptom_onset_to_severeness_onset = poi2,
        severeness_onset_to_severeness_offset = poi3,
        severeness_offset_to_recovery = poi4
    )

    pr_hosp = Hospitalized(
        exposure_to_infectiousness_onset = poi1,
        infectiousness_onset_to_symptom_onset = poi1,
        symptom_onset_to_severeness_onset = poi1,
        severeness_onset_to_hospital_admission = poi2,
        hospital_admission_to_hospital_discharge = poi7,
        hospital_discharge_to_severeness_offset = poi3,
        severeness_offset_to_recovery = poi4
    )

    pr_crit = Critical(
        exposure_to_infectiousness_onset = poi1,
        infectiousness_onset_to_symptom_onset = poi1,
        symptom_onset_to_severeness_onset = poi1,
        severeness_onset_to_hospital_admission = poi2,
        hospital_admission_to_icu_admission = poi2,
        icu_admission_to_icu_discharge = poi7,
        icu_discharge_to_hospital_discharge = poi7,
        hospital_discharge_to_severeness_offset = poi3,
        severeness_offset_to_recovery = poi4,
        icu_admission_to_death = poi10,
        death_probability = 0.3
    )

    # progression assignment
    paf = RandomProgressionAssignment([Asymptomatic, Symptomatic, Severe, Hospitalized, Critical])

    # transmission function
    ctf = ConstantTransmissionRate(transmission_rate = 0.25)

    @testset "General" begin
        # passing
        p = Pathogen(
            name = "TestPathogen",
            id = 5,
            progressions = [pr_asymp, pr_sympt, pr_sev, pr_hosp, pr_crit],
            progression_assignment = paf,
            transmission_function = ctf,
        )
        @test name(p) == "TestPathogen"
        @test id(p) == 5
        @test length(progressions(p)) == 5
        @test get_progression(p, Asymptomatic) === pr_asymp
        @test get_progression(p, Symptomatic) === pr_sympt
        @test get_progression(p, Severe) === pr_sev
        @test get_progression(p, Hospitalized) === pr_hosp
        @test get_progression(p, Critical) === pr_crit
        @test progression_assignment(p) === paf
        @test transmission_function(p) === ctf

        # failing
        @test_throws ArgumentError Pathogen(name = "", id = 1)
        @test_throws ArgumentError Pathogen(name = "DoubleProgressions", id = 2, progressions = [pr_asymp, pr_asymp])

    end

    @testset "Progression Categories" begin
       
        # asymptomatic
        @test pr_asymp.exposure_to_infectiousness_onset === poi2
        @test pr_asymp.infectiousness_onset_to_recovery === poi5

        # symptomatic
        @test pr_sympt.exposure_to_infectiousness_onset === poi2
        @test pr_sympt.infectiousness_onset_to_symptom_onset === poi1
        @test pr_sympt.symptom_onset_to_recovery === poi7

        # severe
        @test pr_sev.exposure_to_infectiousness_onset === poi2
        @test pr_sev.infectiousness_onset_to_symptom_onset === poi1
        @test pr_sev.symptom_onset_to_severeness_onset === poi2
        @test pr_sev.severeness_onset_to_severeness_offset === poi3
        @test pr_sev.severeness_offset_to_recovery === poi4

        # hospitalized
        @test pr_hosp.exposure_to_infectiousness_onset === poi1
        @test pr_hosp.infectiousness_onset_to_symptom_onset === poi1
        @test pr_hosp.symptom_onset_to_severeness_onset === poi1
        @test pr_hosp.severeness_onset_to_hospital_admission === poi2
        @test pr_hosp.hospital_admission_to_hospital_discharge === poi7
        @test pr_hosp.hospital_discharge_to_severeness_offset === poi3
        @test pr_hosp.severeness_offset_to_recovery === poi4

        # critical
        @test pr_crit.exposure_to_infectiousness_onset === poi1
        @test pr_crit.infectiousness_onset_to_symptom_onset === poi1
        @test pr_crit.symptom_onset_to_severeness_onset === poi1
        @test pr_crit.severeness_onset_to_hospital_admission === poi2
        @test pr_crit.hospital_admission_to_icu_admission === poi2
        @test pr_crit.icu_admission_to_icu_discharge === poi7
        @test pr_crit.icu_discharge_to_hospital_discharge === poi7
        @test pr_crit.hospital_discharge_to_severeness_offset === poi3
        @test pr_crit.severeness_offset_to_recovery === poi4
        @test pr_crit.icu_admission_to_death === poi10
        @test pr_crit.death_probability == 0.3
    end

    @testset "Custom Progression Category" begin
        # define custom progression category
        # similar to Symptomatic but with an extra custom parameter
        mutable struct TestProgression <: GEMS.ProgressionCategory
            exposure_to_infectiousness_onset::Distribution
            infectiousness_onset_to_symptom_onset::Distribution
            symptom_onset_to_recovery::Distribution
            custom_parameter::Float64
        end

        # define calcuate progression function
        function GEMS.calculate_progression(individual::Individual, tick::Int16, dp::TestProgression, rng::Xoshiro )
            
            # Calculate the time to infectiousness
            infectiousness_onset = tick + Int16(1) + rand_val(dp.exposure_to_infectiousness_onset, rng)

            # Calculate the time to symptom onset
            symptom_onset = infectiousness_onset + rand_val(dp.infectiousness_onset_to_symptom_onset, rng)

            # Calculate the time to recovery
            recovery = symptom_onset + rand_val(dp.symptom_onset_to_recovery, rng)

            return DiseaseProgression(
                exposure = Int16(tick),
                infectiousness_onset = Int16(infectiousness_onset),
                symptom_onset = Int16(symptom_onset),
                recovery = Int16(recovery)
            )
        end

        # create instance
        tp = TestProgression(
            poi3,
            poi2,
            poi15,
            0.75
        )

        # create pathogen with custom progression
        # no progression assignment needed for this test
        # as it will default to RandomProgressionAssignment with only one option
        p_custom = Pathogen(
            name = "CustomPathogen",
            id = 10,
            progressions = [tp],
            transmission_function = ctf,
        )

        @test length(progressions(p_custom)) == 1
        @test get_progression(p_custom, TestProgression) === tp
        @test tp.custom_parameter == 0.75

        sim = Simulation(pop_size = 1000, pathogen = p_custom, infected_fraction = 0.1)
        run!(sim)
        
        flattened_pc = vcat(infectionlogger(sim).progression_category...)

        # check if all infections used the custom progression category in simulation
        @test all(pc -> pc == :TestProgression, flattened_pc)
        
        # Check if there were infections
        @test length(infectionlogger(sim)) > 0
    end

    @testset "Progression Assignment" begin
        ### RANDOM PROGRESSION ASSIGNMENT
        # THINGS THAT SHOULD WORK
        pgrs = [Asymptomatic, Symptomatic, Severe, Hospitalized, Critical]
        rpa = RandomProgressionAssignment(pgrs) 
        i = individuals(sim)[1]

        res = GEMS.assign(i, rpa, rng(sim))
        @test res in pgrs

        # THINGS THAT SHOULD NOT WORK
        # empty progression categories
        @test_throws ArgumentError RandomProgressionAssignment(DataType[])
        # non-existing progression category
        @test_throws ArgumentError RandomProgressionAssignment([Asymptomatic, Symptomatic, Household])
        # duplicate progression category
        @test_throws ArgumentError RandomProgressionAssignment([Asymptomatic, Symptomatic, Symptomatic])
        

        ### AGE-BASED PROGRESSION ASSIGNMENT
        # THINGS THAT SHOULD WORK
        age_groups = ["0-19", "20-39", "40-59", "60-"]
        progression_categories = ["Asymptomatic", "Symptomatic", "Hospitalized", "Critical"]
        stratification_matrix = [
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0]
        ]

        abpa = AgeBasedProgressionAssignment(
            age_groups = age_groups,
            progression_categories = progression_categories,
            stratification_matrix = stratification_matrix
        )

        res = (i -> GEMS.assign(i, abpa, rng(sim))).(individuals(sim))
        for (ind, pc) in zip(individuals(sim), res)
            if age(ind) <= 19
                @test pc == Asymptomatic
            elseif age(ind) <= 39
                @test pc == Symptomatic
            elseif age(ind) <= 59
                @test pc == Hospitalized
            else
                @test pc == Critical
            end
        end

        # THINGS THAT SHOULD NOT WORK
        # -> AGE GROUPS
        # empty age groups
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = String[],
            progression_categories = progression_categories,
            stratification_matrix = stratification_matrix
        )
        # non-continuous age groups
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = ["0-19", "21-39", "40-59", "60-"],
            progression_categories = progression_categories,
            stratification_matrix = stratification_matrix
        )
        # not starting at 0
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = ["10-19", "20-39", "40-59", "60-"],
            progression_categories = progression_categories,
            stratification_matrix = stratification_matrix
        )
        # non-open ended age groups
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = ["0-19", "20-39", "40-59", "60-79"],
            progression_categories = progression_categories,
            stratification_matrix = stratification_matrix
        )
        # non-numeric age group
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = ["0-19", "20-39", "forty-59", "60-"],
            progression_categories = progression_categories,
            stratification_matrix = stratification_matrix
        )

        # -> PROGRESSION CATEGORIES
        # empty progression categories
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = age_groups,
            progression_categories = String[],
            stratification_matrix = stratification_matrix
        )
        # non-existing progression category
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = age_groups,
            progression_categories = ["Asymptomatic", "Symptomatic", "Hospitalized", "NonExistingProgression"],
            stratification_matrix = stratification_matrix
        )
        # duplicate progression category
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = age_groups,
            progression_categories = ["Asymptomatic", "Symptomatic", "Hospitalized", "Symptomatic"],
            stratification_matrix = stratification_matrix
        )

        # -> STRATIFICATION MATRIX
        # wrong size
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = age_groups,
            progression_categories = progression_categories,
            stratification_matrix = [
                [0.5, 0.5, 0.0, 0.0],
                [0.5, 0.5, 0.0, 0.0],
                [0.0, 0.0, 1.0, 0.0]
            ]
        )
        # rows not summing to 1.0
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = age_groups,
            progression_categories = progression_categories,
            stratification_matrix = [
                [0.5, 0.5, 0.0, 0.0],
                [0.3, 0.3, 0.0, 0.0],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0]
            ]
        )
        # negative values
        @test_throws ArgumentError AgeBasedProgressionAssignment(
            age_groups = age_groups,
            progression_categories = progression_categories,
            stratification_matrix = [
                [0.5, 0.5, 0.0, 0.0],
                [0.5, -0.2, 0.7, 0.0],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0]
            ]
        )
        
    end

    @testset "Custom Progression Assignment" begin
        # define custom progression assignment function
        struct EvenOddProgressionAssignment <: GEMS.ProgressionAssignmentFunction
            even_progression::DataType
            odd_progression::DataType
        end

        function GEMS.assign(individual::Individual, pa::EvenOddProgressionAssignment, rng::Xoshiro)
            if iseven(individual.id)
                return pa.even_progression
            else
                return pa.odd_progression
            end
        end

        # create instance
        eo_pa = EvenOddProgressionAssignment(Symptomatic, Asymptomatic)

        # create pathogen with custom progression assignment
        p_eo = Pathogen(
            name = "EvenOddPathogen",
            id = 20,
            progressions = [pr_asymp, pr_sympt],
            progression_assignment = eo_pa,
            transmission_function = ctf,
        )

        sim = Simulation(pop_size = 1000, pathogen = p_eo, infected_fraction = 0.1)
        run!(sim)
        
        flat_id_b = vcat(infectionlogger(sim).id_b...)
        flat_pc = vcat(infectionlogger(sim).progression_category...)
        
        # make sure that there were infections
        @test length(flat_id_b) > 0 

        # check if even IDs got Symptomatic and odd IDs got Asymptomatic
        for (ind_id, pc) in zip(flat_id_b, flat_pc)
            if iseven(ind_id)
                @test pc == :Symptomatic
            else
                @test pc == :Asymptomatic
            end
        end

    end



    @testset "Transmission Function" begin

        @testset "ConstantTransmissionRate" begin
            test_ctr = ConstantTransmissionRate(transmission_rate = 0.3)
            @test test_ctr.transmission_rate == 0.3

            # single-pathogen sim with explicit setup to ensure infecter is infectious
            p_ctr = Pathogen(id=1, name="TestCTR",
                progressions=[Asymptomatic(exposure_to_infectiousness_onset=0, infectiousness_onset_to_recovery=7)],
                transmission_function=test_ctr)
            sim = Simulation(pop_size=1000, pathogens=(p_ctr,), infected_fraction=0.0)
            infecter = individuals(sim)[1]
            suscpt_ind = individuals(sim)[2]
            # infect and advance disease to make infectious
            infect!(infecter, Int16(0), first_pathogen(sim), rng=Xoshiro())
            GEMS.update_individual!(infecter, Int16(1), sim)

            @test transmission_probability(test_ctr, id(first_pathogen(sim)), infecter, suscpt_ind, households(sim)[1], Int16(1), sim) == 0.3

            @test_throws ArgumentError ConstantTransmissionRate(transmission_rate = -0.1)
            @test_throws ArgumentError ConstantTransmissionRate(transmission_rate = 1.5)

            # call with uninfected infecter
            @test_throws ArgumentError transmission_probability(test_ctr, id(first_pathogen(sim)), suscpt_ind, individuals(sim)[3], households(sim)[1], Int16(1), sim)
        end

        @testset "AgeDependentTransmissionRate" begin
            age_groups = ["0-19", "20-39", "40-59", "60-"]
            age_transmissions = [0.0, 0.0, 0.0, 0.4]
            abtr = AgeDependentTransmissionRate(
                age_groups = age_groups,
                transmission_rates = age_transmissions
            )

            @test abtr.age_transmission_rates == age_transmissions

            sim = Simulation(pop_size = 1000, transmission_function = abtr)
            run!(sim)
            rd = ResultData(sim)

            # check if all infectees are older than 60
            @test infections(rd) |>
                df -> df[df.tick .>= 1 .&& df.age_b .< 60, :] |> nrow == 0

            @test_throws ArgumentError AgeDependentTransmissionRate(
                age_groups = String[], transmission_rates = Real[])
            @test_throws ArgumentError AgeDependentTransmissionRate(
                age_groups = ["0-19", "21-39", "40-59", "60-"],
                transmission_rates = [0.1, 0.2, 0.3, 0.4])
            @test_throws ArgumentError AgeDependentTransmissionRate(
                age_groups = ["10-19", "20-39", "40-59", "60-"],
                transmission_rates = [0.1, 0.2, 0.3, 0.4])
            @test_throws ArgumentError AgeDependentTransmissionRate(
                age_groups = ["0-19", "20-39", "40-59", "60-79"],
                transmission_rates = [0.1, 0.2, 0.3, 0.4])
            @test_throws ArgumentError AgeDependentTransmissionRate(
                age_groups = ["0-19", "20-39", "forty-59", "60-"],
                transmission_rates = [0.1, 0.2, 0.3, 0.4])
            @test_throws ArgumentError AgeDependentTransmissionRate(
                age_groups = ["0-19", "20-39", "40-59", "60-"],
                transmission_rates = [0.1, 0.2, 0.3])
            @test_throws ArgumentError AgeDependentTransmissionRate(
                age_groups = ["0-19", "20-39", "40-59", "60-"],
                transmission_rates = [0.1, -0.2, 0.3, 0.4])
            @test_throws ArgumentError AgeDependentTransmissionRate(
                age_groups = ["0-19", "20-39", "40-59", "60-"],
                transmission_rates = [0.1, 1.2, 0.3, 0.4])

            @test !isempty(@capture_out show(abtr))
        end

        @testset "CrossImmunityTransmissionRate" begin
            pid = Int8(1)
            tf_ci = CrossImmunityTransmissionRate(
                transmission_rate = 0.5,
                pathogen_ids = [1, 2],
                cross_immunity_matrix = [1.0 0.6; 0.6 1.0],
                default_cross_factor = 0.3
            )
            @test tf_ci.transmission_rate == 0.5
            @test !isempty(@capture_out show(tf_ci))

            # constructor validation
            @test_throws ArgumentError CrossImmunityTransmissionRate(transmission_rate = -0.1)
            @test_throws ArgumentError CrossImmunityTransmissionRate(transmission_rate = 1.5)
            @test_throws ArgumentError CrossImmunityTransmissionRate(default_cross_factor = -0.1)
            @test_throws ArgumentError CrossImmunityTransmissionRate(default_cross_factor = 1.5)
            @test_throws ArgumentError CrossImmunityTransmissionRate(
                pathogen_ids = [1, 2],
                cross_immunity_matrix = [1.0 0.5; 0.5 1.0; 0.3 0.3])
            @test_throws ArgumentError CrossImmunityTransmissionRate(
                pathogen_ids = [1, 2],
                cross_immunity_matrix = [1.0 1.5; 0.5 1.0])

            p_ci = Pathogen(id=1, name="TestCITR",
                progressions=[Asymptomatic(exposure_to_infectiousness_onset=0, infectiousness_onset_to_recovery=10)],
                transmission_function=tf_ci)
            sim_ci = Simulation(pop_size=100, pathogens=(p_ci,), infected_fraction=0.0)
            infecter_ci = individuals(sim_ci)[1]
            infectee_ci = individuals(sim_ci)[2]

            infect!(infecter_ci, Int16(0), first_pathogen(sim_ci), rng=Xoshiro())
            GEMS.update_individual!(infecter_ci, Int16(1), sim_ci)
            inf_level = infectiousness(infecter_ci, pid, sim_ci)

            # no immunity: prob = rate * infectiousness/100
            prob_none = transmission_probability(tf_ci, pid, infecter_ci, infectee_ci,
                households(sim_ci)[1], Int16(1), sim_ci)
            @test prob_none ≈ 0.5 * (inf_level / 100.0)

            # full self-immunity: remaining_susceptibility becomes 0
            push_immunity!(immunity_registry(sim_ci, infectee_ci), infectee_ci, pid,
                GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
            update_immunity!(infectee_ci, immunity_registry(sim_ci, infectee_ci),
                GEMS.pathogens(sim_ci), Int16(5), Xoshiro())
            prob_immune = transmission_probability(tf_ci, pid, infecter_ci, infectee_ci,
                households(sim_ci)[1], Int16(5), sim_ci)
            @test prob_immune ≈ 0.0

            # Vector{Vector} constructor: TOML-parsed form is converted to Matrix
            tf_ci_vv = CrossImmunityTransmissionRate(
                transmission_rate = 0.5,
                pathogen_ids = [1, 2],
                cross_immunity_matrix = [[1.0, 0.6], [0.6, 1.0]])
            @test tf_ci_vv.cross_immunity_matrix isa Matrix{Float64}
            @test size(tf_ci_vv.cross_immunity_matrix) == (2, 2)

            # infectee has immunity to pid_other (NOT in pathogen_ids), uses default_cross_factor
            infectee3_ci = individuals(sim_ci)[4]
            push_immunity!(immunity_registry(sim_ci, infectee3_ci), infectee3_ci, Int8(3),
                GEMS.IMMUNITY_SOURCE_NATURAL, Int16(0), Int8(0))
            # set level to 100 directly (update_immunity! requires the pathogen in the sim's tuple)
            let s = infectee3_ci.immunity_cache[1]
                infectee3_ci.immunity_cache = Base.setindex(infectee3_ci.immunity_cache,
                    ImmunityState(s.next, s.natural_acquired_tick, s.vaccine_acquired_tick,
                        Int8(100), s.pathogen_id, s.vaccine_id, s.dose_number), 1)
            end
            prob_cross = transmission_probability(tf_ci, pid, infecter_ci, infectee3_ci,
                households(sim_ci)[1], Int16(1), sim_ci)
            @test prob_cross ≈ 0.5 * (inf_level / 100.0) * (1.0 - 100/100.0 * 0.3)

            # uninfected infecter raises ArgumentError
            @test_throws ArgumentError transmission_probability(tf_ci, pid, infectee_ci,
                individuals(sim_ci)[3], households(sim_ci)[1], Int16(1), sim_ci)
        end

        @testset "ViralInterferenceTransmissionRate" begin
            pid1 = Int8(1)
            pid2 = Int8(2)
            tf_vi = ViralInterferenceTransmissionRate(
                transmission_rate = 0.5,
                pathogen_ids = [1, 2],
                interference_matrix = [1.0 0.4; 0.6 1.0],
                default_interference_factor = 1.0
            )
            @test tf_vi.transmission_rate == 0.5
            @test !isempty(@capture_out show(tf_vi))

            # constructor validation
            @test_throws ArgumentError ViralInterferenceTransmissionRate(transmission_rate = -0.1)
            @test_throws ArgumentError ViralInterferenceTransmissionRate(transmission_rate = 1.5)
            @test_throws ArgumentError ViralInterferenceTransmissionRate(default_interference_factor = -0.1)
            @test_throws ArgumentError ViralInterferenceTransmissionRate(default_interference_factor = 1.5)
            @test_throws ArgumentError ViralInterferenceTransmissionRate(
                pathogen_ids = [1, 2],
                interference_matrix = [1.0 0.4; 0.6 1.0; 0.3 0.3])
            @test_throws ArgumentError ViralInterferenceTransmissionRate(
                pathogen_ids = [1, 2],
                interference_matrix = [1.0 1.5; 0.6 1.0])

            p_vi = Pathogen(id=1, name="TestVITR",
                progressions=[Asymptomatic(exposure_to_infectiousness_onset=0, infectiousness_onset_to_recovery=10)],
                transmission_function=tf_vi)
            sim_vi = Simulation(pop_size=100, pathogens=(p_vi,), infected_fraction=0.0)
            infecter_vi = individuals(sim_vi)[1]
            infectee_vi = individuals(sim_vi)[2]

            infect!(infecter_vi, Int16(0), first_pathogen(sim_vi), rng=Xoshiro())
            GEMS.update_individual!(infecter_vi, Int16(1), sim_vi)
            inf_level = infectiousness(infecter_vi, pid1, sim_vi)

            # no concurrent infections: prob = rate * infectiousness/100 * (1 - immunity/100)
            prob_no_interference = transmission_probability(tf_vi, pid1, infecter_vi, infectee_vi,
                households(sim_vi)[1], Int16(1), sim_vi)
            @test prob_no_interference ≈ 0.5 * (inf_level / 100.0)

            # concurrent infection with pid2 reduces susceptibility by interference_matrix[1,2] = 0.4
            push_infection!(infection_registry(sim_vi, infectee_vi), infectee_vi, pid2, Int32(99),
                DiseaseProgression(exposure=Int16(0), infectiousness_onset=Int16(1), recovery=Int16(20)))
            prob_with_interference = transmission_probability(tf_vi, pid1, infecter_vi, infectee_vi,
                households(sim_vi)[1], Int16(1), sim_vi)
            @test prob_with_interference ≈ prob_no_interference * 0.4

            # Vector{Vector} constructor: TOML-parsed form is converted to Matrix
            tf_vi_vv = ViralInterferenceTransmissionRate(
                transmission_rate = 0.5,
                pathogen_ids = [1, 2],
                interference_matrix = [[1.0, 0.4], [0.6, 1.0]])
            @test tf_vi_vv.interference_matrix isa Matrix{Float64}
            @test size(tf_vi_vv.interference_matrix) == (2, 2)

            # uninfected infecter raises ArgumentError
            @test_throws ArgumentError transmission_probability(tf_vi, pid1, infectee_vi,
                individuals(sim_vi)[3], households(sim_vi)[1], Int16(1), sim_vi)
        end

    end

    @testset "Custom Transmission Function" begin

        # define transmission function to only infect kids under 15 years old
        struct KidsOnlyTransmission <: GEMS.TransmissionFunction
            base_rate::Float64
        end

        function GEMS.transmission_probability(
                transFunc::KidsOnlyTransmission,
                pathogen_id::Int8,
                infecter::Individual,
                infectee::Individual,
                setting::Setting,
                tick::Int16,
                sim::GEMS.Simulation
            )::Float64

            if age(infecter) < 15 && age(infectee) < 15
                return transFunc.base_rate
            else
                return 0.0
            end
        end

        # create instance
        kotf = KidsOnlyTransmission(0.5)
        
        sim = Simulation(pop_size = 10_000, transmission_function = kotf)
        run!(sim)
        rd = ResultData(sim)

        # check if all infections are between kids under 15
        @test infections(rd) |>
            df -> df[df.tick .>= 1 .&& (df.age_a .>= 15 .|| df.age_b .>= 15), :] |> nrow == 0

    end

    ###
    ### ImmunityProfile
    ###
    @testset "ImmunityProfile" begin

        ind = Individual(id=1, sex=0, age=30)
        rng = Xoshiro()
        pid = Int8(1)

        # helper: build an ImmunityState from tick values
        nat_state(t) = ImmunityState(Int32(0), Int16(t), GEMS.DEFAULT_TICK, Int8(0), pid, GEMS.DEFAULT_VACCINE_ID, Int8(0))
        vac_state(t) = ImmunityState(Int32(0), GEMS.DEFAULT_TICK, Int16(t), Int8(0), pid, Int8(1), Int8(1))
        both_state(nt, vt) = ImmunityState(Int32(0), Int16(nt), Int16(vt), Int8(0), pid, Int8(1), Int8(1))
        empty_state = ImmunityState()

        @testset "FullImmunity" begin
            p = FullImmunity()

            # no acquisition: level 0, not stable
            @test calculate_immunity(p, empty_state, ind, Int16(10), rng) == Int8(0)
            @test !immunity_is_stable(p, empty_state, ind, Int16(10))

            # natural acquired in the past: level 100, stable
            @test calculate_immunity(p, nat_state(5), ind, Int16(5), rng) == Int8(100)
            @test calculate_immunity(p, nat_state(5), ind, Int16(10), rng) == Int8(100)
            @test immunity_is_stable(p, nat_state(5), ind, Int16(10))

            # vaccine acquired: level 100
            @test calculate_immunity(p, vac_state(3), ind, Int16(3), rng) == Int8(100)

            # not yet acquired (future tick): level 0
            @test calculate_immunity(p, nat_state(10), ind, Int16(5), rng) == Int8(0)
        end

        @testset "NoImmunity" begin
            p = NoImmunity()

            # always returns 0 regardless of acquisition
            @test calculate_immunity(p, empty_state, ind, Int16(10), rng) == Int8(0)
            @test calculate_immunity(p, nat_state(5), ind, Int16(10), rng) == Int8(0)
            @test calculate_immunity(p, vac_state(3), ind, Int16(10), rng) == Int8(0)

            # always stable
            @test immunity_is_stable(p, empty_state, ind, Int16(10))
            @test immunity_is_stable(p, nat_state(5), ind, Int16(10))
        end

        @testset "ExponentialWaning" begin
            # validation
            @test_throws ArgumentError ExponentialWaning(halflife=-1.0)
            @test_throws ArgumentError ExponentialWaning(floor=Int8(-1))
            @test_throws ArgumentError ExponentialWaning(floor=Int8(101))
            @test_throws ArgumentError ExponentialWaning(vaccine_buildup_duration=Int16(-1))

            p = ExponentialWaning(halflife=180.0)

            # at acquisition tick: full immunity
            @test calculate_immunity(p, nat_state(0), ind, Int16(0), rng) == Int8(100)

            # after one halflife: ~50
            @test calculate_immunity(p, nat_state(0), ind, Int16(180), rng) == Int8(50)

            # floor clamping
            p_floor = ExponentialWaning(halflife=1.0, floor=Int8(30))
            @test calculate_immunity(p_floor, nat_state(0), ind, Int16(1000), rng) >= Int8(30)

            # vaccine buildup: during buildup window immunity rises, not yet at peak
            p_buildup = ExponentialWaning(halflife=180.0, vaccine_buildup_duration=Int16(10))
            mid_buildup = calculate_immunity(p_buildup, vac_state(0), ind, Int16(5), rng)
            @test 0 < mid_buildup < 100
            @test !immunity_is_stable(p_buildup, vac_state(0), ind, Int16(5))

            # combined natural + vaccine: higher than either alone (independent barriers)
            nat_only = calculate_immunity(p, nat_state(0), ind, Int16(180), rng)
            both = calculate_immunity(p, both_state(0, 0), ind, Int16(180), rng)
            @test both > nat_only

            # stability: once waned to floor (level <= floor) the profile is stable
            p_stable = ExponentialWaning(halflife=0.5, floor=Int8(0))
            @test immunity_is_stable(p_stable, nat_state(0), ind, Int16(100))
        end

        @testset "SigmoidalWaning" begin
            # validation
            @test_throws ArgumentError SigmoidalWaning(halflife=-1.0)
            @test_throws ArgumentError SigmoidalWaning(hill=-1.0)
            @test_throws ArgumentError SigmoidalWaning(floor=Int8(-1))
            @test_throws ArgumentError SigmoidalWaning(vaccine_buildup_duration=Int16(-1))

            p = SigmoidalWaning(halflife=180.0, hill=3.0)

            # at acquisition: full immunity
            @test calculate_immunity(p, nat_state(0), ind, Int16(0), rng) == Int8(100)

            # at halflife: ~50
            @test calculate_immunity(p, nat_state(0), ind, Int16(180), rng) == Int8(50)

            # floor clamping
            p_floor = SigmoidalWaning(halflife=1.0, floor=Int8(20))
            @test calculate_immunity(p_floor, nat_state(0), ind, Int16(10000), rng) >= Int8(20)

            # combined sources: higher than single source
            single = calculate_immunity(p, nat_state(0), ind, Int16(180), rng)
            combined = calculate_immunity(p, both_state(0, 0), ind, Int16(180), rng)
            @test combined > single

            # vaccine buildup ramp for SigmoidalWaning
            p_sig_buildup = SigmoidalWaning(halflife=180.0, vaccine_buildup_duration=Int16(10))
            mid_buildup_sig = calculate_immunity(p_sig_buildup, vac_state(0), ind, Int16(5), rng)
            @test 0 < mid_buildup_sig < 100
            @test !immunity_is_stable(p_sig_buildup, vac_state(0), ind, Int16(5))

            # stability: once waned to floor the profile is stable
            p_sig_stable = SigmoidalWaning(halflife=0.5, floor=Int8(0))
            @test immunity_is_stable(p_sig_stable, nat_state(0), ind, Int16(100))
        end

    end


    ###
    ### InfectiousnessProfile
    ###
    @testset "InfectiousnessProfile" begin

        ind = Individual(id=1, sex=0, age=30)
        rng = Xoshiro()

        # helper: InfectionState from a DiseaseProgression
        mk_state(dp) = InfectionState(Int8(1), Int32(1), dp)

        @testset "ConstantInfectiousness" begin
            p = ConstantInfectiousness()
            @test p.level == Int8(100)

            p50 = ConstantInfectiousness(level=50)
            @test p50.level == Int8(50)

            state = mk_state(DiseaseProgression(
                exposure=Int16(1), infectiousness_onset=Int16(3), recovery=Int16(20)))

            # before onset: 0
            @test calculate_infectiousness(p, state, ind, Int16(2), rng) == Int8(0)

            # inside window: returns level
            @test calculate_infectiousness(p, state, ind, Int16(5), rng) == Int8(100)
            @test calculate_infectiousness(p50, state, ind, Int16(5), rng) == Int8(50)

            # at or after recovery: 0
            @test calculate_infectiousness(p, state, ind, Int16(20), rng) == Int8(0)
        end

        @testset "StagedInfectiousness" begin
            # validation: negative values rejected
            @test_throws ArgumentError StagedInfectiousness(asymptomatic=-1)

            p = StagedInfectiousness(asymptomatic=Int8(10), presymptomatic=Int8(30),
                                     symptomatic=Int8(70), severe=Int8(90), critical=Int8(100))

            # outside window: 0
            state_out = mk_state(DiseaseProgression(
                exposure=Int16(1), infectiousness_onset=Int16(3), recovery=Int16(20)))
            @test calculate_infectiousness(p, state_out, ind, Int16(2), rng) == Int8(0)
            @test calculate_infectiousness(p, state_out, ind, Int16(20), rng) == Int8(0)

            # asymptomatic: symptom_onset stays DEFAULT_TICK
            state_asymp = mk_state(DiseaseProgression(
                exposure=Int16(1), infectiousness_onset=Int16(3), recovery=Int16(20)))
            @test calculate_infectiousness(p, state_asymp, ind, Int16(5), rng) == Int8(10)

            # presymptomatic: past onset, before symptom_onset
            state_pre = mk_state(DiseaseProgression(
                exposure=Int16(1), infectiousness_onset=Int16(3),
                symptom_onset=Int16(10), recovery=Int16(20)))
            @test calculate_infectiousness(p, state_pre, ind, Int16(5), rng) == Int8(30)

            # symptomatic: past symptom_onset, not severe
            @test calculate_infectiousness(p, state_pre, ind, Int16(12), rng) == Int8(70)

            # severe: past severeness_onset, before offset
            state_sev = mk_state(DiseaseProgression(
                exposure=Int16(1), infectiousness_onset=Int16(3), symptom_onset=Int16(5),
                severeness_onset=Int16(8), severeness_offset=Int16(20), recovery=Int16(25)))
            @test calculate_infectiousness(p, state_sev, ind, Int16(10), rng) == Int8(90)

            # critical: in ICU window
            state_crit = mk_state(DiseaseProgression(
                exposure=Int16(1), infectiousness_onset=Int16(3), symptom_onset=Int16(5),
                severeness_onset=Int16(8), severeness_offset=Int16(25),
                hospital_admission=Int16(9), icu_admission=Int16(10), icu_discharge=Int16(20),
                hospital_discharge=Int16(25), recovery=Int16(30)))
            @test calculate_infectiousness(p, state_crit, ind, Int16(12), rng) == Int8(100)
        end

    end

end