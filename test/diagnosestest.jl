@testset "Diagnoses" begin

    @testset "ErrorMatrix" begin

        @testset "In Simulation" begin
            #TODO: This can first be done, if we have a way to verify that the calculated error matrix (and therefore the weighted error sum) is correct

            #=
            
            # tests for "weighted_error_sum" 

            # load reference matrix
            reference_matrix = load("./testdata/ErrorMatrixTestdata.rds")

            # create test simulation
            sim = test_sim()

            post_processor = postProcessor(sim)

            # define interval steps and aggregation bound for aggregation
            interval_steps = 10
            aggregation_bound = 70

            =#
        end
        
        @testset "Isolated Testing" begin


        end


    end
    
   

end