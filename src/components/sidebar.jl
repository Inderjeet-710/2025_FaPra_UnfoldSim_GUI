"""
Sidebar Layout Component

Assembles all control panels into the left sidebar.
"""

using Bonito
using Observables
using JSON3
using Dates

"""
    create_sidebar(session, params...)

Create complete sidebar with all control panels.

Returns: sidebar DOM element
"""
function create_sidebar(session, status_text, event_definition_ui, design_config_ui,
                       model_ui, onset_choice, onset_ui, noise_choice, noise_lvl,
                       noise_throttled, download_sim_button, upload_sim_file_input,
                       data_mgmt_status, download_button, results, sliders_dict,
                       upload_file_content, upload_processing_flag)
    
    # Download configuration handler
    on(download_button.value) do _
        try
            config = Dict{String, Any}()
            for (key, obs) in sliders_dict
                config[key] = obs[]
            end
            
            json_str = JSON3.write(config)
            blob_url = Bonito.create_blob_url(session, json_str, "application/json")
            Bonito.download_file(session, blob_url, "expexplorer_config.json")
        catch e
            println("Error during configuration download: $(sprint(showerror, e))")
        end
    end
    
    # Download simulation data handler
    on(download_sim_button.value) do _
        try
            res = results[]
            if res.err != ""
                data_mgmt_status[] = "❌ Error: Cannot save faulty simulation"
                return
            end
            
            config_to_save = Dict{String, Any}()
            for (key, obs) in sliders_dict
                config_to_save[key] = obs[]
            end
            
            msg = download_sim_files_smart(res, config_to_save)
            data_mgmt_status[] = "✓ Saved to: $(pwd())"
            println("Files saved in: $(pwd())")
            println(msg)
        catch e
            data_mgmt_status[] = "✗ Error: $e"
            @error "Failed to save" exception=(e, catch_backtrace())
        end
    end
    
    # Upload file handler
    on(upload_sim_file_input.value) do file_paths
        println("\n" * "="^70)
        println("🔔 UPLOAD TRIGGERED at $(Dates.now())")
        println("="^70)
        
        if upload_processing_flag[]
            println("⚠️ Already processing")
            data_mgmt_status[] = "⚠️ Processing..."
            return
        end
        
        try
            if isempty(file_paths) || isempty(file_paths[1])
                data_mgmt_status[] = "❌ No file selected"
                println("❌ No file selected")
                return
            end
            
            upload_processing_flag[] = true
            blob_url = file_paths[1]
            println("📂 Blob URL: $blob_url")
            data_mgmt_status[] = "⏳ Loading file..."
            
            Bonito.evaljs(session, Bonito.js"""
                console.log('🔧 UPLOAD HANDLER RUNNING');
                fetch($blob_url)
                    .then(response => { return response.text(); })
                    .then(text => {
                        console.log('✅ Loaded:', text.length, 'chars');
                        $(upload_file_content).notify(text);
                    })
                    .catch(err => {
                        console.error('❌ Fetch failed:', err);
                        $(data_mgmt_status).notify("❌ Fetch failed");
                        $(upload_processing_flag).notify(false);
                    });
            """)
            
            println("✅ JavaScript sent")
        catch e
            println("❌ Upload error: $e")
            data_mgmt_status[] = "❌ Error: $e"
            upload_processing_flag[] = false
            showerror(stdout, e, catch_backtrace())
        end
    end
    
    # Build sidebar UI
    sidebar = Bonito.DOM.div(
        # Header
        Bonito.DOM.div(
            Bonito.DOM.img(
                src="https://github.com/unfoldtoolbox/UnfoldSim.jl/blob/assets/docs/src/assets/UnfoldSim_features_animation.gif?raw=true",
                style="width:240px; max-width:100%; vertical-align:middle; margin-right:40px"
            ),
            Bonito.DOM.h3("UnfoldSim.jl Dashboard", 
                style="display:inline-block; vertical-align:middle; font-size: 15px;"),
            style="margin-bottom: 16px;"
        ),
        
        # Status & Export
        Bonito.DOM.div(
            Bonito.DOM.h4("Status & Export", style="font-size: 13px; margin: 6px 0;"),
            Bonito.DOM.span(status_text, 
                style="font-size: 12px; font-weight: bold; color: #444;"),
            Bonito.DOM.br(),
            Bonito.DOM.br(),
            download_button,
            style=CARD_STYLE
        ),
        
        # 0. Event Definition
        Bonito.DOM.div(
            Bonito.DOM.h4("0. Event Definition", style="font-size: 13px;"),
            event_definition_ui,
            style=CARD_STYLE
        ),
        
        # 1. Design Configuration
        Bonito.DOM.div(
            Bonito.DOM.h4("1. Design Configuration", style="font-size: 13px;"),
            design_config_ui,
            style=CARD_STYLE
        ),
        
        # 2. Component Configuration
        Bonito.DOM.div(
            Bonito.DOM.h4("2. Component configuration", style="font-size: 13px;"),
            model_ui,
            style=CARD_STYLE
        ),
        
        # 3. Onset Configuration
        Bonito.DOM.div(
            Bonito.DOM.h4("3. Onset Configuration", style="font-size: 13px;"),
            onset_choice,
            onset_ui,
            style=CARD_STYLE
        ),
        
        # 4. Global Noise
        Bonito.DOM.div(
            Bonito.DOM.h4("4. Global Noise", style="font-size: 13px;"),
            noise_choice,
            Bonito.DOM.span(
                Bonito.map(v -> "Noise Level: $(round(map_to_noise(v), digits=2))", noise_throttled),
                style=LABEL_STYLE
            ),
            noise_lvl,
            style=CARD_STYLE
        ),
        
        # 5. Data Management
        Bonito.DOM.div(
            Bonito.DOM.h4("5. Data Management", style="font-size: 13px;"),
            Bonito.DOM.div(download_sim_button, style="margin-bottom: 8px;"),
            Bonito.DOM.div(
                Bonito.DOM.span("📂 Upload Saved Simulation:", style=LABEL_STYLE),
                upload_sim_file_input,
                style="margin-bottom: 8px;"
            ),
            Bonito.DOM.div(
                Bonito.DOM.span(data_mgmt_status,
                    style="font-size: 11px; font-weight: bold; color: #2196F3; word-wrap: break-word;"),
                style="padding: 8px; background: #e3f2fd; border-radius: 4px; border-left: 3px solid #2196F3; margin-top: 8px;"
            ),
            style=CARD_STYLE
        ),
        
        style="grid-column: 1; padding: 8px; background: #f9f9f9; border-right: 1px solid #ddd; height: 100vh; overflow-y: auto; box-sizing: border-box;"
    )
    
    return sidebar
end