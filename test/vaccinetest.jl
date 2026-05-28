@testset "Vaccines" begin

    v = Vaccine(id=1, name="Antitest")

    @testset "Getter" begin
        @test id(v) == 1
        @test name(v) == "Antitest"
        @test typeof(logger(v)) == VaccinationLogger
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
