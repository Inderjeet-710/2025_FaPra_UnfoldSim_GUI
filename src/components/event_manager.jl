"""
Event Variable Management Component

Handles categorical and continuous variable definitions for experimental designs.
"""

using Bonito
using Observables

"""
    create_event_manager(session)

Create event variable management UI and logic.

Returns: (categorical_variables, continuous_variables, event_definition_ui)
"""
function create_event_manager(session)
    # Observables
    categorical_variables = Observable(Dict{String, Vector{String}}("condition" => ["A", "B"]))
    continuous_variables = Observable(Dict{String, NamedTuple{(:min, :max, :steps), Tuple{Float64, Float64, Int}}}())
    event_status = Observable("Default: condition = [A, B]")
    
    # UI Controls - Categorical
    cat_var_dropdown = Bonito.Dropdown(CAT_VAR_OPTIONS; index=1)
    add_cat_var_button = Bonito.Button("+ Add Template")
    custom_cat_name = Bonito.TextField("my_variable")
    custom_cat_levels = Bonito.TextField("level1, level2, level3")
    add_custom_cat_button = Bonito.Button("+ Add Custom Categorical")
    remove_cat_var_dropdown = Bonito.Dropdown(["condition"]; index=1)
    remove_cat_var_button = Bonito.Button("- Remove Selected")
    
    # UI Controls - Continuous
    cont_var_dropdown = Bonito.Dropdown(CONT_VAR_OPTIONS; index=1)
    add_cont_var_button = Bonito.Button("+ Add Template")
    custom_cont_name = Bonito.TextField("my_continuous")
    custom_cont_min = Bonito.TextField("0.0")
    custom_cont_max = Bonito.TextField("10.0")
    custom_cont_steps = Bonito.TextField("5")
    add_custom_cont_button = Bonito.Button("+ Add Custom Continuous")
    remove_cont_var_dropdown = Bonito.Dropdown(["intensity"]; index=1)
    remove_cont_var_button = Bonito.Button("- Remove Selected")
    
    # Update dropdown options when variables change
    on(categorical_variables) do cat_vars
        options = collect(keys(cat_vars))
        if isempty(options)
            options = ["none"]
        end
        remove_cat_var_dropdown.options[] = options
        if !isempty(options)
            remove_cat_var_dropdown.value[] = options[1]
        end
    end
    
    on(continuous_variables) do cont_vars
        options = collect(keys(cont_vars))
        if isempty(options)
            options = ["none"]
        end
        remove_cont_var_dropdown.options[] = options
        if !isempty(options)
            remove_cont_var_dropdown.value[] = options[1]
        end
    end
    
    # Event Handlers - Categorical
    on(add_cat_var_button.value) do _
        try
            var_name = cat_var_dropdown.value[]
            if !haskey(VARIABLE_TEMPLATES, var_name)
                event_status[] = "❌ Error: Variable template not found"
                return
            end
            levels = VARIABLE_TEMPLATES[var_name]
            new_vars = copy(categorical_variables[])
            new_vars[var_name] = levels
            categorical_variables[] = new_vars
            event_status[] = "✓ Added template: $var_name = $levels"
        catch e
            event_status[] = "❌ Error adding template: $(sprint(showerror, e))"
        end
    end
    
    on(add_custom_cat_button.value) do _
        try
            var_name = strip(custom_cat_name.value[])
            levels_str = custom_cat_levels.value[]
            levels = [strip(s) for s in split(levels_str, ',') if !isempty(strip(s))]
            
            if isempty(var_name)
                event_status[] = "❌ Error: Variable name cannot be empty"
                return
            end
            if isempty(levels)
                event_status[] = "❌ Error: Must provide at least one level"
                return
            end
            if length(levels) < 2
                event_status[] = "⚠️ Warning: Categorical variables should have at least 2 levels"
            end
            
            new_vars = copy(categorical_variables[])
            new_vars[var_name] = levels
            categorical_variables[] = new_vars
            event_status[] = "✓ Added custom: $var_name = $levels"
        catch e
            event_status[] = "❌ Error adding custom variable: $(sprint(showerror, e))"
        end
    end
    
    on(remove_cat_var_button.value) do _
        try
            var_name = remove_cat_var_dropdown.value[]
            if var_name == "none"
                event_status[] = "❌ No variables to remove"
                return
            end
            
            new_vars = copy(categorical_variables[])
            if haskey(new_vars, var_name)
                delete!(new_vars, var_name)
                categorical_variables[] = new_vars
                event_status[] = "✓ Removed categorical: $var_name"
            else
                event_status[] = "❌ Variable not found: $var_name"
            end
        catch e
            event_status[] = "❌ Error removing categorical: $(sprint(showerror, e))"
        end
    end
    
    # Event Handlers - Continuous
    on(add_cont_var_button.value) do _
        try
            var_name = cont_var_dropdown.value[]
            if !haskey(VARIABLE_TEMPLATES, var_name)
                event_status[] = "❌ Error: Variable template not found"
                return
            end
            params = VARIABLE_TEMPLATES[var_name]
            new_vars = copy(continuous_variables[])
            new_vars[var_name] = params
            continuous_variables[] = new_vars
            event_status[] = "✓ Added template: $var_name = [$(params.min):$(params.max), $(params.steps) steps]"
        catch e
            event_status[] = "❌ Error adding template: $(sprint(showerror, e))"
        end
    end
    
    on(add_custom_cont_button.value) do _
        try
            var_name = strip(custom_cont_name.value[])
            min_val = parse(Float64, custom_cont_min.value[])
            max_val = parse(Float64, custom_cont_max.value[])
            steps_val = parse(Int, custom_cont_steps.value[])
            
            if isempty(var_name)
                event_status[] = "❌ Error: Variable name cannot be empty"
                return
            end
            if steps_val < 2
                event_status[] = "❌ Error: Steps must be ≥ 2"
                return
            end
            if min_val >= max_val
                event_status[] = "❌ Error: Min must be less than Max"
                return
            end
            
            new_vars = copy(continuous_variables[])
            new_vars[var_name] = (min=min_val, max=max_val, steps=steps_val)
            continuous_variables[] = new_vars
            event_status[] = "✓ Added custom: $var_name = [$min_val:$max_val, $steps_val steps]"
        catch e
            event_status[] = "❌ Error adding custom variable: $(sprint(showerror, e))"
        end
    end
    
    on(remove_cont_var_button.value) do _
        try
            var_name = remove_cont_var_dropdown.value[]
            if var_name == "none"
                event_status[] = "❌ No variables to remove"
                return
            end
            
            new_vars = copy(continuous_variables[])
            if haskey(new_vars, var_name)
                delete!(new_vars, var_name)
                continuous_variables[] = new_vars
                event_status[] = "✓ Removed continuous: $var_name"
            else
                event_status[] = "❌ Variable not found: $var_name"
            end
        catch e
            event_status[] = "❌ Error removing continuous: $(sprint(showerror, e))"
        end
    end
    
    # Display
    event_variables_display = create_event_variables_display(categorical_variables, continuous_variables)
    
    # Build UI
    event_definition_ui = Bonito.DOM.div(
        Bonito.DOM.h4("Event Definition", style="font-size: 13px; margin: 6px 0; color: #2196F3;"),
        Bonito.DOM.div(
            Bonito.DOM.span("💡 Create variables using templates OR define your own custom variables.",
                style="font-size: 10px; color: #666; font-style: italic; display: block; margin-bottom: 8px;"),
            style="padding: 6px; background: #fffde7; border-left: 3px solid #FFC107; border-radius: 3px; margin-bottom: 8px;"
        ),
        
        # Categorical Section
        Bonito.DOM.div(
            Bonito.DOM.span("🔤 Categorical Variables", style="font-weight: bold; font-size: 11px; display: block; margin-bottom: 8px;"),
            Bonito.DOM.div(
                Bonito.DOM.span("📋 Quick Templates:", style="font-weight: bold; font-size: 10px; display: block; margin-bottom: 4px;"),
                Bonito.DOM.span("Select Template:", style=LABEL_STYLE),
                cat_var_dropdown,
                Bonito.DOM.div(
                    Bonito.DOM.span("• condition (A, B)", style="font-size: 9px; color: #888; font-family: monospace; display: block;"),
                    Bonito.DOM.span("• stimulus_type (face, car, house)", style="font-size: 9px; color: #888; font-family: monospace; display: block;"),
                    Bonito.DOM.span("• task (visual, auditory, tactile)", style="font-size: 9px; color: #888; font-family: monospace; display: block;"),
                    Bonito.DOM.span("• emotion (happy, sad, neutral, angry)", style="font-size: 9px; color: #888; font-family: monospace; display: block;"),
                    Bonito.DOM.span("• color (red, green, blue)", style="font-size: 9px; color: #888; font-family: monospace; display: block; margin-bottom: 4px;"),
                    style="padding: 4px; background: #f9f9f9; border-radius: 3px; margin-top: 4px; margin-bottom: 4px;"
                ),
                add_cat_var_button,
                style="padding: 6px; background: #e8f5e9; border-radius: 4px; margin-bottom: 8px;"
            ),
            Bonito.DOM.div(
                Bonito.DOM.span("✏️ Create Custom:", style="font-weight: bold; font-size: 10px; display: block; margin-bottom: 4px;"),
                Bonito.DOM.span("Variable Name:", style=LABEL_STYLE), custom_cat_name,
                Bonito.DOM.span("Levels (comma-separated):", style=LABEL_STYLE), custom_cat_levels,
                Bonito.DOM.span("Example: object_type → chair, table, lamp, desk",
                    style="font-size: 9px; color: #888; font-style: italic; margin-top: 2px; display: block;"),
                Bonito.DOM.div(add_custom_cat_button, style="margin-top: 6px;"),
                style="padding: 6px; background: #fff3e0; border-radius: 4px; margin-bottom: 8px;"
            ),
            Bonito.DOM.div(
                Bonito.DOM.span("🗑️ Remove Variable:", style="font-weight: bold; font-size: 10px; display: block; margin-bottom: 4px;"),
                remove_cat_var_dropdown,
                Bonito.DOM.div(remove_cat_var_button, style="margin-top: 6px;"),
                style="padding: 6px; background: #ffebee; border-radius: 4px;"
            ),
            style="padding: 8px; background: #e3f2fd; border-radius: 4px; margin-bottom: 12px;"
        ),
        
        # Continuous Section
        Bonito.DOM.div(
            Bonito.DOM.span("📈 Continuous Variables", style="font-weight: bold; font-size: 11px; display: block; margin-bottom: 8px;"),
            Bonito.DOM.div(
                Bonito.DOM.span("📋 Quick Templates:", style="font-weight: bold; font-size: 10px; display: block; margin-bottom: 4px;"),
                Bonito.DOM.span("Select Template:", style=LABEL_STYLE), cont_var_dropdown,
                Bonito.DOM.div(
                    Bonito.DOM.span("• intensity (0.0 to 10.0, 5 steps)", style="font-size: 9px; color: #888; font-family: monospace; display: block;"),
                    Bonito.DOM.span("• contrast (0.0 to 1.0, 10 steps)", style="font-size: 9px; color: #888; font-family: monospace; display: block;"),
                    Bonito.DOM.span("• duration (100.0 to 500.0, 5 steps)", style="font-size: 9px; color: #888; font-family: monospace; display: block;"),
                    Bonito.DOM.span("• frequency (1.0 to 20.0, 10 steps)", style="font-size: 9px; color: #888; font-family: monospace; display: block; margin-bottom: 4px;"),
                    style="padding: 4px; background: #f9f9f9; border-radius: 3px; margin-top: 4px; margin-bottom: 4px;"
                ),
                add_cont_var_button,
                style="padding: 6px; background: #e8f5e9; border-radius: 4px; margin-bottom: 8px;"
            ),
            Bonito.DOM.div(
                Bonito.DOM.span("✏️ Create Custom:", style="font-weight: bold; font-size: 10px; display: block; margin-bottom: 4px;"),
                Bonito.DOM.span("Variable Name:", style=LABEL_STYLE), custom_cont_name,
                Bonito.DOM.span("Min Value:", style=LABEL_STYLE), custom_cont_min,
                Bonito.DOM.span("Max Value:", style=LABEL_STYLE), custom_cont_max,
                Bonito.DOM.span("Number of Steps:", style=LABEL_STYLE), custom_cont_steps,
                Bonito.DOM.span("Example: temperature → 20.0 to 40.0, 8 steps",
                    style="font-size: 9px; color: #888; font-style: italic; margin-top: 2px; display: block;"),
                Bonito.DOM.div(add_custom_cont_button, style="margin-top: 6px;"),
                style="padding: 6px; background: #fff3e0; border-radius: 4px; margin-bottom: 8px;"
            ),
            Bonito.DOM.div(
                Bonito.DOM.span("🗑️ Remove Variable:", style="font-weight: bold; font-size: 10px; display: block; margin-bottom: 4px;"),
                remove_cont_var_dropdown,
                Bonito.DOM.div(remove_cont_var_button, style="margin-top: 6px;"),
                style="padding: 6px; background: #ffebee; border-radius: 4px;"
            ),
            style="padding: 8px; background: #fff3e0; border-radius: 4px; margin-bottom: 12px;"
        ),
        
        # Display Current Variables
        Bonito.DOM.div(
            Bonito.DOM.span(event_variables_display, style="font-size: 10px; color: #333; white-space: pre-wrap; font-family: monospace;"),
            style="padding: 8px; background: #f5f5f5; border-radius: 4px; border-left: 3px solid #4CAF50; margin-bottom: 8px;"
        ),
        
        # Formula Examples
        Bonito.DOM.div(
            Bonito.DOM.span("📝 Formula Examples (use your variable names):", style="font-weight: bold; font-size: 10px; display: block; margin-bottom: 4px;"),
            Bonito.DOM.span("• @formula(0 ~ 1)", style="font-size: 9px; display: block; font-family: monospace;"),
            Bonito.DOM.span("  → Intercept only (no effects)", style="font-size: 9px; display: block; color: #666; margin-left: 12px; margin-bottom: 2px;"),
            Bonito.DOM.span("• @formula(0 ~ 1 + your_variable)", style="font-size: 9px; display: block; font-family: monospace;"),
            Bonito.DOM.span("  → Effect of your categorical/continuous variable", style="font-size: 9px; display: block; color: #666; margin-left: 12px; margin-bottom: 2px;"),
            Bonito.DOM.span("• @formula(0 ~ 1 + var1 + var2)", style="font-size: 9px; display: block; font-family: monospace;"),
            Bonito.DOM.span("  → Both variables affect amplitude", style="font-size: 9px; display: block; color: #666; margin-left: 12px; margin-bottom: 2px;"),
            style="padding: 6px; background: #f0f4ff; border-radius: 3px; margin-bottom: 8px;"
        ),
        
        # Status
        Bonito.DOM.div(
            Bonito.DOM.span(event_status, style="font-size: 10px; font-weight: bold; color: #666;"),
            style="padding: 6px; background: #fafafa; border-radius: 4px;"
        )
    )
    
    return (
        categorical_variables = categorical_variables,
        continuous_variables = continuous_variables,
        event_definition_ui = event_definition_ui
    )
end