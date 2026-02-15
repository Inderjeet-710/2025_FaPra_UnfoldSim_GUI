"""
Core Simulation Engine

Handles ERP simulation execution using UnfoldSim.jl
"""

using UnfoldSim
using Random
using Distributions
using StatsModels
using DataFrames
using Observables

"""
    create_simulation_engine(session, params...)

Create simulation engine with auto-triggering on parameter changes.

Returns: (results, status_text, is_running, sim_trigger)
"""
function create_simulation_engine(session, 
                                  categorical_variables, continuous_variables,
                                  active_model_category, design_category,
                                  onset_choice, noise_choice,
                                  active_beta_throttled, active_contrast_throttled, active_sigma_throttled,
                                  subjects_throttled, items_throttled,
                                  mu_throttled, sigma_onset_throttled, offset_throttled,
                                  trl_throttled, tr_throttled, width_throttled, uoff_throttled,
                                  noise_throttled, active_contrast_type_value,
                                  active_basis_value, active_formula_value, active_projection_value,
                                  component_tabs, active_tab_id, all_tab_results,
                                  N_CHANNELS, CLEAN_SIGNAL_CHANNEL_IDX)
    
    # Observables
    results = Observable((
        noisy=[Point2f(0,0)], 
        clean=[Point2f(0,0)],
        multichannel_noisy=zeros(1,1), 
        multichannel_clean=zeros(1,1),
        time=[0.0], 
        events=DataFrame(), 
        err="",
        onset_params=(choice="No Onset", mu=0.0, sigma=0.0, offset=0, trl=0, tru=0, w=0, uoff=0)
    ))
    
    status_text = Observable("Ready")
    is_running = Observable(false)
    
    # Simulation trigger (debounced)
    sim_trigger = throttle(SIMULATION_DEBOUNCE,
        map((args...) -> sum(hash.(args)),
            active_model_category, design_category, onset_choice.value,
            noise_choice.value, active_beta_throttled, active_contrast_throttled,
            active_sigma_throttled, subjects_throttled, items_throttled,
            mu_throttled, sigma_onset_throttled, offset_throttled,
            trl_throttled, tr_throttled, width_throttled, uoff_throttled,
            noise_throttled, active_contrast_type_value,
            active_basis_value, active_formula_value, active_projection_value,
            categorical_variables, continuous_variables)
    )
    
    # Main simulation handler
    on(sim_trigger) do _
        if is_running[]
            return
        end
        is_running[] = true
        
        m_cat = active_model_category[]
        d_cat = design_category[]
        
        # Validate combination
        if m_cat == "Mixed Model" && (d_cat == "Single-subject design" || d_cat == "Repeat design")
            status_text[] = "ERROR: Invalid Combination"
            results[] = (
                noisy=[Point2f(0,0)], 
                clean=[Point2f(0,0)],
                multichannel_noisy=zeros(1,1), 
                multichannel_clean=zeros(1,1),
                time=[0.0], 
                events=DataFrame(),
                err="Simulation Blocked: Mixed Model requires a Multi-subject design.",
                onset_params=(choice="No Onset", mu=0.0, sigma=0.0, offset=0, trl=0, tru=0, w=0, uoff=0)
            )
            is_running[] = false
            return
        end
        
        try
            status_text[] = "Running..."
            
            # Extract parameters (using throttled values)
            o_cat = onset_choice.value[]
            n_cat = noise_choice.value[]
            b_str = active_basis_value[]
            f_str = active_formula_value[]
            b_gui = active_beta_throttled[]
            c_gui = active_contrast_throttled[]
            s_gui = active_sigma_throttled[]
            ni_gui = items_throttled[]
            ns_gui = subjects_throttled[]
            o_mu_gui = mu_throttled[]
            o_sig_gui = sigma_onset_throttled[]
            o_off_gui = offset_throttled[]
            o_trl_gui = trl_throttled[]
            o_tr_gui = tr_throttled[]
            uw_gui = width_throttled[]
            uoff_gui = uoff_throttled[]
            c_type = active_contrast_type_value[]
            n_lvl_gui = noise_throttled[]
            
            # Map to actual values
            b_val = map_to_beta(b_gui)
            c_val = map_to_contrast(c_gui)
            s_val = map_to_sigma(s_gui)
            ni = map_to_items(ni_gui)
            ns = map_to_subjects(ns_gui)
            o_mu = map_to_mu(o_mu_gui)
            o_sig = map_to_onset_sigma(o_sig_gui)
            o_off = map_to_offset(o_off_gui)
            o_trl = map_to_truncate_lower(o_trl_gui)
            o_tr = map_to_truncate(o_tr_gui)
            uw = map_to_width(uw_gui)
            uoff = map_to_offset(uoff_gui)
            n_lvl = map_to_noise(n_lvl_gui)
            
            # Setup contrasts
            coding = c_type == "DummyCoding" ? DummyCoding() : EffectsCoding()
            contrast_dict = Dict{Symbol, Any}()
            cat_vars = categorical_variables[]
            for (var_name, levels) in cat_vars
                if !isempty(levels)
                    contrast_dict[Symbol(var_name)] = coding
                end
            end
            if isempty(contrast_dict)
                contrast_dict[:condition] = coding
            end
            
            # Build design
            design = build_design_from_events(
                categorical_variables[], continuous_variables[], d_cat, ni, ns)
            
            # Parse formula and basis
            p_formula = if m_cat == "Mixed Model"
                include_string(Main, "@formula(0 ~ 1 + condition + (1 + condition | subject))")
            else
                include_string(Main, f_str)
            end
            p_basis = include_string(Main, b_str)
            
            # Create component
            base_comp = if m_cat == "Mixed Model"
                MixedModelComponent(; basis=p_basis, formula=p_formula, β=[b_val, c_val],
                                    σs=Dict(:subject => [s_val, s_val]), contrasts=contrast_dict)
            elseif m_cat == "Multi-channel Model"
                LinearModelComponent(; basis=p_basis, formula=@formula(0 ~ 1), β=[b_val])
            else
                n_terms = count_formula_terms(f_str, categorical_variables[], continuous_variables[])
                β_vec = Float64[]
                push!(β_vec, b_val)
                for i in 2:n_terms
                    if i == 2
                        push!(β_vec, c_val)
                    else
                        push!(β_vec, c_val * 0.5)
                    end
                end
                println("DEBUG: Formula: $f_str")
                println("DEBUG: Counted $n_terms terms, generated β = $β_vec")
                LinearModelComponent(; basis=p_basis, formula=p_formula, β=β_vec, contrasts=contrast_dict)
            end
            
            # Setup multichannel if needed
            if m_cat == "Multi-channel Model"
                mc1 = UnfoldSim.MultichannelComponent(base_comp, get_hartmut_model() => "Left Postcentral Gyrus")
                mc2 = UnfoldSim.MultichannelComponent(base_comp, get_hartmut_model() => "Right Occipital Pole")
                
                onsets = if o_cat == "Log Normal"
                    LogNormalOnset(; μ=o_mu, σ=o_sig, offset=o_off, truncate_lower=o_trl, truncate_upper=o_tr)
                elseif o_cat == "Uniform"
                    UniformOnset(; width=uw, offset=uoff)
                else
                    NoOnset()
                end
                
                noise = if n_cat == "White"
                    WhiteNoise(; noiselevel=n_lvl)
                elseif n_cat == "Pink"
                    PinkNoise(; noiselevel=n_lvl)
                elseif n_cat == "Red"
                    RedNoise(; noiselevel=n_lvl)
                else
                    NoNoise()
                end
                
                data, events_df = simulate(MersenneTwister(42), design, [mc1, mc2], onsets, noise;
                                           return_epoched=(o_cat == "No Onset"))
                clean, _ = simulate(MersenneTwister(42), design, [mc1, mc2], onsets, NoNoise();
                                   return_epoched=(o_cat == "No Onset"))
            else
                onsets = if o_cat == "Log Normal"
                    LogNormalOnset(; μ=o_mu, σ=o_sig, offset=o_off, truncate_lower=o_trl, truncate_upper=o_tr)
                elseif o_cat == "Uniform"
                    UniformOnset(; width=uw, offset=uoff)
                else
                    NoOnset()
                end
                
                noise = if n_cat == "White"
                    WhiteNoise(; noiselevel=n_lvl)
                elseif n_cat == "Pink"
                    PinkNoise(; noiselevel=n_lvl)
                elseif n_cat == "Red"
                    RedNoise(; noiselevel=n_lvl)
                else
                    NoNoise()
                end
                
                data, events_df = simulate(MersenneTwister(42), design, base_comp, onsets, noise;
                                           return_epoched=(o_cat == "No Onset"))
                clean, _ = simulate(MersenneTwister(42), design, base_comp, onsets, NoNoise();
                                   return_epoched=(o_cat == "No Onset"))
            end
            
            # Process data dimensions
            if data isa AbstractArray && ndims(data) == 3
                n_ch, n_t, n_ep = size(data)
                data_flat = reshape(data, n_ch, n_t*n_ep)
                clean_flat = reshape(clean, n_ch, n_t*n_ep)
                
                if m_cat == "Multi-channel Model"
                    y_noisy = vec(data_flat[CLEAN_SIGNAL_CHANNEL_IDX, :])
                    y_clean = vec(clean_flat[CLEAN_SIGNAL_CHANNEL_IDX, :])
                    mc_noisy = data_flat'
                    mc_clean = clean_flat'
                else
                    y_noisy = vec(data_flat[1, :])
                    y_clean = vec(clean_flat[1, :])
                    mc_noisy = repeat(reshape(y_noisy, :, 1), 1, N_CHANNELS)
                    mc_clean = repeat(reshape(y_clean, :, 1), 1, N_CHANNELS)
                end
            elseif data isa Matrix && size(data,1) == N_CHANNELS && m_cat == "Multi-channel Model"
                mc_noisy = data'
                mc_clean = clean'
                y_noisy = vec(data[CLEAN_SIGNAL_CHANNEL_IDX, :])
                y_clean = vec(clean[CLEAN_SIGNAL_CHANNEL_IDX, :])
            elseif data isa Matrix && size(data,2) == N_CHANNELS && m_cat == "Multi-channel Model"
                mc_noisy = data
                mc_clean = clean
                y_noisy = vec(data[:, CLEAN_SIGNAL_CHANNEL_IDX])
                y_clean = vec(clean[:, CLEAN_SIGNAL_CHANNEL_IDX])
            else
                y_noisy = vec(data)
                y_clean = vec(clean)
                mc_noisy = repeat(reshape(y_noisy, :,1), 1, N_CHANNELS)
                mc_clean = repeat(reshape(y_clean, :,1), 1, N_CHANNELS)
            end
            
            t = range(0, length=length(y_noisy), step=1/100)
            
            current_result = (
                noisy = Point2f.(t, y_noisy),
                clean = Point2f.(t, y_clean),
                multichannel_noisy = mc_noisy,
                multichannel_clean = mc_clean,
                time = collect(t),
                events = events_df,
                err = "",
                onset_params = (choice=o_cat, mu=o_mu_gui, sigma=o_sig_gui, offset=o_off_gui,
                               trl=o_trl_gui, tru=o_tr_gui, w=uw_gui, uoff=uoff_gui)
            )
            
            # Store result in tab
            tabs = component_tabs[]
            active_idx = findfirst(t -> t.id == active_tab_id[], tabs)
            if active_idx !== nothing
                tabs[active_idx].last_result = current_result
                all_results = all_tab_results[]
                all_results[active_tab_id[]] = current_result
                all_tab_results[] = all_results
                println("✓ Stored result for tab: $(tabs[active_idx].name)")
            end
            
            results[] = current_result
            status_text[] = "Done"
        catch e
            results[] = (
                noisy=[Point2f(0,0)], 
                clean=[Point2f(0,0)],
                multichannel_noisy=zeros(1,1), 
                multichannel_clean=zeros(1,1),
                time=[0.0], 
                events=DataFrame(), 
                err=sprint(showerror, e),
                onset_params=(choice="No Onset", mu=0.0, sigma=0.0, offset=0, trl=0, tru=0, w=0, uoff=0)
            )
            status_text[] = "Error: $(sprint(showerror, e))"
            println("Full error details: ", e)
            println(stacktrace(catch_backtrace()))
        finally
            is_running[] = false
        end
    end
    
    return (
        results = results,
        status_text = status_text,
        is_running = is_running,
        sim_trigger = sim_trigger
    )
end