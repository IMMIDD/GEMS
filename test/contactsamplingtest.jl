@testset "Contact Sampling" begin
           
    # create testsets for each ContactSamplingMethod known in GEMS
    @testset "RandomSampling" begin

        # create RandomSampling Object (rs)
        rs = RandomSampling()

        # initial infectant
        i = Individual(id = 42, age = 21, sex = 0, household=1)

        # other individuals in the household
        indis = [Individual(id = j, age = 18, sex = 1, household=1) for j in 0:10]
        i_index = 6
        insert!(indis, i_index, i)
        
        # create Household setting based on the individuals
        h = Household(id = 1, individuals = indis, contact_sampling_method = rs)

        # create empty setting
        empty_h = Household(id = 2, individuals = Vector{Individual}(), contact_sampling_method = rs)

        # for these tests we assume that "present_inds" is equal to the individuals in "h" (so every individual of "h" is "present")

        # RandomSampling should only sample 1 contact
        @test length(sample_contacts(rs, h, i_index, individuals(h), GEMS.DEFAULT_TICK)) == 1
        
        # all "ContactSamplingMethod"s should return vectors of individuals 
        @test typeof(sample_contacts(rs, h, i_index, individuals(h), GEMS.DEFAULT_TICK)) == Vector{Individual}

        # Sampling from a setting where no individual is present should result in an error
        @test_throws ArgumentError sample_contacts(rs, empty_h, i_index, individuals(empty_h), GEMS.DEFAULT_TICK)
    end

    @testset "ContactParameterSampling" begin

        # create ContactparameterSampling Object
        cps = ContactparameterSampling(2)

        # initial infectant
        i = Individual(id = 42, age = 21, sex = 0, household=1)

        # other individuals in the household
        indis = [Individual(id = j, age = 18, sex = 1, household=1) for j in 0:10]
        i_index = 6
        insert!(indis, i_index, i)
        
        # create Household setting based on the individuals
        h = Household(id = 1, individuals = indis, contact_sampling_method = cps)

        # create empty setting
        empty_h = Household(id = 2, individuals = Vector{Individual}(), contact_sampling_method = cps)

        # for these tests we assume that "present_inds" is equal to the individuals in "h" (so every individual of "h" is "present")
        
        # all "ContactSamplingMethod"s should return vectors of individuals 
        @test typeof(sample_contacts(cps, h, i_index, individuals(h), GEMS.DEFAULT_TICK)) == Vector{Individual}

        # Sampling from a setting where no individual is present should result in an error
        @test_throws ArgumentError sample_contacts(cps, empty_h, i_index, individuals(empty_h), GEMS.DEFAULT_TICK)

        # Test that sample_contacts avoids self-sampling the input individual
        for _ in 1:10
            contacts = sample_contacts(cps, h, i_index, individuals(h), GEMS.DEFAULT_TICK)
            @test all(contact.id != i.id for contact in contacts)
        end

        # Test that sample_contacts with replace=false avoids self-sampling and produces unique contacts
        for _ in 1:10
            contacts = sample_contacts(cps, h, i_index, individuals(h), GEMS.DEFAULT_TICK, replace=false)
            @test all(contact.id != i.id for contact in contacts)
            @test length(unique([contact.id for contact in contacts])) == length(contacts)
        end
    end
end
