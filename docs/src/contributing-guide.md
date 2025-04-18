# Contributing to GEMS

In case you want to contribute to the GEMS package, please consider that we follow a workflow for the development for which you will find a brief guideline here.
We are excited to see your contibutions to this project!

Contributions to GEMS are [released](https://help.github.com/articles/github-terms-of-service/#6-contributions-under-repository-license) to the public under the [project’s open source license](https://github.com/IMMIDD/GEMS/blob/f711885e4497a6162a4aeec6459d77835f25a212/LICENSE).

You can open issues to request features and report bugs or directly add to the code base via pull requests.

## Issues

- **Feature**: Something that you would like to see in GEMS.
  - Provide a meaningful title
  - Specify your use-case precisely and suggest how to address the issue you currently encounter
- **Bugs**: Something that doesn't work as expected.
  - Provide a meaningful title
  - Include detailed examples on how to reproduce the issue
  - Describe the observed AND expected behavior in detail 

Before submitting an issue, please make sure you're not submitting a duplicate and review the [currently open issues](https://github.com/IMMIDD/GEMS/issues).
If there is an issue addressing your request, add a thumbs-up to help us prioritize fixes.

## Pull Requests

Another way to directly contribute to GEMS is through pull requests (PRs).
Please follow these steps to submit PRs:

- Fork and clone the GEMS repository
- Install GEMS
- Create a new branch
- Apply your changes to the code
- Push to your fork
- Make a pull request

We will review your code changes as soon as possible.
However, there is no guarantee your PR will be merged.
Moreover, we might get back to you with requests after review.
These are our review requirements:

- Up-to-date with master with no merge conflicts
- Self-contained
- Following the [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/)
- New functions have complete, correctly formatted docstrings (see Style Guide below)
- New features have a unit tests
- Documentation updated (if applicable)
- *Optional for substantial extensions*: Add a tutorial to the documentation

## Style Guides
There is an official style guide for Julia, the [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/).


This guide was mostly used for the Blue Style.
We will follow the [Blue style](https://github.com/invenia/BlueStyle), but as the Julia Style Guide is a large part of the Blue Style, there wont be many cases, where following the Julia Style Guide would be far off.

Some differences include a 92 character line limit or the snake_case for method names. When in doubt, look at existing code in the project/module/file.

### GEMS Docstring Format

We require every function in GEMS to have a docstring like this:

- complete signature copied to the very top (indented).
  If you have multiple functions of the same name (that do roughly the same), copy all signatures here.
  You don't need to have docstrings for *all* functions of the same name.
- Add a clear and expressive description of what the function does.
- Add a parameter section for each function with 3+ arguments
- Parameters are presented as a list with argument name, type and description
- Optional parameters are qualified as such and state their default value
- Add a section that states the return value type and brief explanation.

Here's an example:

```julia
"""
    my_function(a::Int, b::Float; c::String = "Hello")

This is a clear, concise, and (ideally) short description of what the function does.

# Parameters

- `a::Int`: First required input argument
- `b::Float`: Second required input argument
- `c::String = "Hello"` *(optional)*: Optional string-argument

# Returns

- `Int`: 42, which is always right, no matter the input.

"""
function my_function(a::Int, b::Float; c::String = "Hello")
    # do stuff
    return 42
end
```
