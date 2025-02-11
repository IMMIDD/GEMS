@testset "Pathogens" begin

    p = Pathogen(   
            id = 1,
            name = "COVID",
            infection_rate = Uniform(0,1),
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
    
    # test getter & setter
    @test id(p) == 1
    @test name(p) == "COVID"
    @test infection_rate(p) == Uniform(0,1)
    @test mild_death_rate(p) == Uniform(0,0.005)
    @test severe_death_rate(p) == Uniform(0,0.1)
    @test critical_death_rate(p) == Uniform(0,0.1)
    
    @test hospitalization_rate(p) == Uniform(0, 0.1)
    @test ventilation_rate(p) == Uniform(0, 0.1)
    @test icu_rate(p) == Uniform(0, 0.1)
    
    @test onset_of_symptoms(p) == Uniform(2,3)
    @test onset_of_severeness(p) == Uniform(2,3)
    @test infectious_offset(p) == Uniform(0,1)
    @test time_to_hospitalization(p) == Uniform(1,4)
    @test time_to_icu(p) == Uniform(1,2)

    @test time_to_recovery(p) == Uniform(5,6)
    @test length_of_stay(p) == Uniform(6,7)

    @test typeof(disease_progression_strat(p)) == DiseaseProgressionStrat
end