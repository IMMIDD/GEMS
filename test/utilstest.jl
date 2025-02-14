
@testset "Utils" begin
    
    @testset verbose=true "Matrix Aggregation" begin
        matrix = [1 1 2 2 3 ; 1 1 2 2 3 ; 3 3 4 4 3; 3 3 4 4 3; 3 3 3 3 3]
        vector = [1, 1, 8, 5, 3]
        result_matrix = [4 8 6; 12 16 6; 6 6 3]
        result_vector = [2 13 3]

        matrix_dim = 5
        vector_size = 5

        # test correct calculation
        @test aggregate_matrix(matrix,2) == result_matrix

        # test correct calculation
        @test aggregate_matrix(vector,2) == transpose(result_vector)

        # test correct aggregation size
        @test length(aggregate_matrix(vector, 2, 2)) == 2

        @test size(aggregate_matrix(matrix, 2, 2)) == (2,2)
        @test size(aggregate_matrix(matrix, 2, 4)) == (3,3)

        # test aggregation_bound > interval_steps
        @test_throws ArgumentError aggregate_matrix(matrix,2,1)

        # test aggregation_bound is multiple of interval steps
        @test_throws ArgumentError aggregate_matrix(matrix,2,3)

        # test interval_steps > 1
        @test_throws ArgumentError aggregate_matrix(matrix,1,2)


        @test date_at_tick(Date("2024.1.1", dateformat"y.m.d"), 604800, 'S') == Date("2024.1.8", dateformat"y.m.d")

    end
end