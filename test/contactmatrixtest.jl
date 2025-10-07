@testset "Contact Matrices" begin
    
    @testset "Matrix creation" begin
        
        # create data matrix
        correct_data = [1 2 3; 4 5 6; 7 8 9]
        wrong_data = [1 2; 3 4; 5 6]

        # define parameters
        interval_steps = 10

        @test typeof(ContactMatrix{Int64}(correct_data, interval_steps)) == ContactMatrix{Int64}

        # wrong matrix dimension
        @test_throws ArgumentError ContactMatrix{Int64}(wrong_data, interval_steps)
    
        # wrong factor between interval_steps and aggregation_bound
        aggregation_bound = 5

        # aggregation bound is smaller than interval_steps
        @test_throws ArgumentError ContactMatrix{Int64}(correct_data, interval_steps, aggregation_bound)

        aggregation_bound = 12

        # aggregation bound isn't a multiple of interval_steps
        @test_throws ArgumentError ContactMatrix{Int64}(correct_data, interval_steps, aggregation_bound)

        interval_steps = -1

        # interval steps is < 1
        @test_throws ArgumentError ContactMatrix{Int64}(correct_data, interval_steps, aggregation_bound)

        aggregation_bound = -1

        # aggregation_bound is < 2
        @test_throws ArgumentError ContactMatrix{Int64}(correct_data, interval_steps, aggregation_bound)

        # test different combinations of interval_steps and aggregation_bound
        interval_steps = 5
        aggregation_bound = 15

        @test typeof(ContactMatrix{Int64}(correct_data, interval_steps, aggregation_bound)) == ContactMatrix{Int64}

        interval_steps = 3
        aggregation_bound = 3

        @test typeof(ContactMatrix{Int64}(correct_data, interval_steps, aggregation_bound)) == ContactMatrix{Int64}

        interval_steps = 5
        aggregation_bound = 20

        @test_throws ArgumentError ContactMatrix{Int64}(correct_data, interval_steps, aggregation_bound)
    end

    # @testset "Get Contacts" begin

    #     # create individual
    #     i = Individual(id = 1, sex = 0, age = 12, household = 1)

    #     correct_data = [1 2 3; 4 5 6; 7 8 9]

    #     age_group_10_till_20 = correct_data[:,2]

    #     contact_matrix = ContactMatrix{Int64}(correct_data, 10)

    #     @test get_contacts(contact_matrix, i) == mean(age_group_10_till_20)

    #     @test typeof(get_contacts(contact_matrix, i)) == Int64
    # end
end
