"""
UnfoldSim Dashboard - Main Application Assembly

Coordinates all components into the complete dashboard interface.
"""

# Disable logging for cleaner output
import Logging
Logging.disable_logging(Logging.Info)
Logging.disable_logging(Logging.Warn)

# Load dependencies
using Bonito
using WGLMakie
using UnfoldSim
using DataFrames
using Distributions
using Random
using Statistics
using Observables
using StatsModels
using ColorSchemes
using Colors
using JSON3
using Dates
using CSV
using JLD2

# Include all source modules in dependency order
include("types.jl")
include("constants.jl")
include("hartmut.jl")
include("erp_analysis.jl")
include("utils.jl")
include("io_system.jl")
include("viz_utils.jl")
include("ui_components.jl")

# Include component modules
include("components/event_manager.jl")
include("components/tab_manager.jl")
include("components/simulation_engine.jl")
include("components/main_plot.jl")
include("components/onset_plot.jl")
include("components/topoplot.jl")
include("components/sidebar.jl")

# ============================================================================
# MAIN APPLICATION
# ============================================================================

"""
Main application factory function
"""
app = Bonito.App() do session
    println("\n" * "="^70)
    println("🎨 Building UnfoldSim Dashboard...")
    println("="^70)
    
    # ========================================================================
    # INITIALIZE ELECTRODE SYSTEM
    # ========================================================================
    
    ELECTRODE_POSITIONS = get_electrode_positions()
    N_CHANNELS = length(ELECTRODE_POSITIONS)
    channel_names_list_temp = collect(keys(ELECTRODE_POSITIONS))
    
    CLEAN_SIGNAL_CHANNEL_IDX = findfirst(==(CLEAN_SIGNAL_CHANNEL_NAME), channel_names_list_temp)
    if CLEAN_SIGNAL_CHANNEL_IDX === nothing
        @warn "Electrode '$(CLEAN_SIGNAL_CHANNEL_NAME)' not found in HArtMuT model, using index 1"
        CLEAN_SIGNAL_CHANNEL_IDX = 1
    else
        println("✓ Clean signal electrode: $(CLEAN_SIGNAL_CHANNEL_NAME) at index $(CLEAN_SIGNAL_CHANNEL_IDX)")
    end
    
    elec_pos = ELECTRODE_POSITIONS
    channel_names_list = collect(keys(elec_pos))
    rainbow_colors = [get(ColorSchemes.jet, (i-1)/max(N_CHANNELS-1, 1)) for i in 1:N_CHANNELS]
    
    # ========================================================================
    # CREATE EVENT MANAGER
    # ========================================================================
    
    println("📊 Creating event variable manager...")
    event_mgr = create_event_manager(session)
    categorical_variables = event_mgr.categorical_variables
    continuous_variables = event_mgr.continuous_variables
    event_definition_ui = event_mgr.event_definition_ui
    
    # ========================================================================
    # CREATE TAB MANAGER
    # ========================================================================
    
    println("📑 Creating component tab manager...")
    tab_mgr = create_tab_manager(session)
    component_tabs = tab_mgr.component_tabs
    active_tab_id = tab_mgr.active_tab_id
    active_beta_value = tab_mgr.active_beta_value
    active_contrast_value = tab_mgr.active_contrast_value
    active_sigma_value = tab_mgr.active_sigma_value
    active_basis_value = tab_mgr.active_basis_value
    active_formula_value = tab_mgr.active_formula_value
    active_projection_value = tab_mgr.active_projection_value
    active_contrast_type_value = tab_mgr.active_contrast_type_value
    active_model_category = tab_mgr.active_model_category
    all_tab_results = tab_mgr.all_tab_results
    model_ui = tab_mgr.model_ui
    
    # ========================================================================
    # SIMULATION PARAMETERS & UI CONTROLS
    # ========================================================================
    
    println("⚙️  Setting up simulation controls...")
    
    # Dropdown controls
    onset_choice = Bonito.Dropdown(["Uniform", "Log Normal", "No Onset"]; index=1)
    noise_choice = Bonito.Dropdown(["No Noise", "White", "Pink", "Red"]; index=1)
    
    # File I/O controls
    download_button = Bonito.Button("Download Configuration")
    download_sim_button = Bonito.Button("Download Simulation Object")
    upload_sim_file_input = Bonito.FileInput(Observable(String[]), true)
    data_mgmt_status = Observable("")
    upload_file_content = Observable{String}("")
    upload_processing_flag = Observable(false)
    
    # Sliders
    time_slider = Bonito.Slider(1:1:500; value=100)
    n_subjects = Bonito.Slider(0:1:100; value=10)
    n_items = Bonito.Slider(0:1:100; value=20)
    on_mu = Bonito.Slider(0:1:100; value=17)
    on_sigma = Bonito.Slider(0:1:100; value=44)
    on_offset = Bonito.Slider(0:1:100; value=10)
    on_truncate_lower = Bonito.Slider(0:1:100; value=0)
    on_truncate = Bonito.Slider(0:1:100; value=44)
    u_width = Bonito.Slider(0:1:100; value=21)
    u_offset_uni = Bonito.Slider(0:1:100; value=10)
    noise_lvl = Bonito.Slider(0:1:100; value=15)
    
    # Design category
    design_category = Observable("Single-subject design")
    
    # Auto-adjust design for Mixed Model
    on(active_model_category) do m
        if m == "Mixed Model"
            design_category[] = "Multi-subject design"
        else
            design_category[] = "Single-subject design"
        end
    end
    
    # Throttled observables for performance
    time_slider_throttled = throttle(THROTTLE_DT, time_slider.value)
    subjects_throttled = throttle(SLIDER_THROTTLE, n_subjects.value)
    items_throttled = throttle(SLIDER_THROTTLE, n_items.value)
    mu_throttled = throttle(SLIDER_THROTTLE, on_mu.value)
    sigma_onset_throttled = throttle(SLIDER_THROTTLE, on_sigma.value)
    offset_throttled = throttle(SLIDER_THROTTLE, on_offset.value)
    trl_throttled = throttle(SLIDER_THROTTLE, on_truncate_lower.value)
    tr_throttled = throttle(SLIDER_THROTTLE, on_truncate.value)
    width_throttled = throttle(SLIDER_THROTTLE, u_width.value)
    uoff_throttled = throttle(SLIDER_THROTTLE, u_offset_uni.value)
    noise_throttled = throttle(SLIDER_THROTTLE, noise_lvl.value)
    active_beta_throttled = throttle(SLIDER_THROTTLE, active_beta_value)
    active_contrast_throttled = throttle(SLIDER_THROTTLE, active_contrast_value)
    active_sigma_throttled = throttle(SLIDER_THROTTLE, active_sigma_value)
    
    # Selected channels and hannings
    selected_channels = Observable(Set{Int}([CLEAN_SIGNAL_CHANNEL_IDX]))
    selected_hannings = Observable(Set{String}())
    
    # Hanning checkboxes
    p100_checkbox = Bonito.Checkbox(false)
    n170_checkbox = Bonito.Checkbox(false)
    n400_checkbox = Bonito.Checkbox(false)
    p300_checkbox = Bonito.Checkbox(false)
    
    onany(p100_checkbox.value, n170_checkbox.value, n400_checkbox.value, p300_checkbox.value) do p100, n170, n400, p300
        s = Set{String}()
        if p100; push!(s, "P100 (Positive)"); end
        if n170; push!(s, "N170 (Negative)"); end
        if n400; push!(s, "N400 (Negative)"); end
        if p300; push!(s, "P300 (Positive)"); end
        selected_hannings[] = s
    end
    
    # ========================================================================
    # DESIGN CONFIGURATION UI
    # ========================================================================
    
    design_dropdown = Bonito.Dropdown(DESIGN_DROPDOWN_OPTIONS; index=1)
    
    on(design_dropdown.value) do val
        design_category[] = val
    end
    
    on(design_category) do val
        idx = findfirst(==(val), DESIGN_DROPDOWN_OPTIONS)
        if idx !== nothing && design_dropdown.value[] != val
            design_dropdown.value[] = val
        end
    end
    
    design_config_ui = Bonito.map(active_model_category, design_category, items_throttled, subjects_throttled) do m, d, ni_gui, ns_gui
        if m == "Mixed Model"
            Bonito.DOM.div(
                Bonito.DOM.span("Multi-subject design (required for Mixed Model)",
                    style="font-size: 16px; color: #ff6600; font-weight: bold;"),
                Bonito.DOM.div(
                    Bonito.DOM.span("Subjects: $(map_to_subjects(ns_gui))", style=LABEL_STYLE), n_subjects,
                    Bonito.DOM.span("Items: $(map_to_items(ni_gui))", style=LABEL_STYLE), n_items
                )
            )
        else
            Bonito.DOM.div(
                Bonito.DOM.span("Design Type", style=LABEL_STYLE), design_dropdown,
                Bonito.DOM.div(
                    Bonito.DOM.span("Single-subject configuration active.", 
                        style="font-style:italic; color:#888"),
                    style=d == "Single-subject design" ? "" : "display: none;"
                ),
                Bonito.DOM.div(
                    Bonito.DOM.span("Repeats: $(map_to_items(ni_gui))", style=LABEL_STYLE), n_items,
                    style=d == "Repeat design" ? "" : "display: none;"
                ),
                Bonito.DOM.div(
                    Bonito.DOM.span("Subjects: $(map_to_subjects(ns_gui))", style=LABEL_STYLE), n_subjects,
                    Bonito.DOM.span("Items: $(map_to_items(ni_gui))", style=LABEL_STYLE), n_items,
                    style=d == "Multi-subject design" ? "" : "display: none;"
                )
            )
        end
    end
    
    # ========================================================================
    # ONSET CONFIGURATION UI
    # ========================================================================
    
    onset_ui = Bonito.map(onset_choice.value, mu_throttled, sigma_onset_throttled, offset_throttled,
                          trl_throttled, tr_throttled, width_throttled, uoff_throttled) do o, mu_gui, sig_gui, off_gui, trl_gui, tr_gui, w_gui, uoff_gui
        if o == "No Onset"
            Bonito.DOM.span("No parameters needed.", style="font-style:italic; color:#888")
        elseif o == "Uniform"
            Bonito.DOM.div(
                Bonito.DOM.span("Width: $(map_to_width(w_gui))", style=LABEL_STYLE), u_width,
                Bonito.DOM.span("Offset: $(map_to_offset(uoff_gui))", style=LABEL_STYLE), u_offset_uni
            )
        else  # Log Normal
            Bonito.DOM.div(
                Bonito.DOM.span("μ (Mu): $(round(map_to_mu(mu_gui), digits=2))", style=LABEL_STYLE), on_mu,
                Bonito.DOM.span("σ (Sigma): $(round(map_to_onset_sigma(sig_gui), digits=2))", style=LABEL_STYLE), on_sigma,
                Bonito.DOM.span("Offset: $(map_to_offset(off_gui))", style=LABEL_STYLE), on_offset,
                Bonito.DOM.span("Truncate Lower: $(map_to_truncate_lower(trl_gui))", style=LABEL_STYLE), on_truncate_lower,
                Bonito.DOM.span("Truncate Upper: $(map_to_truncate(tr_gui))", style=LABEL_STYLE), on_truncate
            )
        end
    end
    
    # ========================================================================
    # CREATE SIMULATION ENGINE
    # ========================================================================
    
    println("🔬 Creating simulation engine...")
    sim_engine = create_simulation_engine(
        session, categorical_variables, continuous_variables,
        active_model_category, design_category,
        onset_choice, noise_choice,
        active_beta_throttled, active_contrast_throttled, active_sigma_throttled,
        subjects_throttled, items_throttled,
        mu_throttled, sigma_onset_throttled, offset_throttled,
        trl_throttled, tr_throttled, width_throttled, uoff_throttled,
        noise_throttled, active_contrast_type_value,
        active_basis_value, active_formula_value, active_projection_value,
        component_tabs, active_tab_id, all_tab_results,
        N_CHANNELS, CLEAN_SIGNAL_CHANNEL_IDX
    )
    
    results = sim_engine.results
    status_text = sim_engine.status_text
    is_running = sim_engine.is_running
    sim_trigger = sim_engine.sim_trigger
    
    # ========================================================================
    # CREATE UPLOAD FILE HANDLER
    # ========================================================================
    
    println("📤 Setting up file upload handler...")
    
    # Sliders dictionary for config save/load
    sliders_dict = Dict(
        "n_subjects" => n_subjects.value,
        "n_items" => n_items.value,
        "on_mu" => on_mu.value,
        "on_sigma" => on_sigma.value,
        "on_offset" => on_offset.value,
        "on_truncate_lower" => on_truncate_lower.value,
        "on_truncate" => on_truncate.value,
        "u_width" => u_width.value,
        "u_offset_uni" => u_offset_uni.value,
        "noise_lvl" => noise_lvl.value,
        "active_beta_value" => active_beta_value,
        "active_contrast_value" => active_contrast_value,
        "active_sigma_value" => active_sigma_value,
        "onset_choice" => onset_choice.value,
        "noise_choice" => noise_choice.value,
        "design_category" => design_category,
        "active_model_category" => active_model_category,
        "active_contrast_type_value" => active_contrast_type_value,
        "active_basis_value" => active_basis_value,
        "active_formula_value" => active_formula_value,
        "active_projection_value" => active_projection_value
    )
    
    on(upload_file_content) do csv_text
        try
            if isempty(csv_text)
                upload_processing_flag[] = false
                return
            end
            
            println("\n" * "="^70)
            println("📥 PROCESSING UPLOAD ($(length(csv_text)) chars)")
            println("="^70)
            
            data_mgmt_status[] = "⏳ Parsing CSV..."
            
            df, config = parse_uploaded_csv(csv_text)
            
            println("  ✓ CSV: $(nrow(df)) rows × $(ncol(df)) columns")
            println("  ✓ Columns: $(names(df))")
            
            if !isempty(config)
                println("\n" * "="^70)
                println("RESTORING CONFIGURATION")
                println("="^70)
                
                restored = 0
                for (key, obs) in sliders_dict
                    if haskey(config, key)
                        try
                            old_val = obs[]
                            new_val = config[key]
                            
                            if isa(new_val, Real)
                                obs[] = convert(Int, round(new_val))
                            elseif isa(new_val, String)
                                obs[] = String(new_val)
                            else
                                obs[] = new_val
                            end
                            
                            restored += 1
                            println("  ✓ $(rpad(key, 25)) $(rpad(string(old_val), 10)) → $(obs[])")
                        catch e
                            println("  ✗ $key: $e")
                        end
                    end
                end
                
                println("="^70)
                println("✅ Restored: $restored / $(length(sliders_dict))")
                println("="^70)
                
                # Trigger updates
                for (key, obs) in sliders_dict
                    notify(obs)
                end
                
                sleep(0.3)
                old_noise = noise_lvl.value[]
                noise_lvl.value[] = old_noise == 0 ? 1 : 0
                sleep(0.1)
                noise_lvl.value[] = old_noise
                
                notify(active_beta_value)
                notify(active_contrast_value)
                notify(component_tabs)
                notify(active_tab_id)
                
                println("✅ GUI updated, simulation triggered")
                println("="^70 * "\n")
                
                data_mgmt_status[] = "✅ LOADED! $restored params restored"
            else
                println("\n⚠️ No config found - loading as data")
                
                if ncol(df) > 1
                    data_matrix = Matrix(df)
                    results[] = (
                        noisy = vec(data_matrix[:, 1]),
                        clean = results[].clean,
                        multichannel_noisy = data_matrix,
                        multichannel_clean = results[].multichannel_clean,
                        time = results[].time,
                        events = results[].events,
                        err = "",
                        onset_params = results[].onset_params
                    )
                    data_mgmt_status[] = "✅ Data loaded (no config)"
                else
                    data_mgmt_status[] = "❌ Invalid format"
                end
            end
            
            upload_processing_flag[] = false
        catch e
            data_mgmt_status[] = "❌ Error: $(string(e)[1:min(80, length(string(e)))])"
            upload_processing_flag[] = false
            println("\n❌ ERROR:")
            showerror(stdout, e, catch_backtrace())
            println("\n")
        end
    end
    
    # ========================================================================
    # CREATE VISUALIZATIONS
    # ========================================================================
    
    println("📈 Creating main plot...")
    main_plot = create_main_plot(
        session, results, all_tab_results, component_tabs,
        selected_hannings, selected_channels, active_model_category,
        time_slider_throttled, channel_names_list, rainbow_colors,
        CLEAN_SIGNAL_CHANNEL_IDX
    )
    fig = main_plot.fig
    legend_content = main_plot.legend_content
    
    println("📊 Creating onset plot...")
    onset_plot_fig = create_onset_plot(session, results)
    
    println("🧠 Creating topoplot...")
    topoplot = create_topoplot(
        session, results, selected_channels, time_slider_throttled,
        active_model_category, elec_pos, channel_names_list,
        CLEAN_SIGNAL_CHANNEL_IDX
    )
    brain_fig = topoplot.brain_fig
    erp_panel_content = topoplot.erp_panel_content
    
    # ========================================================================
    # CREATE SIDEBAR
    # ========================================================================
    
    println("🎛️  Creating sidebar...")
    sidebar = create_sidebar(
        session, status_text, event_definition_ui, design_config_ui,
        model_ui, onset_choice, onset_ui, noise_choice, noise_lvl,
        noise_throttled, download_sim_button, upload_sim_file_input,
        data_mgmt_status, download_button, results, sliders_dict,
        upload_file_content, upload_processing_flag
    )
    
    # ========================================================================
    # ASSEMBLE LAYOUT
    # ========================================================================
    
    println("🎨 Assembling final layout...")
    
    center_panel = Bonito.DOM.div(
        Bonito.DOM.div(
            fig,
            legend_content,
            style="margin-bottom: 20px; max-width:100%; overflow: hidden; box-sizing: border-box;"
        ),
        Bonito.DOM.div(
            onset_plot_fig,
            style="padding: 10px; background: #fff; border: 1px solid #e0e0e0; border-radius: 8px; max-width:100%; overflow: hidden; box-sizing: border-box;"
        ),
        style="grid-column: 2; padding: 16px; overflow: auto; box-sizing: border-box;"
    )
    
    erp_panel = Bonito.DOM.div(
        erp_panel_content,
        style="grid-column: 3; padding: 10px; background: #fff; border-left: 1px solid #ddd; overflow-y: auto; overflow-x: hidden; height: 100vh; box-sizing: border-box; width: 100%; max-width: 100%;"
    )
    
    println("="^70)
    println("✅ UnfoldSim Dashboard Ready!")
    println("="^70 * "\n")
    
    # Return final layout
    Bonito.DOM.div(
        sidebar,
        center_panel,
        erp_panel,
        style="""
          display: grid;
          grid-template-columns: minmax(300px, 22vw) minmax(0, 1fr) minmax(300px, 22vw);
          grid-template-rows: 100vh;
          font-family: sans-serif;
          width: 100vw;
          height: 100vh;
          box-sizing: border-box;
          overflow: hidden;
          margin: 0;
          padding: 0;
        """
    )
end

# Export the app
app