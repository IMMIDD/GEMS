@testset "Vaccines" begin

    dw = DiscreteWaning(7,30)
    v = Vaccine(id=1, name="Antitest", waning=dw)

    @testset "Getter" begin
        @test id(v) == 1
        @test name(v) == "Antitest"
        @test waning(v) == dw
        @test typeof(logger(v)) == VaccinationLogger
        @test length(logger(v).id) == 0
    end

    @testset "Vaccinate Individuals" begin
        i = Individual(id = 1, sex = 0, age = 31, household=1)

        @test number_of_vaccinations(i) == 0
        @test !isvaccinated(i)
        vaccinate!(i, v, Int16(42))
        @test isvaccinated(i)
        @test vaccine_id(i) == 1
        @test vaccination_tick(i) == Int16(42)
        @test number_of_vaccinations(i) == 1
    end

end
