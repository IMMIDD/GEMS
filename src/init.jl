"""
    check_naked_rng_calls(; src_path=joinpath(Pkg.pkgdir(@__MODULE__), "src"), files_to_ignore=Set(["utils.jl"]))

Checks source files for direct calls to RNG functions
excluding specified files. Returns `offending_lines::Vector`.
"""
function check_naked_rng_calls(;
    src_path = @__DIR__, # this only works because the devToolss.jl is actually in the src folder. If this file is moved, the src_path needs to be adjusted accordingly.
    files_to_ignore::Set{String} = Set(["rng.jl"])
)
    forbidden_pattern = Regex("\\b($(join(["rand", "randn", "shuffle", "shuffle!", "sample", "sample!"], "|")))\\(")
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

    return offending_lines
end