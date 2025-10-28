@testset "naked rng calls" begin
    offending_lines = check_naked_rng_calls()
    @test isempty(offending_lines)
end
