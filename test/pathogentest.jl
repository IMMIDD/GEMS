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