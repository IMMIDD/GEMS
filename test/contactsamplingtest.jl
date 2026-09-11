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
end
