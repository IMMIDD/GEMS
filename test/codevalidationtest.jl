@testset "naked rng calls" begin

    # finds all instances of rng calls using a regex
    forbidden_pattern = Regex("\\b($(join(["rand", "randn", "shuffle", "shuffle!", "sample", "sample!"], "|")))\\(")
    
    files_to_ignore = Set(["utils.jl"])

    src_path = joinpath(pkgdir(GEMS), "src")
    offending_lines = []

    for (root, dirs, files) in walkdir(src_path)
        for file in files
            if file in files_to_ignore
                continue
            end

            if endswith(file, ".jl")
                filepath = joinpath(root, file)
                for (i, line) in enumerate(eachline(filepath))
                    line_without_comments = first(split(line, '#'))
                    
                    if occursin(forbidden_pattern, line_without_comments)
                        push!(offending_lines, (filepath, i, strip(line_without_comments)))
                    end
                end
            end
        end
    end

    @test isempty(offending_lines)

    if !isempty(offending_lines)
        println("\nDisallowed RNG calls found by searching source files:")
        for (filepath, line_num, content) in offending_lines
            println("- Found in `$filepath` on line $line_num:\n  `$content`")
        end
    end
end
