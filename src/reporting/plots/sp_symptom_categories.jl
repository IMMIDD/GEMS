export SymptomCategories

###
### STRUCT
###

"""
    SymptomCategories <: SimulationPlot

A simulation plot type for visualizing the symptom categories of infections by age.
"""
@with_kw mutable struct SymptomCategories <: SimulationPlot

    title::String = "Symptom Categories" # dfault title
    description::String = "" # default description empty
    filename::String = "symptom_categories.png" # default filename

    # indicates to which package the result plot belongs
    # is used to parallelize report generation and prevents
    # concurrent generation of plots coming from the same package
    # if you don't know the origin package or if the function
    # returns different plot types depending on the input, 
    # just put ":other" which will trigger sequential generation
    package::Symbol = :Plots
        
end

###
### PLOT GENERATION
###

"""
    generate(plt::SymptomCategories, rd::ResultData; plotargs...)

Generates and returns a `symptom_category` x `age` matrix as heatmap.
You can pass any additional keyword arguments using `plotargs...` that are available in the `Plots.jl` package.

# Parameters

- `plt::SymptomCategories`: `SimulationPlot` struct with meta data (i.e. title, description, and filename)
- `rd::ResultData`: Input data used to generate plot
- `plotargs...` *(optional)*: Any argument that the `plot()` function of the `Plots.jl` package can take.

# Returns

- `Plots.Plot`: Symptom Categories plot
"""
function generate(plt::SymptomCategories, rd::ResultData; plotargs...)

    # build symptom_category x age matrix
    df = rd |> infections
    co_state_age = zeros(Float64, maximum(df.symptom_category), maximum(df.age_b) + 1)
    
    for x in 1:nrow(df)
        co_state_age[df.symptom_category[x],df.age_b[x]+1] += 1
    end

    for x in 1:length(co_state_age[1,:])
        co_state_age[:,x] = co_state_age[:,x] ./ sum(co_state_age[:,x])
    end

    # add description
    desc = "This graph shows the disease progression in terms of severity "
    desc *= "(_asymptomatic, mild, severe, critical_) per age group. The "
    desc *= "color-coding tells for which percentage of infected individuals of a certain age (x-axis) "
    desc *= "the disease progressed to a certain final state (y-axis). "
    desc *= "Look up the glossary for more detailed explanations on the particular progression categories."
    
    description!(plt, desc)

    # crete plot object
    p = heatmap(co_state_age, 
        color =:viridis, 
        xlabel="Age", 
        ylabel="Symptom Category", 
        colorbar_title = "Relative Frequency",
        fontfamily="Times Roman",
        dpi = 300)
        yticks!((
            minimum(SYMPTOM_CATEGORIES |> keys |> collect |> sort |> x -> x[2:end]):maximum(SYMPTOM_CATEGORIES |> keys), 
            [SYMPTOM_CATEGORIES[i] for i in minimum(SYMPTOM_CATEGORIES |> keys |> collect |> sort |> x -> x[2:end]):maximum(SYMPTOM_CATEGORIES |> keys)]
        ))

    # add custom arguments that were passed
    plot!(p; plotargs...)

    return(p)
end