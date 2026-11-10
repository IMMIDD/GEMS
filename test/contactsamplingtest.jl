# samplers for the `sample_contacts!` fallback, which built-in ones never reach because they
# define the positional method. Each defines one of the shapes the fallback probes for.

# mutating keyword method
struct KwMutatingSampler <: ContactSamplingMethod end

function GEMS.sample_contacts!(indivs::Vector{Individual}, csm::KwMutatingSampler,
        setting::Setting, individual_index::Int, present_inds::AbstractVector{Individual},
        tick::Int16; replace::Bool = true, rng::Xoshiro = Xoshiro(1))
    push!(indivs, present_inds[1])
    return indivs
end

# non-mutating keyword method, sharing a signature with GEMS' own generic wrapper
struct KwNonMutatingSampler <: ContactSamplingMethod end

function GEMS.sample_contacts(csm::KwNonMutatingSampler, setting::Setting,
        individual_index::Int, present_inds::AbstractVector{Individual}, tick::Int16;
        replace::Bool = true, rng::Xoshiro = Xoshiro(1))
    return [present_inds[1], present_inds[end]]
end

# still types present_inds as Vector, so a pooled setting's view reaches it only by copying
struct VectorOnlySampler <: ContactSamplingMethod end

function GEMS.sample_contacts!(indivs::Vector{Individual}, csm::VectorOnlySampler,
        setting::Setting, individual_index::Int, present_inds::Vector{Individual},
        tick::Int16; replace::Bool = true, rng::Xoshiro = Xoshiro(1))
    append!(indivs, present_inds)
    return indivs
end

# defines neither shape
struct NoMethodSampler <: ContactSamplingMethod end

@testset "Contact Sampling" begin
           
    # create testsets for each ContactSamplingMethod known in GEMS
    @testset "RandomSampling" begin

        # create RandomSampling Object (rs)
        rs = RandomSampling()

        # initial infectant
        i = Individual(id = 42, age = 21, sex = 0)

        # other individuals in the household
        indis = [Individual(id = j, age = 18, sex = 1) for j in 0:10]
        i_index = 6
        insert!(indis, i_index, i)
        
        # create Household setting based on the individuals
        h = Household(id = 1, individuals = indis, contact_sampling_method = rs)

        # create empty setting
        empty_h = Household(id = 2, individuals = Vector{Individual}(), contact_sampling_method = rs)

        # for these tests we assume that "present_inds" is equal to the individuals in "h" (so every individual of "h" is "present")

        # RandomSampling should only sample 1 contact
        @test length(sample_contacts(rs, h, i_index, individuals(h), GEMS.DEFAULT_TICK, rng = Xoshiro())) == 1
        
        # all "ContactSamplingMethod"s should return vectors of individuals 
        @test typeof(sample_contacts(rs, h, i_index, individuals(h), GEMS.DEFAULT_TICK, rng = Xoshiro())) == Vector{Individual}

        # Sampling from a setting where no individual is present should result in an error
        @test_throws ArgumentError sample_contacts(rs, empty_h, i_index, individuals(empty_h), GEMS.DEFAULT_TICK, rng = Xoshiro())
    end

    @testset "ContactParameterSampling" begin

        # create ContactparameterSampling Object
        cps = ContactparameterSampling(2)

        # initial infectant
        i = Individual(id = 42, age = 21, sex = 0)

        # other individuals in the household
        indis = [Individual(id = j, age = 18, sex = 1) for j in 0:10]
        i_index = 6
        insert!(indis, i_index, i)
        
        # create Household setting based on the individuals
        h = Household(id = 1, individuals = indis, contact_sampling_method = cps)

        # create empty setting
        empty_h = Household(id = 2, individuals = Vector{Individual}(), contact_sampling_method = cps)

        # for these tests we assume that "present_inds" is equal to the individuals in "h" (so every individual of "h" is "present")
        
        # all "ContactSamplingMethod"s should return vectors of individuals 
        @test typeof(sample_contacts(cps, h, i_index, individuals(h), GEMS.DEFAULT_TICK, rng = Xoshiro())) == Vector{Individual}

        # Sampling from a setting where no individual is present should result in an error
        @test_throws ArgumentError sample_contacts(cps, empty_h, i_index, individuals(empty_h), GEMS.DEFAULT_TICK, rng = Xoshiro())

        # Test that sample_contacts avoids self-sampling the input individual
        for _ in 1:10
            contacts = sample_contacts(cps, h, i_index, individuals(h), GEMS.DEFAULT_TICK, rng = Xoshiro())
            @test all(contact.id != i.id for contact in contacts)
        end

        # Test that sample_contacts with replace=false avoids self-sampling and produces unique contacts
        for _ in 1:10
            contacts = sample_contacts(cps, h, i_index, individuals(h), GEMS.DEFAULT_TICK, replace=false, rng = Xoshiro())
            @test all(contact.id != i.id for contact in contacts)
            @test length(unique([contact.id for contact in contacts])) == length(contacts)
        end
    end

    @testset "AgeBasedContactSampling" begin
        BASE_FOLDER = dirname(dirname(pathof(GEMS)))
        m = hcat([[rand() for i = 1:10] for i = 1:10]...)
        m = m .* hcat([vec(1 ./ sum(m, dims=2)) for _ =1:10]...) # normalization of each row
        abcs_null = AgeBasedContactSampling(0.0, 10, ContactMatrix{Float64}(m, 10, 100), Float64[])
        abcs1 = AgeBasedContactSampling(1.0, 10, ContactMatrix{Float64}(m, 10, 100), Float64[])
        abcs2 = AgeBasedContactSampling(2.0, 10, ContactMatrix{Float64}(m, 10, 100), Float64[])
        abcs3 = AgeBasedContactSampling(3.0, 10, ContactMatrix{Float64}(m, 10, 100), Float64[])
        abcs100 = AgeBasedContactSampling(contactparameter=100.0, interval=5, contact_matrix_file=BASE_FOLDER * "/test/testdata/contact_matrix.txt")

        # initial infectant
        i = Individual(id = 1, age = floor(Int, rand(Uniform(1, 100))), sex = floor(Int, rand(Uniform(0, 2))))

        # other individuals in the household
        indis = [Individual(id = j, age = floor(Int, rand(Uniform(1, 100))), sex = floor(Int, rand(Uniform(0, 2)))) for j in 2:10000]
        i_index = 6
        insert!(indis, i_index, i)

        # create Household setting based on the individuals
        h1 = Household(id = 1, individuals = indis, contact_sampling_method = abcs1)
        h2 = Household(id = 2, individuals = indis, contact_sampling_method = abcs2)
        h3 = Household(id = 3, individuals = indis, contact_sampling_method = abcs3)
        h100 = Household(id = 4, individuals = indis, contact_sampling_method = abcs100)
        hnull = Household(id = 5, individuals = indis, contact_sampling_method = abcs_null)

        # Sampling from a setting where with expected contacts is zero returns no individuals
        @test length(sample_contacts(abcs_null, hnull, i_index, individuals(hnull), GEMS.DEFAULT_TICK, rng = Xoshiro())) == 0

        # AgeBasedContactSampling should return vectors of individuals 
        @test typeof(sample_contacts(abcs_null, hnull, i_index, individuals(hnull), GEMS.DEFAULT_TICK, rng = Xoshiro())) == Vector{Individual}

        # Contact counts are Poisson(λ), so the mean of `n` draws has standard error √(λ/n).
        # The tolerance scales with λ: a flat ±1 would be only 3.2 SE at λ = 100.
        n = 1000
        rng = Xoshiro(42)
        tol(λ) = 5 * sqrt(λ / n)
        mean_contacts(abcs, h) = mean(length(sample_contacts(abcs, h, i_index, individuals(h), GEMS.DEFAULT_TICK, rng = rng)) for _ = 1:n)

        @test abs(mean_contacts(abcs1, h1) - 1.0) < tol(1.0)
        @test abs(mean_contacts(abcs2, h2) - 2.0) < tol(2.0)
        @test abs(mean_contacts(abcs3, h3) - 3.0) < tol(3.0)
        @test abs(mean_contacts(abcs100, h100) - 100.0) < tol(100.0)

        # create empty setting
        empty_h = Household(id = 2, individuals = Vector{Individual}(), contact_sampling_method = abcs1)

        # Sampling from a setting where no individual is present should result in an error
        @test_throws ArgumentError sample_contacts(abcs1, empty_h, i_index, individuals(empty_h), GEMS.DEFAULT_TICK, rng = Xoshiro())

        # replace=false avoids self-sampling and produces unique contacts
        for _ in 1:10
            contacts = sample_contacts(abcs3, h3, i_index, individuals(h3), GEMS.DEFAULT_TICK, replace = false, rng = Xoshiro())
            @test all(c -> c.id != i.id, contacts)
            @test length(unique(c.id for c in contacts)) == length(contacts)
        end

    end

@testset "sample_contacts positional wrapper" begin
        rs = RandomSampling()
        indivs = [Individual(id = j, age = 18, sex = 1) for j in 0:10]
        h = Household(id = 1, individuals = indivs, contact_sampling_method = rs)

        result = sample_contacts(rs, h, 1, indivs, GEMS.DEFAULT_TICK, true, Xoshiro(42))
        @test result isa Vector{Individual}
        @test length(result) == 1
    end

    @testset "Buffer-aware Sampling" begin
        rs = RandomSampling()
        indis = [Individual(id=j, age=18, sex=1) for j in 0:10]
        h = Household(id=1, individuals=indis, contact_sampling_method=rs)
        
        # Create an empty buffer
        buffer = Vector{Individual}()
        
        # Call the new ! version
        sample_contacts!(buffer, rs, h, 1, indis, Int16(1), true, Xoshiro(42))

        @test length(buffer) == 1
        @test buffer[1] isa Individual
        @test buffer[1].id != indis[1].id # Should not sample self
    end

    @testset "sample_contacts! dispatch fallback" begin
        inds = [Individual(id = j, age = 20, sex = 1) for j in 1:5]
        h = Household(id = 1, individuals = copy(inds),
            contact_sampling_method = ContactparameterSampling(1.0))
        # what a pooled setting hands out, as opposed to a plain Vector
        slice = view(inds, 1:length(inds))
        tick = GEMS.DEFAULT_TICK
        ids(f) = [i.id for i in f]

        @testset "mutating keyword method" begin
            csm = KwMutatingSampler()
            buf = Individual[]
            sample_contacts!(buf, csm, h, 1, inds, tick, true, Xoshiro(1))
            @test ids(buf) == [inds[1].id]

            # the view reaches the sampler as it is, with nothing copied on the way
            buf = Individual[]
            sample_contacts!(buf, csm, h, 1, slice, tick, true, Xoshiro(1))
            @test ids(buf) == [inds[1].id]
        end

        @testset "non-mutating keyword method" begin
            csm = KwNonMutatingSampler()
            buf = Individual[]
            sample_contacts!(buf, csm, h, 1, inds, tick, true, Xoshiro(1))
            @test ids(buf) == [inds[1].id, inds[end].id]

            # results are appended to the buffer, not swapped in for it
            buf = [inds[3]]
            sample_contacts!(buf, csm, h, 1, slice, tick, true, Xoshiro(1))
            @test ids(buf) == [inds[3].id, inds[1].id, inds[end].id]

            # and the non-mutating entry point reaches the same method
            @test ids(sample_contacts(csm, h, 1, slice, tick, true, Xoshiro(1))) ==
                [inds[1].id, inds[end].id]
        end

        @testset "Vector-typed sampler" begin
            csm = VectorOnlySampler()

            # already a Vector, so it is handed over directly
            buf = Individual[]
            sample_contacts!(buf, csm, h, 1, inds, tick, true, Xoshiro(1))
            @test ids(buf) == ids(inds)

            # a view has to be materialised first - the deprecated path, which warns
            buf = Individual[]
            with_logger(NullLogger()) do
                sample_contacts!(buf, csm, h, 1, slice, tick, true, Xoshiro(1))
            end
            @test ids(buf) == ids(inds)
        end

        @testset "no method defined" begin
            csm = NoMethodSampler()
            err = try
                sample_contacts!(Individual[], csm, h, 1, inds, tick, true, Xoshiro(1))
                nothing
            catch e
                e
            end
            @test err isa ErrorException
            @test occursin("NoMethodSampler", sprint(showerror, err))

            # a view gets the same answer rather than falling into the copying path
            @test_throws ErrorException sample_contacts!(Individual[], csm, h, 1, slice,
                tick, true, Xoshiro(1))
        end
    end

    @testset "too few members" begin
        m = hcat([[rand(Xoshiro(7 + i)) for i = 1:10] for i = 1:10]...)
        m = m .* hcat([vec(1 ./ sum(m, dims = 2)) for _ = 1:10]...)
        lone = [Individual(id = 1, age = 30, sex = 1)]

        # a member on their own has nobody to meet, which is not an error the way an
        # empty setting is
        cps = ContactparameterSampling(2.0)
        h = Household(id = 1, individuals = copy(lone), contact_sampling_method = cps)
        @test isempty(sample_contacts(cps, h, 1, lone, GEMS.DEFAULT_TICK, rng = Xoshiro(1)))

        abcs = AgeBasedContactSampling(2.0, 10, ContactMatrix{Float64}(m, 10, 100), Float64[])
        h2 = Household(id = 2, individuals = copy(lone), contact_sampling_method = abcs)
        @test isempty(sample_contacts(abcs, h2, 1, lone, GEMS.DEFAULT_TICK, rng = Xoshiro(1)))

        # with exactly one other member, `replace = false` draws from everyone but the last
        # slot, so the individual can only reach a valid contact via the self-swap
        pair = [Individual(id = 1, age = 30, sex = 1),
                Individual(id = 2, age = 30, sex = 1)]
        abcs2 = AgeBasedContactSampling(100.0, 10, ContactMatrix{Float64}(m, 10, 100), Float64[])
        h3 = Household(id = 3, individuals = copy(pair), contact_sampling_method = abcs2)

        drew = false
        for s in 1:20
            contacts = sample_contacts(abcs2, h3, 1, pair, GEMS.DEFAULT_TICK,
                replace = false, rng = Xoshiro(s))
            @test all(c -> c.id == pair[2].id, contacts) # never themselves
            drew |= !isempty(contacts)
        end
        @test drew # the assertion above is only worth anything if something was sampled
    end

    @testset "Scaled sampling thins" begin
        m = hcat([[rand(Xoshiro(3 + i)) for i = 1:10] for i = 1:10]...)
        m = m .* hcat([vec(1 ./ sum(m, dims = 2)) for _ = 1:10]...)
        inds = [Individual(id = j, age = 10 * j, sex = 1) for j in 1:9]
        tick = GEMS.DEFAULT_TICK
        household(csm) = Household(id = 1, individuals = copy(inds), contact_sampling_method = csm)
        plans, cntnr = ActivityPlanStore(), SettingsContainer()
        scaled(csm, h, rng, s_host, thin) = GEMS.sample_scaled_contacts!(Individual[], Individual[], csm, h, 2, inds, tick, true, rng,
            plans, cntnr, Float32(s_host), 1.0f0; thin = Float32(thin))

        # with or without `contact_rate`, a host keeps `s_host * thin` times a call's mean contacts
        n = 20_000
        rng = Xoshiro(9)
        samplers = [RandomSampling(), ContactparameterSampling(4.0),
            AgeBasedContactSampling(4.0, 10, ContactMatrix{Float64}(m, 10, 100), Float64[]), KwMutatingSampler()]
        for csm in samplers, s_host in (1, 2.5)
            h = household(csm)
            mu = mean(length(sample_contacts(csm, h, 2, inds, tick, true, rng)) for _ in 1:n)
            counts = [length(scaled(csm, h, rng, s_host, 0.3)) for _ in 1:n]
            @test abs(mean(counts) - mu * s_host * 0.3) < 5 * sqrt((var(counts) + mu * s_host * 0.3) / n)
        end

        # a method with `contact_rate` draws one Poisson count at its rate times `s_host * thin`
        counts = [length(scaled(samplers[2], household(samplers[2]), rng, 2.5, 0.3)) for _ in 1:n]
        @test isapprox(mean(counts), 3.0; atol = 0.08)
        @test isapprox(var(counts), 3.0; atol = 0.15)
        @test isapprox(mean(==(0), counts), exp(-3.0); atol = 0.01)
    end

    @testset "Contact rates" begin
        m = hcat([[rand(Xoshiro(5 + i)) for i = 1:10] for i = 1:10]...)
        m = m .* hcat([vec(1 ./ sum(m, dims = 2)) for _ = 1:10]...)
        # ages spread unevenly over the bins, so the host's own bin matters
        inds = [Individual(id = j, age = (j % 7) * 13, sex = 1) for j in 1:40]
        tick = GEMS.DEFAULT_TICK
        household(csm) = Household(id = 1, individuals = copy(inds), contact_sampling_method = csm)
        cps = ContactparameterSampling(2.5)
        abcs = AgeBasedContactSampling(2.5, 10, ContactMatrix{Float64}(m, 10, 100), Float64[])
        n = 40_000
        rng = Xoshiro(17)

        @test contact_rate_bound(KwMutatingSampler()) == Inf
        @test_throws ErrorException contact_rate(KwMutatingSampler(), household(cps), 2, inds, tick)
        @test contact_rate(cps, household(cps), 2, inds, tick) == 2.5
        @test contact_rate(cps, household(cps), 1, inds[1:1], tick) == 0.0
        @test contact_rate_bound(cps) == 2.5
        @test contact_rate_bound(abcs) == 5.0

        # an opted-in method's rate is the mean count of its own sampling, within its bound
        for csm in (cps, abcs), idx in (2, 5, 33)
            h = household(csm)
            rate = contact_rate(csm, h, idx, inds, tick)
            @test rate <= contact_rate_bound(csm)
            counts = [length(sample_contacts(csm, h, idx, inds, tick, true, rng)) for _ in 1:n]
            @test abs(mean(counts) - rate) < 5 * sqrt(rate / n)
        end

        # drawing k contacts picks who as sampling does, by a method's own draw and by the generic one
        generic_draw = Tuple{Vector{Individual}, ContactSamplingMethod, Setting, Int, AbstractVector{Individual}, Int16, Int, Xoshiro}
        for csm in (cps, abcs)
            h = household(csm)
            freq(v) = [count(c -> c === i, v) / length(v) for i in inds]
            sampled = reduce(vcat, [sample_contacts(csm, h, 5, inds, tick, true, rng) for _ in 1:(n ÷ 4)])
            own = sample_k_contacts!(Individual[], csm, h, 5, inds, tick, length(sampled), rng)
            generic = invoke(sample_k_contacts!, generic_draw, Individual[], csm, h, 5, inds, tick, length(sampled), rng)
            @test length(own) == length(generic) == length(sampled)
            @test all(c -> c !== inds[5], own)
            @test maximum(abs.(freq(own) .- freq(sampled))) < 0.01
            @test maximum(abs.(freq(generic) .- freq(sampled))) < 0.01
        end

        # nobody else has weight in the host's row: no contacts, and no endless draw
        alone = [Individual(id = 1, age = 5, sex = 1); [Individual(id = j, age = 50, sex = 1) for j in 2:5]]
        eye = AgeBasedContactSampling(2.5, 10, ContactMatrix{Float64}(Float64[i == j for i in 1:10, j in 1:10], 10, 100), Float64[])
        h = Household(id = 1, individuals = copy(alone), contact_sampling_method = eye)
        @test contact_rate(eye, h, 1, alone, tick) == 0.0
        @test isempty(sample_contacts(eye, h, 1, alone, tick, true, rng))
        @test_throws ErrorException sample_k_contacts!(Individual[], eye, h, 1, alone, tick, 1, rng)

        # a membership change drops the rate cache
        @test eye.rate_cache !== nothing
        membership_changed!(eye, h)
        @test eye.rate_cache === nothing

        @test_throws ArgumentError AgeBasedContactSampling(1.0, 10, ContactMatrix{Float64}(fill(-0.1, 10, 10), 10, 100), Float64[])
    end
end

@testset "Past Contacts" begin
    # two school years of two classes; each class holds two individuals
    cp = ContactparameterSampling(10)
    inds = [Individual(id=i, sex=1, age=10) for i in 1:8]
    scs = [SchoolClass(id=c, individuals=inds[2c-1:2c], contained=div(c - 1, 2) + 1, contact_sampling_method=cp) for c in 1:4]
    sys = [SchoolYear(id=y, contains=[2y - 1, 2y], contained=1, contact_sampling_method=cp) for y in 1:2]
    sc = SettingsContainer()
    add_types!(sc, [SchoolClass, SchoolYear])
    foreach(x -> add!(sc, x), scs)
    foreach(x -> add!(sc, x), sys)
    sim = Simulation()
    pop = Population(inds)
    foreach(i -> fake_membership!(pop, inds[i], SchoolClass, div(i - 1, 2) + 1), 1:8)
    sim.population = pop
    sim.settings = sc

    keep_all = GEMS.ContactFilterFn((s, t) -> true)

    # a container type draws from the whole school year, never the index or the other year
    latest = GEMS._sample_past_contacts(inds[1], sim, DataType[SchoolYear], Int16(1), Int16(3), keep_all)
    @test !isempty(latest)
    @test all(in(Int32(2):Int32(4)), keys(latest))
    @test all(t -> 1 <= t <= 3, values(latest))

    # a leaf type draws from the class only; a missing membership is skipped
    latest = GEMS._sample_past_contacts(inds[1], sim, DataType[SchoolClass, Household], Int16(1), Int16(3), keep_all)
    @test collect(keys(latest)) == Int32[2]
    @test latest[Int32(2)] == Int16(3)

    # the filter skips settings at ticks it rejects
    latest = GEMS._sample_past_contacts(inds[1], sim, DataType[SchoolClass], Int16(1), Int16(3),
        GEMS.ContactFilterFn((s, t) -> t != 3))
    @test latest[Int32(2)] == Int16(2)

    latest = GEMS._sample_past_contacts(inds[1], sim, DataType[SchoolClass, SchoolYear], Int16(1), Int16(3),
        GEMS.ContactFilterFn((s, t) -> !(s isa SchoolClass)))
    @test all(in(Int32(2):Int32(4)), keys(latest))
end

@testset "Past Contacts with activity plans" begin
    # two classes in one year: members 5 and 6 are in both, member 3 has scale 0, and member 10 sets the bound
    function scaled_school(csm)
        cntnr = SettingsContainer()
        add_types!(cntnr, [SchoolClass, SchoolYear])
        inds = [Individual(id = Int32(j), age = 5j, sex = 1) for j in 1:10]
        cs = [SchoolClass(id = Int32(1), individuals = inds[1:6], contained = Int32(1), contact_sampling_method = deepcopy(csm)),
              SchoolClass(id = Int32(2), individuals = inds[5:10], contained = Int32(1), contact_sampling_method = deepcopy(csm))]
        yr = SchoolYear(id = Int32(1), contains = Int32[1, 2], contact_sampling_method = deepcopy(csm))
        for s in vcat(cs, [yr]); GEMS.add!(cntnr, s); end
        GEMS.build_pools!(cntnr)
        pop = Population(inds)
        for (k, c) in enumerate(cs), m in individuals(c)
            assign_settings!(pop, m, SchoolClass => k; scale = id(m) == 3 ? 0.0 : id(m) == 5 ? 0.5 : 0.25 * id(m))
        end
        assign_member_indices!(pop, cntnr)
        GEMS.repack_dirty_pools!(cntnr)
        sim = Simulation(pop_size = 100, seed = 1)
        sim.population = pop
        sim.settings = cntnr
        return sim, cntnr, activity_plans(pop), pop, inds, cs, yr
    end
    age_based() = AgeBasedContactSampling(2.0, 10, ContactMatrix{Float64}(ones(10, 10) ./ 10, 10, 100), Float64[])
    keep_all = GEMS.ContactFilterFn((s, t) -> true)
    trace(ind, sim, types; from = 1, to = 5, filter = keep_all) =
        GEMS._sample_past_contacts(ind, sim, DataType[types...], Int16(from), Int16(to), filter)

    @testset "draws what transmission draws while nothing is closed" begin
        for csm in (ContactparameterSampling(2.0), RandomSampling(), age_based())
            sim, cntnr, plans, pop, inds, cs, yr = scaled_school(csm)
            same_draws = true
            same_rng = true
            for s in (cs[1], cs[2], yr)
                frame = GEMS.present_members(s, cntnr)
                @test collect(GEMS._members_alive_at(s, Int16(0), sim)) == collect(frame)
                bound = GEMS._scale_bound(s)
                for (pos, host) in enumerate(frame), t in Int16(1):Int16(5)
                    s_host = GEMS._membership_scale(plans, host, s, cntnr)
                    r1 = Xoshiro(100 * pos + t)
                    r2 = copy(r1)
                    spread = GEMS.sample_scaled_contacts!(Individual[], Individual[], contact_sampling_method(s), s, pos, frame, t, true,
                        r1, plans, cntnr, s_host, bound)
                    traced = GEMS._draw_past_contacts_at!(Individual[], Individual[], contact_sampling_method(s), s, pos, frame, t,
                        s_host, bound, r2, plans, cntnr)
                    same_draws &= spread == traced
                    same_rng &= r1 == r2
                end
            end
            @test same_draws
            @test same_rng
        end
    end

    @testset "scales set the number of contacts" begin
        for csm in (ContactparameterSampling(5.0), RandomSampling())
            sim, cntnr, plans, pop, inds, cs, yr = scaled_school(csm)
            # a host or a contact of scale 0 draws nobody and is never drawn
            @test isempty(trace(inds[3], sim, [SchoolClass]; to = 200))
            @test inds[3].id ∉ keys(trace(inds[1], sim, [SchoolClass]; to = 200))
        end

        # a contact of scale 0.5 is drawn half as often as one of scale 1, counted per draw as the result lists each once
        sim, cntnr, plans, pop, inds, cs, yr = scaled_school(ContactparameterSampling(5.0))
        s = cs[1]
        members = GEMS._members_alive_at(s, Int16(0), sim)
        counts = Dict(id(m) => 0 for m in members)
        rng = Xoshiro(1)
        contacts, draws = Individual[], Individual[]
        s_host = GEMS._membership_scale(plans, inds[1], s, cntnr)
        for _ in 1:40_000
            GEMS._draw_past_contacts_at!(contacts, draws, contact_sampling_method(s), s, 1, members, Int16(1), s_host, GEMS._scale_bound(s), rng, plans, cntnr)
            foreach(c -> counts[id(c)] += 1, contacts)
        end
        @test isapprox(counts[2] / counts[4], 0.5; atol = 0.03)
        # a host of half the scale draws half as many, on average
        half = sum(1:40_000) do _
            length(GEMS._draw_past_contacts_at!(contacts, draws, contact_sampling_method(s), s, 1, members, Int16(1), s_host / 2, GEMS._scale_bound(s), rng, plans, cntnr))
        end
        @test isapprox(half / sum(values(counts)), 0.5; atol = 0.03)
    end

    @testset "which settings are re-drawn" begin
        # two classes, and the year by default, which reaches someone only in the other class
        sim, cntnr, plans, pop, inds, cs, yr = scaled_school(ContactparameterSampling(5.0))
        @test Int32(9) ∉ keys(trace(inds[1], sim, [SchoolClass]; to = 100))
        @test Int32(9) in keys(trace(inds[1], sim, DataType[Household, SchoolClass, SchoolYear, School, SchoolComplex, Office, Department, Workplace, WorkplaceSite]; to = 100))
        # both classes of someone in two
        @test all(in(keys(trace(inds[5], sim, [SchoolClass]; to = 200))), Int32[1, 2, 7, 8])

        # a container with the default method of contact rate 0 is skipped
        sim, cntnr, plans, pop, inds, cs, yr = scaled_school(ContactparameterSampling(5.0))
        yr.contact_sampling_method = ContactparameterSampling(0)
        @test Int32(9) ∉ keys(trace(inds[1], sim, DataType[Household, SchoolClass, SchoolYear, School, SchoolComplex, Office, Department, Workplace, WorkplaceSite]; to = 100))
    end

    @testset "today's closures and quarantines are ignored" begin
        sim, cntnr, plans, pop, inds, cs, yr = scaled_school(ContactparameterSampling(5.0))
        close!(cs[1])
        GEMS.quarantined!(inds[2], true)
        GEMS.home_quarantine!(inds[2])
        # read while the pool waits for its repack, as during events after a death or closure
        @test Int32(2) in keys(trace(inds[1], sim, [SchoolClass]; to = 200))
        @test Int32(2) in keys(trace(inds[1], sim, [SchoolYear]; to = 200))
    end

    @testset "the dead" begin
        sim, cntnr, plans, pop, inds, cs, yr = scaled_school(ContactparameterSampling(5.0))
        kill(m, t) = (GEMS.dead!(m, true); m.death = Int16(t); mark_deceased!(cs[1], m, pop))

        # alive members: the view of the living, which the setting's method already counts
        @test GEMS._members_alive_at(cs[1], Int16(4), sim) isa SubArray

        # who died by the window's start is out, who died in it is in, but cannot be traced
        kill(inds[2], 3)
        kill(inds[4], 8)
        members = GEMS._members_alive_at(cs[1], Int16(5), sim)
        @test members isa Vector{Individual}
        @test inds[2] ∉ members
        @test inds[4] in members
        @test inds[2] ∉ GEMS._members_alive_at(yr, Int16(5), sim)
        @test inds[4] in GEMS._members_alive_at(yr, Int16(5), sim)
        traced = trace(inds[1], sim, [SchoolClass]; from = 5, to = 100)
        @test Int32(4) ∉ keys(traced)
        @test !isempty(traced)

        # after everyone in it died before the window, the view is the list again
        @test GEMS._members_alive_at(cs[1], Int16(8), sim) isa SubArray

        # a dead index is on the list for a window before its death, and its re-draw stops the tick before it
        kill(inds[6], 4)
        @test inds[6] in GEMS._members_alive_at(cs[1], Int16(3), sim)
        ticks = Int16[]
        traced = trace(inds[6], sim, [SchoolClass]; from = 1, to = 10, filter = (s, t) -> (s === cs[1] && push!(ticks, t); true))
        @test ticks == Int16[1, 2, 3]
        @test !isempty(traced)
    end

    @testset "the sampling method's cache" begin
        sim, cntnr, plans, pop, inds, cs, yr = scaled_school(age_based())
        csm = contact_sampling_method(yr)
        frame = GEMS.present_members(yr, cntnr)

        # a built list leaves an empty cache empty
        @test csm.rate_cache === nothing
        @test !isempty(trace(inds[1], sim, [SchoolYear]; to = 100))
        @test csm.rate_cache === nothing
        @test isempty(csm.bin_counts)

        # and a filled one as it was
        rate = contact_rate(csm, yr, 1, frame, Int16(1))
        cache = csm.rate_cache
        @test cache !== nothing
        trace(inds[1], sim, [SchoolYear]; to = 100)
        @test csm.rate_cache === cache
        @test contact_rate(csm, yr, 1, frame, Int16(1)) == rate
    end
end
