@testset "Utils" begin

    @testset verbose = true "Matrix Aggregation" begin
        matrix = [1 1 2 2 3; 1 1 2 2 3; 3 3 4 4 3; 3 3 4 4 3; 3 3 3 3 3]
        vector = [1, 1, 8, 5, 3]
        result_matrix = [4 8 6; 12 16 6; 6 6 3]
        result_vector = [2 13 3]

        matrix_dim = 5
        vector_size = 5

        # test correct calculation
        @test aggregate_matrix(matrix, 2) == result_matrix

        # test correct calculation
        @test aggregate_matrix(vector, 2) == transpose(result_vector)

        # test correct aggregation size
        @test length(aggregate_matrix(vector, 2, 2)) == 2

        @test size(aggregate_matrix(matrix, 2, 2)) == (2, 2)
        @test size(aggregate_matrix(matrix, 2, 4)) == (3, 3)

        # test aggregation_bound > interval_steps
        @test_throws ArgumentError aggregate_matrix(matrix, 2, 1)

        # test aggregation_bound is multiple of interval steps
        @test_throws ArgumentError aggregate_matrix(matrix, 2, 3)

        # test interval_steps > 1
        @test_throws ArgumentError aggregate_matrix(matrix, 1, 2)

        non_square = [1 2 3; 4 5 6]
        vector2 = [1, 2, 3, 4, 5]

        # non-square matrix (2-arg and 3-arg overloads)
        @test_throws ArgumentError aggregate_matrix(non_square, 2)
        @test_throws ArgumentError aggregate_matrix(non_square, 2, 2)

        # interval_steps <= 1 (all overloads)
        @test_throws ArgumentError aggregate_matrix(matrix, 1)
        @test_throws ArgumentError aggregate_matrix(vector2, 1)
        @test_throws ArgumentError aggregate_matrix(matrix, 1, 2)
        @test_throws ArgumentError aggregate_matrix(vector2, 1, 2)

        # aggregation_bound <= 1 (3-arg overloads)
        @test_throws ArgumentError aggregate_matrix(matrix, 2, 1)
        @test_throws ArgumentError aggregate_matrix(vector2, 2, 1)

        # aggregation_bound < interval_steps (3-arg overloads)
        @test_throws ArgumentError aggregate_matrix(matrix, 3, 2)
        @test_throws ArgumentError aggregate_matrix(vector2, 3, 2)

        # aggregation_bound not a multiple of interval_steps (3-arg overloads)
        @test_throws ArgumentError aggregate_matrix(matrix, 2, 3)
        @test_throws ArgumentError aggregate_matrix(vector2, 2, 3)

    end

    @testset "isdate tests" begin
        @test isdate("2024-01-01") == true
        @test isdate("not-a-date") == false
    end

    @testset "foldercount tests" begin
        mktempdir() do tmpdir
            # Leeres Verzeichnis
            @test foldercount(tmpdir) == 0

            # Füge eine Datei hinzu
            touch(joinpath(tmpdir, "file.txt"))
            @test foldercount(tmpdir) == 0

            # Füge einen Unterordner hinzu
            mkdir(joinpath(tmpdir, "subfolder1"))
            @test foldercount(tmpdir) == 1

            # Noch ein Unterordner
            mkdir(joinpath(tmpdir, "subfolder2"))
            @test foldercount(tmpdir) == 2
        end
    end
    @testset "basefolder test" begin
        path = GEMS.basefolder()
        @test isdir(path)  # Es sollte ein existierendes Verzeichnis sein
    end
    @testset "identical tests" begin
        # Primitive Types
        @test identical(5, 5) == true
        @test identical(5, 6) == false
        @test identical("hi", "hi") == true
        @test identical("hi", "ho") == false

        # Structs mit Feldern
        struct TestStruct
            x::Int
            y::String
        end

        a = TestStruct(1, "test")
        b = TestStruct(1, "test")
        c = TestStruct(2, "fail")
        @test identical(a, b) == true
        @test identical(a, c) == false

        # Verschiedene Typen
        @test identical(5, "5") == false
    end

    @testset "bad_unique tests" begin
        #= Mit Structs TODO: fix
        struct Thing
            id::Int
        end
        v = [Thing(1), Thing(1), Thing(2)]
        bad_unique(v)
        @test length(v) == 2
        @test v[1] == Thing(1)
        @test v[2] == Thing(2)
=#
        # length 1: returns immediately, vector unchanged
        v = [42]
        bad_unique(v)
        @test v == [42]

        # length > 1: duplicate removed, unique values preserved
        v = [1, 1, 2]
        bad_unique(v)
        @test length(v) == 2
        @test 1 in v
        @test 2 in v

        # length > 1: no duplicates, vector unchanged
        v = [1, 2, 3]
        bad_unique(v)
        @test v == [1, 2, 3]
    end

    @testset "find_subtype" begin
        @test GEMS.find_subtype("Household", Setting) == Household
        @test_throws ArgumentError GEMS.find_subtype("NonExistentType", Setting)
    end

    @testset "concrete_subtypes" begin
        # abstract type with no subtypes returns empty vector
        abstract type _EmptyAbstract end
        @test concrete_subtypes(_EmptyAbstract) == DataType[]
    end

    @testset "is_existing_subtype" begin
        @test GEMS.is_existing_subtype("Household", Setting) == true
        @test GEMS.is_existing_subtype("NonExistentType", Setting) == false
        # concrete_subtypes may return "GEMS.Household" - should still match on last segment
        @test GEMS.is_existing_subtype("Household", IndividualSetting) == true
    end

    @testset "county_data" begin
        df = county_data()
        @test df isa DataFrame
        @test :ags in propertynames(df)
        @test :gen in propertynames(df)
        @test nrow(df) > 0
        @test eltype(df.ags) == AGS
        @test eltype(df.gen) == String
    end

    @testset "municipality_data" begin
        df = municipality_data()
        @test df isa DataFrame
        @test :ags in propertynames(df)
        @test :gen in propertynames(df)
        @test nrow(df) > 0
        @test eltype(df.ags) == AGS
        @test eltype(df.gen) == String
    end

    @testset "state_data" begin
        df = state_data()
        @test df isa DataFrame
        @test :ags in propertynames(df)
        @test :gen in propertynames(df)
        @test nrow(df) > 0
        @test eltype(df.ags) == AGS
        @test eltype(df.gen) == String
    end

    @testset "get_missing_docs test" begin
        missing = get_missing_docs()
        @test missing isa Vector{Symbol}  # Es sollte ein Symbol-Vektor sein
    end

    @testset "aggregate_dicts" begin
        # empty input
        @test aggregate_dicts(Vector{Dict}()) == Dict()

        # single dict
        d1 = Dict("a" => 1.0, "b" => 2.0)
        result = aggregate_dicts([d1])
        @test haskey(result, "a")
        @test haskey(result, "b")
        @test result["a"]["mean"] == 1.0
        @test result["b"]["mean"] == 2.0

        # multiple dicts
        d2 = Dict("a" => 3.0, "b" => 4.0)
        result2 = aggregate_dicts([d1, d2])
        @test result2["a"]["mean"] == 2.0
        @test result2["b"]["mean"] == 3.0
        @test result2["a"]["min"] == 1.0
        @test result2["a"]["max"] == 3.0
    end

    @testset "aggregate_dfs_multcol" begin
        df1 = DataFrame(id = [1, 2], a = [1.0, 2.0])
        df2 = DataFrame(id = [1, 2], b = [3.0, 4.0])

        # mismatched columns
        @test_throws ArgumentError aggregate_dfs_multcol([df1, df2], :id)

        # empty dataframes
        df_empty = DataFrame()
        @test_throws ArgumentError aggregate_dfs_multcol([df_empty, df_empty], :id)

        # key column missing
        df3 = DataFrame(a = [1.0], b = [2.0])
        df4 = DataFrame(a = [3.0], b = [4.0])
        @test_throws ArgumentError aggregate_dfs_multcol([df3, df4], :id)

        # happy path: two runs with identical columns, single key
        run1 = DataFrame(id = [1, 2], val = [10.0, 20.0])
        run2 = DataFrame(id = [1, 2], val = [20.0, 40.0])
        result = aggregate_dfs_multcol([run1, run2], :id)
        @test haskey(result, "val")
        @test result["val"][result["val"].id .== 1, "mean"][1] == 15.0
        @test result["val"][result["val"].id .== 1, "minimum"][1] == 10.0
        @test result["val"][result["val"].id .== 1, "maximum"][1] == 20.0
    end

    @testset "aggregate_dfs (multi-key)" begin
        # each run has a compound key (group, tick) plus one value column
        run1 = DataFrame(group = [1, 1], tick = [1, 2], val = [1.0, 2.0])
        run2 = DataFrame(group = [1, 1], tick = [1, 2], val = [3.0, 4.0])
        run3 = DataFrame(group = [1, 1], tick = [1, 2], val = [5.0, 6.0])
        result = aggregate_dfs([run1, run2, run3], [:group, :tick])
        @test result isa DataFrame
        @test "mean" in names(result)
        @test "minimum" in names(result)
        @test "maximum" in names(result)
        # row for (group=1, tick=1): values are 1, 3, 5 → mean 3
        r = result[result.group .== 1 .&& result.tick .== 1, :]
        @test r[1, :mean] ≈ 3.0
        @test r[1, :minimum] ≈ 1.0
        @test r[1, :maximum] ≈ 5.0
    end

    @testset "aggregate_dfs_multcol (multi-key)" begin
        run1 = DataFrame(pid = [1, 2], tick = [1, 1], val = [10.0, 20.0])
        run2 = DataFrame(pid = [1, 2], tick = [1, 1], val = [30.0, 40.0])
        result = aggregate_dfs_multcol([run1, run2], [:pid, :tick])
        @test haskey(result, "val")
        @test result["val"] isa DataFrame
        @test "mean" in names(result["val"])
        r1 = result["val"][result["val"].pid .== 1, :]
        @test r1[1, :mean] ≈ 20.0
    end

    @testset "aggregate_by_pathogen" begin
        # empty input returns empty dict
        @test aggregate_by_pathogen(DataFrame[], :attack_rate) == Dict{Int8, Dict{String, Real}}()

        # two runs with two pathogens each
        run1 = DataFrame(pathogen_id = Int8[1, 2], attack_rate = [0.2, 0.4])
        run2 = DataFrame(pathogen_id = Int8[1, 2], attack_rate = [0.4, 0.6])
        result = aggregate_by_pathogen([run1, run2], :attack_rate)
        @test haskey(result, Int8(1))
        @test haskey(result, Int8(2))
        @test result[Int8(1)]["mean"] ≈ 0.3
        @test result[Int8(1)]["min"]  ≈ 0.2
        @test result[Int8(1)]["max"]  ≈ 0.4
        @test result[Int8(2)]["mean"] ≈ 0.5
    end

    @testset "parameters" begin
        d = Normal(2.0, 0.5)
        p = parameters(d)
        @test p["distribution"] == string(d)
        @test isapprox(p["mean"], 2.0, atol = 1e-10)
        @test isapprox(p["std"], 0.5, atol = 1e-10)

        d2 = Uniform(0.0, 1.0)
        p2 = parameters(d2)
        @test isapprox(p2["mean"], 0.5, atol = 1e-10)
        @test isapprox(p2["std"], 1/sqrt(12), atol = 1e-10)
    end

    @testset "calculate_absolute_error" begin
        m1 = [2 2; 2 2]
        m2 = [3 1; 4 2]

        expected = [1 1; 2 0]
        result = calculate_absolute_error(m1, m2)

        @test result == expected
    end
    @testset "find_alpha" begin
        om = [1.0 2.0; 3.0 4.0]
        pm = [0.5 1.0; 1.5 2.0]
        alpha = GEMS.find_alpha(om, pm)
        @test isapprox(alpha, 2.0, atol=1e-10)

        om2 = [1 2]
        pm2 = [1 2; 3 4]
        @test_throws ArgumentError GEMS.find_alpha(om2, pm2)
    end

    @testset "gemscolors" begin
        @test isempty(gemscolors(0))
        @test isempty(gemscolors(-1))

        @test length(gemscolors(1)) == 1
        @test length(gemscolors(2)) == 2

        for l in 3:9
            @test length(gemscolors(l)) == l
        end

        @test length(gemscolors(10)) == 10
        @test length(gemscolors(15)) == 15
    end

    @testset "Base.show methods" begin
        inds = [
            Individual(age=42, id=1, sex=0),
            Individual(age=21, id=2, sex=1),
            Individual(age=1, id=3, sex=1)
        ]

        io = IOBuffer()
        @test (show(io, inds[1]); !isempty(String(take!(io))))

        io = IOBuffer()
        @test (show(io, MIME("text/plain"), inds); !isempty(String(take!(io))))
    end


    @testset "Typing System" begin

        # not exported but important to test
        @test GEMS.structname("GEMS.Household") == "Household"
        @test GEMS.structname(GEMS.Household) == "Household"

        plt_types = convert.(DataType, subtypes(SimulationPlot))
        test_plt = plt_types[1]

        @test GEMS.type_in_collection(string(test_plt), plt_types)
        @test GEMS.type_in_collection("GEMS.$test_plt", plt_types)
        @test GEMS.type_in_collection("Other.$test_plt", plt_types)
        @test GEMS.type_in_collection(test_plt, plt_types)
        @test GEMS.type_in_collection(string(test_plt), string.(plt_types))
        @test GEMS.type_in_collection(test_plt, string.(plt_types))
        @test GEMS.type_in_collection(test_plt, (x -> "GEMS.$x").(plt_types))
              
        # transmission functions
        tfs = transmission_functions()
        @test all(x -> isa(x, DataType) && x <: TransmissionFunction, tfs)

    end

    @testset "WelfordState" begin
        # initial state
        s = WelfordState()
        @test s.n == 0
        @test s.min == Inf
        @test s.max == -Inf

        # accumulate known values and verify against Statistics
        vals = [3.0, 7.0, 1.0, 9.0, 5.0]
        for v in vals
            welford_update!(s, v)
        end
        @test s.n == 5
        @test s.mean ≈ mean(vals)
        @test s.min == 1.0
        @test s.max == 9.0

        # welford_to_aggregate keys and correctness
        agg = welford_to_aggregate(s)
        @test Set(keys(agg)) == Set(["mean", "std", "min", "max", "lower_95", "upper_95"])
        @test agg["mean"] ≈ mean(vals)
        @test agg["std"] ≈ std(vals) atol = 1e-10
        @test agg["min"] == 1.0
        @test agg["max"] == 9.0
        @test agg["lower_95"] < agg["mean"] < agg["upper_95"]

        # welford_df_to_stats_df schema and values
        accum = Dict{Int, WelfordState}()
        for (tick, v) in [(1, 10.0), (1, 20.0), (2, 5.0), (2, 15.0)]
            welford_update!(get!(accum, tick, WelfordState()), v)
        end
        df = welford_df_to_stats_df(accum, :tick)
        @test "tick" in names(df)
        @test "mean" in names(df)
        @test "minimum" in names(df)
        @test "lower_95" in names(df)
        @test nrow(df) == 2
        @test df[df.tick .== 1, "mean"][1] ≈ 15.0
        @test df[df.tick .== 2, "mean"][1] ≈ 10.0

        # welford_df_to_stats_df_multicol returns one df per column
        accum_multi = Dict{String, Dict{Int, WelfordState}}()
        for col in ["a", "b"]
            accum_multi[col] = Dict{Int, WelfordState}()
            welford_update!(get!(accum_multi[col], 1, WelfordState()), col == "a" ? 2.0 : 8.0)
        end
        dfs = welford_df_to_stats_df_multicol(accum_multi, :tick)
        @test Set(keys(dfs)) == Set(["a", "b"])
        @test dfs["a"][1, "mean"] ≈ 2.0
        @test dfs["b"][1, "mean"] ≈ 8.0
    end
end
