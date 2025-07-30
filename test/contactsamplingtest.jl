@testset "Contact Sampling" begin
           
    # create testsets for each ContactSamplingMethod known in GEMS
    @testset "RandomSampling" begin

        # create RandomSampling Object (rs)
        rs = RandomSampling()

        # initial infectant
        i = Individual(id = 42, age = 21, sex = 0, household=1)

        # other individuals in the household
        indis = [Individual(id = j, age = 18, sex = 1, household=1) for j in 0:10]
        push!(indis, i)
        
        # create Household setting based on the individuals
        h = Household(id = 1, individuals = indis, contact_sampling_method = rs)

        # create empty setting
        empty_h = Household(id = 2, individuals = Vector{Individual}(), contact_sampling_method = rs)

        # for these tests we assume that "present_inds" is equal to the individuals in "h" (so every individual of "h" is "present")

        # RandomSampling should only sample 1 contact
        @test length(sample_contacts(rs, h, i, individuals(h), GEMS.DEFAULT_TICK)) == 1
        
        # all "ContactSamplingMethod"s should return vectors of individuals 
        @test typeof(sample_contacts(rs, h, i, individuals(h), GEMS.DEFAULT_TICK)) == Vector{Individual}

        # Sampling from a setting where no individual is present should result in an error
        @test_throws ArgumentError sample_contacts(rs, empty_h, i, individuals(empty_h), GEMS.DEFAULT_TICK)
    end

    @testset "AgeBasedContactSampling" begin
        m = hcat([[rand() for i = 1:10] for i = 1:10]...)
        m = m .* hcat([vec(1 ./ sum(m, dims=2)) for _ =1:10]...) # normalization of each row
        abcs_null = AgeBasedContactSampling(0.0, 10, ContactMatrix{Float64}(m, 10), Float64[])
        abcs1 = AgeBasedContactSampling(1.0, 10, ContactMatrix{Float64}(m, 10), Float64[])
        abcs2 = AgeBasedContactSampling(2.0, 10, ContactMatrix{Float64}(m, 10), Float64[])
        abcs3 = AgeBasedContactSampling(3.0, 10, ContactMatrix{Float64}(m, 10), Float64[])
        abcs100 = AgeBasedContactSampling(100.0, 10, ContactMatrix{Float64}(m, 10), Float64[])

        # initial infectant
        i = Individual(id = 1, age = floor(Int, rand(Uniform(1, 100))), sex = floor(Int, rand(Uniform(0, 2))), household=1)

        # other individuals in the household
        indis = [Individual(id = j, age = floor(Int, rand(Uniform(1, 100))), sex = floor(Int, rand(Uniform(0, 2))), household=1) for j in 2:10000]
        push!(indis, i)

        # create Household setting based on the individuals
        h1 = Household(id = 1, individuals = indis, contact_sampling_method = abcs1)
        h2 = Household(id = 2, individuals = indis, contact_sampling_method = abcs2)
        h3 = Household(id = 3, individuals = indis, contact_sampling_method = abcs3)
        h100 = Household(id = 4, individuals = indis, contact_sampling_method = abcs100)
        hnull = Household(id = 5, individuals = indis, contact_sampling_method = abcs_null)

        # Sampling from a setting where with expected contacts is zero returns no individuals
        @test length(sample_contacts(abcs_null, hnull, i, individuals(hnull), GEMS.DEFAULT_TICK)) == 0

        # AgeBasedContactSampling should return vectors of individuals 
        @test typeof(sample_contacts(abcs_null, hnull, i, individuals(hnull), GEMS.DEFAULT_TICK)) == Vector{Individual}

        # AgeBasedContactSampling should only sample with poisson distribution with mean value of contact parameter
        # here we arbitrarly test the mean for various contact parameters
        # expected count equal 1
        @test mean([length(sample_contacts(abcs1, h1, i, individuals(h1), GEMS.DEFAULT_TICK)) for _ = 1:1000]) < 2
        @test mean([length(sample_contacts(abcs1, h1, i, individuals(h1), GEMS.DEFAULT_TICK)) for _ = 1:1000]) > 0
        # expected count equal 2
        @test mean([length(sample_contacts(abcs2, h2, i, individuals(h2), GEMS.DEFAULT_TICK)) for _ = 1:1000]) < 3
        @test mean([length(sample_contacts(abcs2, h2, i, individuals(h2), GEMS.DEFAULT_TICK)) for _ = 1:1000]) > 1
        # expected count equal 3
        @test mean([length(sample_contacts(abcs3, h3, i, individuals(h3), GEMS.DEFAULT_TICK)) for _ = 1:1000]) < 4
        @test mean([length(sample_contacts(abcs3, h3, i, individuals(h3), GEMS.DEFAULT_TICK)) for _ = 1:1000]) > 2
        # expected count equal 100
        @test mean([length(sample_contacts(abcs100, h100, i, individuals(h100), GEMS.DEFAULT_TICK)) for _ = 1:1000]) < 101
        @test mean([length(sample_contacts(abcs100, h100, i, individuals(h100), GEMS.DEFAULT_TICK)) for _ = 1:1000]) > 99

        # create empty setting
        empty_h = Household(id = 2, individuals = Vector{Individual}(), contact_sampling_method = abcs1)

        # Sampling from a setting where no individual is present should result in an error
        @test_throws ArgumentError sample_contacts(abcs1, empty_h, i, individuals(empty_h), GEMS.DEFAULT_TICK)

    end
end
