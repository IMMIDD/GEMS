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
    paf = RandomProgressionAssignment([Asymptomatic, Symptomatic, Hospitalized, Critical])

    # transmission function
    ctf = ConstantTransmissionRate(transmission_rate = 0.25)

    @testset "General" begin
        # passing
        p = Pathogen(
            name = "TestPathogen",
            id = 5,
            progressions = [pr_asymp, pr_sympt, pr_hosp, pr_crit],
            progression_assignment = paf,
            transmission_function = ctf,
        )
        @test name(p) == "TestPathogen"
        @test id(p) == 5
        @test length(progressions(p)) == 4
        @test progressions(p)[Asymptomatic] === pr_asymp
        @test progressions(p)[Symptomatic] === pr_sympt
        @test progressions(p)[Hospitalized] === pr_hosp
        @test progressions(p)[Critical] === pr_crit
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
        function GEMS.calculate_progression(individual::Individual, tick::Int16, dp::TestProgression;
                rng::AbstractRNG = Random.default_rng())
            
            # Calculate the time to infectiousness
            infectiousness_onset = tick + Int16(1) + rand_val(dp.exposure_to_infectiousness_onset, rng)

            # Calculate the time to symptom onset
            symptom_onset = infectiousness_onset + rand_val(dp.infectiousness_onset_to_symptom_onset, rng)

            # Calculate the time to recovery
            recovery = symptom_onset + rand_val(dp.symptom_onset_to_recovery, rng)

            return DiseaseProgression(
                exposure = tick,
                infectiousness_onset = infectiousness_onset,
                symptom_onset = symptom_onset,
                recovery = recovery
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
        @test progressions(p_custom)[TestProgression] === tp
        @test tp.custom_parameter == 0.75

        sim = Simulation(pop_size = 1000, pathogen = p_custom, infected_fraction = 0.1)
        run!(sim)
        infectionlogger(sim).progression_category

        # check if all infections used the custom progression category in simulation
        @test all(pc -> pc == :TestProgression, infectionlogger(sim).progression_category)
        @test length(infectionlogger(sim).progression_category) > 0 # just to verify that there were infections

    end

    @testset "Progression Assignment" begin
        # random progression
        pgrs = [Asymptomatic, Symptomatic, Hospitalized, Critical]
        rpa = RandomProgressionAssignment(pgrs) 
        i = individuals(sim)[1]

        res = GEMS.assign(i, sim, rpa)
        @test res in pgrs

        # age-based progression

        
    end

    @testset "Transmission Function" begin

    end

    @testset "Disease Progression" begin
    
    
    end
end