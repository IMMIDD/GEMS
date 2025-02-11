### THIS FILE IS DEDICATED TO TEST THE PERFORMANCE OF CERTAIN IMPLEMENTATION OPTIONS ##
using BenchmarkTools
using Random

# STRUCTS

### ACCESS PERFORMANCE

# Testing whether it makes a notable difference whether object members are accssed
# directly or via wrapping getter function

mutable struct T
    a::Float64
end

function a(t::T)
    return(t.a)
end

function rawAccess(data)
    for i in data
        x = sqrt(i.a)
    end
end

function wrappedAccess(data)
    for i in data
        x = sqrt(a(i))
    end
end

data = Array{T}(undef, 1_000_000)
    for i in 1:length(data)
        data[i] = T(rand())
    end


@btime rawAccess(data)
@btime wrappedAccess(data)

# results
#   2.276 ms (0 allocations: 0 bytes)
#   2.278 ms (0 allocations: 0 bytes)
# --> almost identical runtime


### FILTER ACTIVE SETTINGS

# testing how long it would take to filter a list of 40 million setting IDs by true/false
# bitvector. In comparison to filling a dynamic set with active setting objects on the fly

# bitvector
rng = MersenneTwister(1234)
r = bitrand(rng, 40_000_000)

# setting ID vector
t = [1:1:40_000_000;]

function filterSettings()
    t[r]
end

@btime filterSettings()

# results
#   47.688 ms (2 allocations: 152.59 MiB)
#   -> quite low runtime but considerable memory allocation


# MULTI-THREADING

# Important: Start threaded Julia session before testing
# use: >julia --threads auto


### THREADING SEQUENCE

# test whether threaded loops and subsequent instructions
# are run asynchronously

Threads.@threads for i = 1:100
    println(Threads.threadid())
end


# result: last println only evaluated once loop has been completed


### THREADING PERFORMANCE WRITING TO SAME VECTOR

function singleT!(v)
    for i in 1:length(v)
        v[i] = sqrt(i)
    end
end

function multiT!(v)
    Threads.@threads for i in 1:length(v)
        v[i] = sqrt(i)
    end
end

@btime singleT!(zeros(10_000_000))
@btime multiT!(zeros(10_000_000))

# results (on 8 cores and 16 threads)
#   4.674 ms (2 allocations: 7.63 MiB)
#   1.722 ms (99 allocations: 7.64 MiB)
#  -> 3-fold improvement without any further optimization