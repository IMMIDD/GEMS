
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
    end

    @testset "Tick-Date Conversion" begin

        # test number of ticks between two dates
        @test ticks_between_dates(Date("2020-01-01"), Date("2023-01-01"), 'y') == 4 
        @test ticks_between_dates(Date("2020-01-01"), Date("2020-12-01"), 'm') == 12 
        @test ticks_between_dates(Date("2020-01-01"), Date("2020-02-05"), 'w') == 6  
        @test ticks_between_dates(Date("2020-01-01"), Date("2020-01-10"), 'd') == 10 
        @test ticks_between_dates(Date("2020-01-01"), Date("2020-01-02"), 'h') == 48 


        # test if date at tick equals corresponding date
        @test date_at_tick(Int16(5), Date("2024.1.1", dateformat"y.m.d"), 'y') == Date("2029.1.1", dateformat"y.m.d")
        @test date_at_tick(Int16(5), Date("2024.1.1", dateformat"y.m.d"), 'm') == Date("2024.6.1", dateformat"y.m.d")
        @test date_at_tick(Int16(5), Date("2024.1.1", dateformat"y.m.d"), 'w') == Date("2024.2.5", dateformat"y.m.d")
        @test date_at_tick(Int16(7), Date("2024.1.1", dateformat"y.m.d"), 'd') == Date("2024.1.8", dateformat"y.m.d")
        @test date_at_tick(Int16(168), Date("2024.1.1", dateformat"y.m.d"), 'h') == Date("2024.1.8", dateformat"y.m.d")

        # test date intervals
        # weekly interval
        ticks_w = select_interval_dates(Date("2025-01-01"), Date("2025-01-31"))
        @test length(ticks_w) == 5

        # monthly interval
        ticks_m = select_interval_dates(Date("2025-01-01"), Date("2025-12-31"))
        @test length(ticks_m) == 12
        @test all(day.(ticks_m) .== [day.(lastdayofmonth(t)) for t in ticks_m])

        #yearly interval
        ticks_y = select_interval_dates(Date("2025-01-01"), Date("2027-12-31"))
        @test length(ticks_y) == 3
        @test all(month.(ticks_y) .== 12) && all(day.(ticks_y) .== 31)
    end
end