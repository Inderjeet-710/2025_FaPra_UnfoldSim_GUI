"""
Utility functions for UnfoldSim Dashboard
"""

using ColorSchemes
using Colors
using StatsModels
using DataFrames

"""
    map_to_beta(gui_val)

Map GUI slider value (0-100) to beta parameter range
"""
map_to_beta(gui_val) = (gui_val - 50) / 2.5

"""
    map_to_contrast(gui_val)

Map GUI slider value (0-100) to contrast parameter range
"""
map_to_contrast(gui_val) = (gui_val - 50) / 5

"""
    map_to_sigma(gui_val)

Map GUI slider value (0-100) to sigma (random effect) parameter
"""
map_to_sigma(gui_val) = gui_val / 20

"""
    map_to_subjects(gui_val)

Map GUI slider value to number of subjects (minimum 1)
"""
map_to_subjects(gui_val) = max(1, round(Int, gui_val / 2))

"""
    map_to_items(gui_val)

Map GUI slider value to number of items (minimum 2)
"""
map_to_items(gui_val) = max(2, round(Int, gui_val))

"""
    map_to_noise(gui_val)

Map GUI slider value to noise level
"""
map_to_noise(gui_val) = gui_val / 10

"""
    map_to_mu(gui_val)

Map GUI slider value to mu parameter (-1.0 to 2.0 range)
"""
map_to_mu(gui_val) = -1.0 + (gui_val / 100) * 3.0

"""
    map_to_onset_sigma(gui_val)

Map GUI slider value to onset sigma parameter (0.1 to 1.0)
"""
map_to_onset_sigma(gui_val) = 0.1 + (gui_val / 100) * 0.9

"""
    map_to_offset(gui_val)

Map GUI slider value to offset parameter
"""
map_to_offset(gui_val) = round(Int, gui_val * 2)

"""
    map_to_truncate(gui_val)

Map GUI slider value to upper truncation parameter
"""
map_to_truncate(gui_val) = round(Int, 100 + gui_val * 9)

"""
    map_to_truncate_lower(gui_val)

Map GUI slider value to lower truncation parameter
"""
map_to_truncate_lower(gui_val) = round(Int, gui_val * 5)

"""
    map_to_width(gui_val)

Map GUI slider value to width parameter
"""
map_to_width(gui_val) = round(Int, 10 + gui_val * 1.9)

"""
    get_channel_colors(n_channels)

Generate color scheme for multiple channels using jet colormap
"""
function get_channel_colors(n_channels)
    return [ColorSchemes.jet[i / n_channels] for i in 1:n_channels]
end

"""
    count_formula_terms(formula_str::String, cat_vars::Dict, cont_vars::Dict)

Count the number of terms in a formula string, accounting for categorical variable levels.

# Arguments
- `formula_str`: Formula string (e.g., "@formula(0 ~ 1 + condition)")
- `cat_vars`: Dictionary of categorical variables and their levels
- `cont_vars`: Dictionary of continuous variables

# Returns
Integer count of formula terms (for beta vector generation)
"""
function count_formula_terms(formula_str::String, cat_vars::Dict, cont_vars::Dict)
    if !occursin("+", formula_str) || formula_str == "@formula(0 ~ 1)"
        return 1
    end
    
    n_terms = 1  # Intercept
    clean_formula = replace(formula_str, r"@formula\([^~]*~\s*" => "")
    clean_formula = replace(clean_formula, ")" => "")
    terms = [strip(t) for t in split(clean_formula, "+")]
    filter!(t -> t != "1", terms)
    
    for term in terms
        base_var = replace(term, r"\^[0-9]+" => "")
        base_var = strip(base_var)
        
        if haskey(cat_vars, base_var)
            n_levels = length(cat_vars[base_var])
            n_terms += (n_levels - 1)  # Dummy coding: k-1 terms for k levels
        else
            n_terms += 1
        end
    end
    
    return n_terms
end

"""
    build_design_from_events(categorical_vars, continuous_vars, design_type, n_items, n_subjects)

Build an UnfoldSim design object from event variable specifications.

# Arguments
- `categorical_vars`: Dict of categorical variable names => level vectors
- `continuous_vars`: Dict of continuous variable names => (min, max, steps) tuples
- `design_type`: "Single-subject design", "Repeat design", or "Multi-subject design"
- `n_items`: Number of items/repeats
- `n_subjects`: Number of subjects

# Returns
UnfoldSim design object (SingleSubjectDesign, RepeatDesign, or MultiSubjectDesign)
"""
function build_design_from_events(categorical_vars::Dict, continuous_vars::Dict,
                                   design_type::String, n_items::Int, n_subjects::Int)
    conditions = Dict{Symbol, Any}()
    
    # Add categorical variables
    for (var_name, levels) in categorical_vars
        if !isempty(levels)
            conditions[Symbol(var_name)] = levels
        end
    end
    
    # Add continuous variables
    for (var_name, params) in continuous_vars
        conditions[Symbol(var_name)] = range(params.min, params.max, length=params.steps)
    end
    
    # Default condition if none specified
    if isempty(conditions)
        conditions[:condition] = ["A", "B"]
    end
    
    # Build appropriate design type
    if design_type == "Single-subject design"
        return SingleSubjectDesign(; conditions = conditions)
    elseif design_type == "Repeat design"
        base_design = SingleSubjectDesign(; conditions = conditions)
        return RepeatDesign(base_design, n_items)
    else  # Multi-subject design
        items_between_dict = Dict{Symbol, Any}()
        for (var_name, levels) in categorical_vars
            if !isempty(levels)
                items_between_dict[Symbol(var_name)] = levels
                break
            end
        end
        if isempty(items_between_dict)
            items_between_dict[:condition] = ["A", "B"]
        end
        
        ni_adjusted = n_items % 2 == 0 ? n_items : n_items - 1
        return MultiSubjectDesign(n_subjects = n_subjects, n_items = ni_adjusted,
                                  items_between = items_between_dict)
    end
end