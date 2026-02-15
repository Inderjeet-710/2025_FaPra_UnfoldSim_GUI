"""
Component Tab Management

Handles multiple ERP component tabs (P100, N170, P300, N400, Custom).
"""

using Bonito
using Observables

"""
    create_tab_manager(session)

Create tab management system for multiple ERP components.

Returns: Named tuple with tab-related observables and UI
"""
function create_tab_manager(session)
    # Observables
    component_tabs = Observable(ComponentTab[])
    active_tab_id = Observable("")
    tab_counter = Ref(0)
    
    # Active values (shared across tabs)
    active_beta_value = Observable(50)
    active_contrast_value = Observable(50)
    active_sigma_value = Observable(20)
    active_basis_value = Observable("hanning(40, 0, 100)")
    active_formula_value = Observable("@formula(0 ~ 1 + condition)")
    active_projection_value = Observable("[1.0, 0.5, -0.2]")
    active_contrast_type_value = Observable("DummyCoding")
    active_model_category = Observable("Linear Model")
    
    all_tab_results = Observable(Dict{String, Any}())
    
    # Global preset dropdown
    global_hanning_preset = Bonito.Dropdown(HANNING_PRESET_OPTIONS; index=1)
    
    """
    Create a new component tab
    """
    function create_new_tab(preset_name::String)
        try
            tab_counter[] += 1
            tab_id = "tab_$(tab_counter[])"
            
            # Create UI widgets
            model_cat = Bonito.Dropdown(["Linear Model", "Mixed Model", "Multi-channel Model"]; index=1)
            
            presets = HANNING_PRESET_OPTIONS
            preset_idx = findfirst(==(preset_name), presets)
            preset_idx = preset_idx === nothing ? 1 : preset_idx
            hanning_pre = Bonito.Dropdown(presets; index=preset_idx)
            
            contrast_t = Bonito.Dropdown(["DummyCoding", "EffectsCoding"]; index=1)
            
            # Set default values based on preset
            if preset_name == "Custom"
                default_beta = 50
                basis_text = "hanning(40, 0, 100)"
            elseif preset_name == "N170 (Negative)"
                default_beta = 40
                basis_text = "-hanning(20, 15, 100)"
            elseif preset_name == "N400 (Negative)"
                default_beta = 35
                basis_text = "-hanning(50, 35, 100)"
            elseif preset_name == "P100 (Positive)"
                default_beta = 60
                basis_text = "hanning(15, 8, 100)"
            else  # P300
                default_beta = 65
                basis_text = "hanning(40, 25, 100)"
            end
            
            basis_t = Bonito.TextField(basis_text)
            formula_t = Bonito.TextField("@formula(0 ~ 1 + condition)")
            projection_t = Bonito.TextField("[1.0, 0.5, -0.2]")
            
            beta_s = Bonito.Slider(0:1:100; value=default_beta)
            contrast_s = Bonito.Slider(0:1:100; value=50)
            mixed_s = Bonito.Slider(0:1:100; value=20)
            
            # Setup preset dropdown handler
            on(hanning_pre.value) do val
                if val == "Custom"
                    basis_t.value[] = "hanning(40, 0, 100)"
                elseif val == "N170 (Negative)"
                    basis_t.value[] = "-hanning(20, 15, 100)"
                elseif val == "N400 (Negative)"
                    basis_t.value[] = "-hanning(50, 35, 100)"
                elseif val == "P100 (Positive)"
                    basis_t.value[] = "hanning(15, 8, 100)"
                elseif val == "P300 (Positive)"
                    basis_t.value[] = "hanning(40, 25, 100)"
                end
                notify(basis_t.value)
            end
            
            if preset_name != "Custom"
                notify(hanning_pre.value)
            end
            
            # Create tab object
            new_tab = ComponentTab(tab_id, preset_name, model_cat, hanning_pre, contrast_t,
                basis_t, formula_t, projection_t, beta_s, contrast_s, mixed_s, nothing)
            
            # Wire up observables to active values
            on(beta_s.value) do val
                if new_tab.id == active_tab_id[]
                    active_beta_value[] = val
                end
            end
            on(contrast_s.value) do val
                if new_tab.id == active_tab_id[]
                    active_contrast_value[] = val
                end
            end
            on(mixed_s.value) do val
                if new_tab.id == active_tab_id[]
                    active_sigma_value[] = val
                end
            end
            on(basis_t.value) do val
                if new_tab.id == active_tab_id[]
                    active_basis_value[] = val
                end
            end
            on(formula_t.value) do val
                if new_tab.id == active_tab_id[]
                    active_formula_value[] = val
                end
            end
            on(projection_t.value) do val
                if new_tab.id == active_tab_id[]
                    active_projection_value[] = val
                end
            end
            on(contrast_t.value) do val
                if new_tab.id == active_tab_id[]
                    active_contrast_type_value[] = val
                end
            end
            on(model_cat.value) do val
                if new_tab.id == active_tab_id[]
                    active_model_category[] = val
                end
            end
            
            # Add to tabs and set as active
            current_tabs = component_tabs[]
            push!(current_tabs, new_tab)
            active_tab_id[] = tab_id
            component_tabs[] = current_tabs
            
            # Update active values
            active_beta_value[] = beta_s.value[]
            active_contrast_value[] = contrast_s.value[]
            active_sigma_value[] = mixed_s.value[]
            active_basis_value[] = basis_t.value[]
            active_formula_value[] = formula_t.value[]
            active_projection_value[] = projection_t.value[]
            active_contrast_type_value[] = contrast_t.value[]
            active_model_category[] = model_cat.value[]
            
            return new_tab
        catch e
            println("Error creating tab for preset=\"$preset_name\": $(sprint(showerror, e))")
            rethrow(e)
        end
    end
    
    # Create initial tab
    create_new_tab("Custom")
    
    # Global preset dropdown handler
    on(global_hanning_preset.value) do val
        existing = findfirst(t -> t.name == val, component_tabs[])
        if existing !== nothing
            active_tab_id[] = component_tabs[][existing].id
        else
            create_new_tab(val)
        end
    end
    
    # Update active values when tab changes
    on(active_tab_id) do active_id
        tabs = component_tabs[]
        tab_idx = findfirst(t -> t.id == active_id, tabs)
        if tab_idx !== nothing
            tab = tabs[tab_idx]
            active_beta_value[] = tab.beta_slider.value[]
            active_contrast_value[] = tab.contrast_slider.value[]
            active_sigma_value[] = tab.mixed_sigma.value[]
            active_basis_value[] = tab.basis_txt.value[]
            active_formula_value[] = tab.formula_txt.value[]
            active_projection_value[] = tab.projection_txt.value[]
            active_contrast_type_value[] = tab.contrast_type.value[]
            active_model_category[] = tab.model_category.value[]
        end
    end
    
    # Tab bar UI
    tab_bar_ui = create_tab_bar_ui(component_tabs, active_tab_id)
    
    # Tab content UI
    current_tab_container = Observable{Any}(nothing)
    
    tab_content_ui = map(component_tabs, active_tab_id) do tabs, active_id
        tab_idx = findfirst(t -> t.id == active_id, tabs)
        if tab_idx === nothing
            return Bonito.DOM.div("No active tab")
        end
        
        current_tab = tabs[tab_idx]
        current_tab_container[] = current_tab
        
        beta_label = map(current_tab.beta_slider.value) do v
            "β (Intercept): $(round(map_to_beta(v), digits=2))"
        end
        contrast_label = map(current_tab.contrast_slider.value) do v
            "Contrast: $(round(map_to_contrast(v), digits=2))"
        end
        sigma_label = map(current_tab.mixed_sigma.value) do v
            "σs (Random Effect): $(round(map_to_sigma(v), digits=2))"
        end
        
        Bonito.DOM.div(
            Bonito.DOM.span("Hanning Presets", style=LABEL_STYLE),
            current_tab.hanning_preset,
            Bonito.DOM.span("Basis Function", style=LABEL_STYLE),
            current_tab.basis_txt,
            
            # Linear Model controls
            Bonito.DOM.div(
                Bonito.DOM.span("Contrast Coding", style=LABEL_STYLE),
                current_tab.contrast_type,
                Bonito.DOM.span("Formula (use event variables)", style=LABEL_STYLE),
                current_tab.formula_txt,
                Bonito.DOM.span(beta_label, style=LABEL_STYLE),
                current_tab.beta_slider,
                Bonito.DOM.span(contrast_label, style=LABEL_STYLE),
                current_tab.contrast_slider,
                style=map(m -> m == "Linear Model" ? "" : "display: none;", current_tab.model_category.value)
            ),
            
            # Mixed Model controls
            Bonito.DOM.div(
                Bonito.DOM.span("Contrast Coding", style=LABEL_STYLE),
                current_tab.contrast_type,
                Bonito.DOM.span("Formula (use event variables)", style=LABEL_STYLE),
                current_tab.formula_txt,
                Bonito.DOM.span(beta_label, style=LABEL_STYLE),
                current_tab.beta_slider,
                Bonito.DOM.span(sigma_label, style=LABEL_STYLE),
                current_tab.mixed_sigma,
                style=map(m -> m == "Mixed Model" ? "" : "display: none;", current_tab.model_category.value)
            ),
            
            # Multi-channel Model controls
            Bonito.DOM.div(
                Bonito.DOM.span("Projection Vector", style=LABEL_STYLE),
                current_tab.projection_txt,
                style=map(m -> m == "Multi-channel Model" ? "" : "display: none;", current_tab.model_category.value)
            )
        )
    end
    
    # Model UI
    model_ui = Bonito.DOM.div(
        Bonito.DOM.span("Select Hanning Preset to Create Tab:", style=LABEL_STYLE),
        global_hanning_preset,
        Bonito.DOM.br(),
        Bonito.DOM.br(),
        tab_bar_ui,
        Bonito.DOM.div(
            Bonito.DOM.div(
                Bonito.DOM.span("Model Type", style=LABEL_STYLE),
                Bonito.map(component_tabs, active_tab_id) do tabs, active_id
                    tab_idx = findfirst(t -> t.id == active_id, tabs)
                    return tab_idx !== nothing ? tabs[tab_idx].model_category : Bonito.DOM.div()
                end,
                style="margin-bottom: 10px;"
            ),
            tab_content_ui,
            style="padding: 15px; background: #fff; border: 1px solid #ddd; border-top: none; border-radius: 0 0 4px 4px;"
        )
    )
    
    return (
        component_tabs = component_tabs,
        active_tab_id = active_tab_id,
        active_beta_value = active_beta_value,
        active_contrast_value = active_contrast_value,
        active_sigma_value = active_sigma_value,
        active_basis_value = active_basis_value,
        active_formula_value = active_formula_value,
        active_projection_value = active_projection_value,
        active_contrast_type_value = active_contrast_type_value,
        active_model_category = active_model_category,
        all_tab_results = all_tab_results,
        model_ui = model_ui,
        create_new_tab = create_new_tab
    )
end