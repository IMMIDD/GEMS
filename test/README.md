# Test Structure (For Maintenance and Development)
To test systematically test new functionality as part of the development, we use unit tests. If you wrote new functionality for already existing types or a certain "theme", add unit tests to the corresponding file. In most cases you want to define a new testset with `@testset` in the corresponding file.

> For example: You wrote a new function `better_infect!` for GEMS. Go to [infectionstest.jl](test/infectionstest.jl) and add a testset with @testset on a correct sublevel. For example just inside of the "Infections" testset. Then write tests for the new function by using `@test` followed by an expression that evaluates to a boolean value, e.g.
> ```julia
> ...
> better_infect!(individual, Int16(0), pathogen)
> @test infected(individual)
> ...
> ```

If it makes more sense to create a new file to contain the new testsets and tests, create that file as `<what-to-test>tests.jl` (see for example the existing [infectionstest.jl](test/infectionstest.jl) or [vaccinetest.jl](test/vaccinetest.jl)). Then include this file in the array `testfiles` in [runtests.jl](test/runtests.jl).