@testset "Movie Renderer" begin

    @testset "steps" begin
        @test GEMS.steps(1, 0) ≈ [0.5]
        @test GEMS.steps(3, 0) ≈ [0.25, 0.5, 0.75]
        @test GEMS.steps(1, 5) ≈ [5.5]
        @test GEMS.steps(3, 5) ≈ [5.25, 5.5, 5.75]

        # length always equals n
        for n in [1, 5, 10]
            @test length(GEMS.steps(n, 0)) == n
        end

        # all values strictly within (base, base+1)
        for base in [0, 3, 10]
            @test all(x -> base < x < base + 1, GEMS.steps(5, base))
        end

        # values are strictly increasing
        @test issorted(GEMS.steps(10, 0))

        # values are evenly spaced
        s = GEMS.steps(4, 0)
        diffs = diff(s)
        @test all(d -> d ≈ diffs[1], diffs)
    end


    @testset "prepare_frame_data" begin

        # 3 geolocated rows, 1 without coords
        # infection 3: death > recovery to verify max.(r,d) takes death
        infections = DataFrame(
            infection_id = [1, 2, 3, 4],
            tick = Int16[1, 1, 2, 3],
            recovery = Int16[5, 6, 4, 8],
            death = Int16[0, 0, 9, 0],
            lat = [52.5, 51.0, 53.0, NaN],
            lon = [13.4, 12.0, 14.0, NaN]
        )

        result = GEMS.prepare_frame_data(infections, 1000)

        # output schema
        for col in [:tick, :removed_tick, :lat, :lon, :show, :start_time, :end_time]
            @test col in propertynames(result)
        end

        # removed_tick is max(recovery, death)
        # infection 3: death=9 > recovery=4, so removed_tick should be 9
        row3 = filter(row -> !isnan(row.lat) && row.lat == 53.0, result)[1, :]
        @test row3.removed_tick == 9

        # infection 1: recovery=5 > death=0
        row1 = filter(row -> !isnan(row.lat) && row.lat == 52.5, result)[1, :]
        @test row1.removed_tick == 5

        # row without geolocation is not show-eligible
        non_geo = filter(row -> isnan(row.lat), result)
        @test nrow(non_geo) == 1
        @test all(row -> row.show == false, eachrow(non_geo))

        # start_time lies strictly within (tick, tick+1)
        for row in eachrow(result)
            @test row.tick < row.start_time < row.tick + 1
        end

        # end_time lies strictly within (removed_tick, removed_tick+1)
        for row in eachrow(result)
            @test row.removed_tick < row.end_time < row.removed_tick + 1
        end

        # same-tick infections get distinct start_times
        same_tick = filter(row -> row.tick == 1, result)
        @test length(unique(same_tick.start_time)) == nrow(same_tick)

        # when max_points >= geolocated count, all geolocated rows are shown
        @test sum(result.show) == 3

        # subsampling caps the number of shown rows
        result_capped = GEMS.prepare_frame_data(infections, 2)
        @test sum(result_capped.show) == 2

        # non-geolocated rows are never shown regardless of cap
        non_geo_capped = filter(row -> isnan(row.lat), result_capped)
        @test all(row -> row.show == false, eachrow(non_geo_capped))

        # throws when no geolocated rows exist
        no_geo = DataFrame(
            infection_id = [1],
            tick = Int16[1],
            recovery = Int16[5],
            death = Int16[0],
            lat = [NaN],
            lon = [NaN]
        )
        @test_throws "The infections dataframe does not have any geolocated entries." GEMS.prepare_frame_data(no_geo, 1000)
    end


    @testset "crop_image" begin

        # use a matrix of known values so we can verify which rows were kept
        img = [i for i in 1:120, j in 1:100]  # 120 rows, 100 cols

        cropped = GEMS.crop_image(img)
        h, w = size(cropped)

        # height: new_h = 120 - mod(120,2) = 120, then rows GEMS.GMT_TOP_BORDER_CROP:120
        @test h == 120 - GEMS.GMT_TOP_BORDER_CROP + 1
        # width: 100 is already even
        @test w == 100
        # both dimensions are even
        @test mod(h, 2) == 0
        @test mod(w, 2) == 0

        # top GEMS.GMT_TOP_BORDER_CROP-1 rows are gone: first row of result is row GEMS.GMT_TOP_BORDER_CROP
        @test cropped[1, 1] == GEMS.GMT_TOP_BORDER_CROP

        # odd dimensions get rounded down before cropping
        img_odd = ones(Int, 121, 99)
        cropped_odd = GEMS.crop_image(img_odd)
        h2, w2 = size(cropped_odd)
        @test mod(h2, 2) == 0
        @test mod(w2, 2) == 0
        # new_h = 121 - 1 = 120, rows GEMS.GMT_TOP_BORDER_CROP:120
        @test h2 == 120 - GEMS.GMT_TOP_BORDER_CROP + 1
        @test w2 == 98
    end

end