@testset "AgeContactDistribution" begin
    
    @testset "Create Struct" begin
        
        distribution_data::Vector{Int64} = [1,2,3,4,5,6,7,8,9]
        correct_ego_age::Int8 = Int8(5)
        correct_contact_age::Int8 = Int8(5)

        @test typeof(AgeContactDistribution(distribution_data, correct_ego_age, correct_contact_age)) == AgeContactDistribution

        wrong_ego_age::Int8 = Int8(-1)

        # age in a AgeContactDistribution must not be negative
        @test_throws ArgumentError AgeContactDistribution(distribution_data, wrong_ego_age, correct_contact_age)

        wrong_contact_age::Int8 = Int8(-1)

        # age in a AgeContactDistribution must not be negative
        @test_throws ArgumentError AgeContactDistribution(distribution_data, correct_ego_age, wrong_contact_age)

        wrong_distribution_data::Vector{Int64} = [1,1,3,3,-1,6,-7,8,8,9]

        @test_throws ArgumentError AgeContactDistribution(wrong_distribution_data, correct_ego_age, correct_contact_age)

    end

    # a "zero contact" is an individual that doesn't have a contact
    @testset "Calculate AgeContactDistribution without 'zero contacts'" begin
        
        #=
        12×3 DataFrame
        Row │ ego_id  ego_age  contact_age 
            │ Int64   Int64    Int64       
        ────┼──────────────────────────────
        1   │      1        5            4
        2   │      1        5            4
        3   │      1        5           11
        4   │      2       10           22
        5   │      2       10            6
        6   │      3        4            5
        7   │      3        4            2
        8   │      3        4           13
        9   │      3        4           13
        10  │      4       18           20
        11  │      5       22           18
        12  │      5       22           17
        =#
        test_contact_data = DataFrame(ego_id = [1,1,1,2,2,3,3,3,3,4,5,5], ego_age = [5,5,5,10,10,4,4,4,4,18,22,22], contact_age = [4,4,11,22,6,5,2,13,13,20,18,17])

        distribution1 = GEMS.calculate_age_contact_distribution(test_contact_data; ego_age=5, contact_age=4, ego_id_column=1, ego_age_column=2, contact_age_column=3)

        # only two "contacts" of age "4" exist
        @test distribution1 == [2]
        # only one "ego" of age "5" exists
        @test length(distribution1) == 1
        # frequencies are always integer values
        @test typeof(distribution1) == Vector{Int}

        # test if the function can successfully return a AgeContactDistribution type (check for any error in method execution)
        @test typeof(get_age_contact_distribution(test_contact_data; ego_age=5, contact_age=4, ego_id_column=1, ego_age_column=2, contact_age_column=3)) == AgeContactDistribution

        # the test contact data has no entries of "egos" who doesn't have any contacts
        @test isempty(GEMS.get_zero_contact_distribution(contactdata=test_contact_data, ego_age=5, ego_id_column=1, ego_age_column=2, contact_age_column=3))

        #=
        12×3 DataFrame
        Row │ ego_id  ego_age  contact_age 
            │ Int64   Int64    Int64       
        ────┼──────────────────────────────
        1   │      1        5            4
        2   │      1       -5            4
        3   │      1        5           11
        4   │      2       10           22
        5   │      2       10            6
        6   │      3        4            5
        7   │      3        4            2
        8   │      3        4           13
        9   │      3        4           13
        10  │      4       18           20
        11  │      5       22           18
        12  │      5       22           17
        =# 
        wrong_test_contact_data = DataFrame(ego_id = [1,1,1,2,2,3,3,3,3,4,5,5], ego_age = [5,-5,5,10,10,4,4,4,4,18,22,22], contact_age = [4,4,11,22,6,5,2,13,13,20,18,17])
        
        distribution2 = GEMS.calculate_age_contact_distribution(wrong_test_contact_data; ego_age=5, contact_age=4, ego_id_column=1, ego_age_column=2, contact_age_column=3)

        # only one "contacts" of age "4" exist (one entry for "ego 1 (ego_id=1)" is invalid (negative age))
        @test distribution2 == [1]
        # only one "ego" of age "5" exists
        @test length(distribution2) == 1
        # frequencies are always integer values
        @test typeof(distribution2) == Vector{Int}
    end

    # a "zero contact" is an individual that doesn't have a contact
    @testset "Calculate AgeContactDistribution with 'zero contacts'" begin
        
        #=
        13×3 DataFrame
        Row │ ego_id  ego_age  contact_age 
            │ Int64   Int64    Int64       
        ────┼──────────────────────────────
        1   │      1       18            1
        2   │      1       18           11
        3   │      1       18           11
        4   │      2       10           22
        5   │      2       10            6
        6   │      3        4            5
        7   │      3        4            2
        8   │      3        4           13
        9   │      3        4           13
        10  │      4       18           -1
        11  │      5       22           18
        12  │      5       22           17
        13  │      6       18           -1
        =#
        test_contact_data_with_zero_contacts = DataFrame(ego_id = [1,1,1,2,2,3,3,3,3,4,5,5,6], ego_age = [18,18,18,10,10,4,4,4,4,18,22,22,18], contact_age = [1,11,11,22,6,5,2,13,13,-1,18,17,-1])

        distribution_with_zero_contacts = GEMS.get_zero_contact_distribution(test_contact_data_with_zero_contacts; ego_age=18, ego_id_column=1, ego_age_column=2, contact_age_column=3)

        # only 2 "egos" of age "18" don't have contacts
        @test length(distribution_with_zero_contacts) == 2
    end

    @testset "Plotting" begin

        #=
        12×3 DataFrame
        Row │ ego_id  ego_age  contact_age 
            │ Int64   Int64    Int64       
        ────┼──────────────────────────────
        1   │      1        5            4
        2   │      1        5            4
        3   │      1        5           11
        4   │      2       10           22
        5   │      2       10            6
        6   │      3        4            5
        7   │      3        4            2
        8   │      3        4           13
        9   │      3        4           13
        10  │      4       18           20
        11  │      5       22           18
        12  │      5       22           17
        =#
        test_contact_data = DataFrame(ego_id = [1,1,1,2,2,3,3,3,3,4,5,5], ego_age = [5,5,5,10,10,4,4,4,4,18,22,22], contact_age = [4,4,11,22,6,5,2,13,13,20,18,17])

        age_contact_distribution = get_age_contact_distribution(test_contact_data; ego_age=5, contact_age=4, ego_id_column=1, ego_age_column=2, contact_age_column=3)

        # test if the function can be called without throwing any error
        @test try 
                plot_age_contact_distribution(age_contact_distribution)
                true
            catch
                false
            end

    end

end

@testset "AgeGroupContactDistribution" begin
    
    @testset "Create Struct" begin
        
        distribution_data::Vector{Int64} = [1,2,3,4,5,6,7,8,9]
        correct_ego_age_group::Tuple{Int8, Int8} = (0,5)
        correct_contact_age_group::Tuple{Int8, Int8} = (0,5)

        @test typeof(AgeGroupContactDistribution(distribution_data, correct_ego_age_group, correct_contact_age_group)) == AgeGroupContactDistribution

        # one age is negative
        wrong_ego_age_group::Tuple{Int8, Int8} = (-1,5)

        @test_throws ArgumentError AgeGroupContactDistribution(distribution_data, wrong_ego_age_group, correct_contact_age_group)

        # 'lower bound' is greater than 'upper bound'
        wrong_ego_age_group = (10,5)

        @test_throws ArgumentError AgeGroupContactDistribution(distribution_data, wrong_ego_age_group, correct_contact_age_group)

        # one age is negative
        wrong_contact_age_group::Tuple{Int8, Int8} = (-2,5)

        @test_throws ArgumentError AgeGroupContactDistribution(distribution_data, correct_ego_age_group, wrong_contact_age_group)

        # 'lower bound' is greater than 'upper bound'
        wrong_contact_age_group = (10,5)

        @test_throws ArgumentError AgeGroupContactDistribution(distribution_data, correct_ego_age_group, wrong_contact_age_group)

        wrong_distribution_data::Vector{Int64} = [1,1,3,3,-1,6,-7,8,8,9]

        @test_throws ArgumentError AgeGroupContactDistribution(wrong_distribution_data, correct_ego_age_group, correct_contact_age_group)

    end

    # a "zero contact" is an individual that doesn't have a contact
    @testset "Calculate AgeGroupContactDistribution without 'zero contacts'" begin

        #=
        14×3 DataFrame
        Row │ ego_id  ego_age  contact_age 
            │ Int64   Int64    Int64       
        ────┼──────────────────────────────
        1   │      6        1            2
        2   │      1        2            0
        3   │      1        2            2
        4   │      2        2            2
        5   │      2        2            4
        6   │      8        2            2
        7   │     10        3            1
        8   │      3        4            3
        9   │      3        4            5
        10  │      9        4            2
        11  │      7        7            3
        12  │      4        8            5
        13  │      5        9            1
        14  │      5        9            1
        =#
        test_contact_data = DataFrame(ego_id = [1,1,2,2,3,3,4,5,5,6,7,8,9,10], ego_age = [2,2,2,2,4,4,8,9,9,1,7,2,4,3], contact_age = [0,2,2,4,3,5,5,1,1,2,3,2,2,1]) |> x -> sort!(x, [:ego_age])

        age_group_contact_distribution = get_ageGroup_contact_distribution(test_contact_data; ego_age_group=(0,5), contact_age_group=(0,5), ego_id_column=1, ego_age_column=2, contact_age_column=3).distribution_data

        # two individuals have two contacts in [0,5) (id=1 and id=2). Every other ego in age group [0,5) only has 1 contact
        @test age_group_contact_distribution == [2,2,1,1,1,1,1]
    
        # only 7 unique "egos" are in age group [0,5)
        @test length(age_group_contact_distribution) == 7

        # frequencies are always integer values
        @test typeof(age_group_contact_distribution) == Vector{Int}
    end

    @testset "Plotting" begin

        #=
        14×3 DataFrame
        Row │ ego_id  ego_age  contact_age 
            │ Int64   Int64    Int64       
        ────┼──────────────────────────────
        1   │      6        1            2
        2   │      1        2            0
        3   │      1        2            2
        4   │      2        2            2
        5   │      2        2            4
        6   │      8        2            2
        7   │     10        3            1
        8   │      3        4            3
        9   │      3        4            5
        10  │      9        4            2
        11  │      7        7            3
        12  │      4        8            5
        13  │      5        9            1
        14  │      5        9            1
        =#
        test_contact_data = DataFrame(ego_id = [1,1,2,2,3,3,4,5,5,6,7,8,9,10], ego_age = [2,2,2,2,4,4,8,9,9,1,7,2,4,3], contact_age = [0,2,2,4,3,5,5,1,1,2,3,2,2,1]) |> x -> sort!(x, [:ego_age])

        age_group_contact_distribution = get_ageGroup_contact_distribution(test_contact_data; ego_age_group=(0,5), contact_age_group=(0,5), ego_id_column=1, ego_age_column=2, contact_age_column=3)

        # test if the function can be called without throwing any error
        @test try 
                plot_ageGroup_contact_distribution(age_group_contact_distribution)
                true
            catch
                false
            end

    end
end