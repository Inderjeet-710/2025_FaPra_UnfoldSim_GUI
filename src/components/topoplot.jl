"""
Brain Topoplot Component

Interactive EEG electrode visualization with HArtMuT head model.
"""

using WGLMakie
using Observables
using Colors

"""
    create_topoplot(session, params...)

Create interactive brain topoplot with electrode selection.

Returns: (brain_fig, erp_panel_content)
"""
function create_topoplot(session, results, selected_channels, time_slider_throttled,
                        active_model_category, elec_pos, channel_names_list,
                        CLEAN_SIGNAL_CHANNEL_IDX)
    
    N_CHANNELS = length(channel_names_list)
    
    # Create figure
    brain_fig = Figure(size=(250, 250))
    brain_ax = Axis(brain_fig[1, 1],
                    aspect=DataAspect(),
                    title="HArtMuT EEG (227 Channels)",
                    titlesize=10, 
                    titlefont=:bold, 
                    titlealign=:center)
    hidedecorations!(brain_ax)
    hidespines!(brain_ax)
    
    # Draw head outline
    draw_head_outline!(brain_ax)
    
    # Electrode positions
    positions = [Point2f(elec_pos[ch]...) for ch in channel_names_list]
    
    # Observable colors for electrodes
    topo_colors_obs = Observable(
        [i == CLEAN_SIGNAL_CHANNEL_IDX ? RGBAf(1.0, 0.0, 0.0, 1.0) :
                                          RGBAf(0.2, 0.4, 0.9, 0.85)
         for i in 1:N_CHANNELS]
    )
    
    # Plot electrodes
    scatter!(brain_ax, positions, 
            color=topo_colors_obs, 
            markersize=9, 
            strokewidth=1, 
            strokecolor=:black)
    
    # Update colors based on data and selection
    onany(results, selected_channels, time_slider_throttled, active_model_category) do res, sel_set, time_pt, m_cat
        n_ch = length(channel_names_list)
        
        if m_cat != "Multi-channel Model"
            # Simple color coding: red for reference, orange for selected, blue for others
            new_colors = [i == CLEAN_SIGNAL_CHANNEL_IDX ? RGBAf(1.0, 0.0, 0.0, 1.0) :
                         (i in sel_set ? RGBAf(1.0, 0.5, 0.0, 1.0) :
                                        RGBAf(0.2, 0.4, 0.9, 0.85))
                         for i in 1:n_ch]
            topo_colors_obs[] = new_colors
            return
        end
        
        # For multi-channel model, color by amplitude
        new_colors = if res.err != "" || size(res.multichannel_noisy, 2) != n_ch
            [i == CLEAN_SIGNAL_CHANNEL_IDX ? RGBAf(1.0, 0.0, 0.0, 1.0) :
             (i in sel_set ? RGBAf(1.0, 0.5, 0.0, 1.0) :
                            RGBAf(0.2, 0.4, 0.9, 0.85))
             for i in 1:n_ch]
        else
            colors, _ = plot_expexplorer_topoplot(res.multichannel_noisy, positions, time_pt, "Amplitude")
            n_c = length(colors)
            [i == CLEAN_SIGNAL_CHANNEL_IDX ? RGBAf(1.0, 0.0, 0.0, 1.0) :
             (i in sel_set ? RGBAf(1.0, 0.5, 0.0, 1.0) :
             (i <= n_c ? colors[i] :
                        RGBAf(0.2, 0.4, 0.9, 0.85)))
             for i in 1:n_ch]
        end
        topo_colors_obs[] = new_colors
    end
    
    # Click handler for electrode selection
    on(events(brain_ax.scene).mousebutton) do event
        if active_model_category[] != "Multi-channel Model"
            return
        end
        if event.button == Mouse.left && event.action == Mouse.press
            pos = mouseposition(brain_ax.scene)
            dists = [sum((pos .- p).^2) for p in positions]
            min_dist, idx = findmin(dists)
            
            # If click is close enough to an electrode
            if min_dist < 0.02
                # Don't allow toggling the reference electrode
                idx == CLEAN_SIGNAL_CHANNEL_IDX && return
                
                curr_set = copy(selected_channels[])
                if idx in curr_set
                    delete!(curr_set, idx)
                else
                    push!(curr_set, idx)
                end
                selected_channels[] = curr_set
            end
        end
    end
    
    # ERP panel content (shows topoplot only for multi-channel model)
    erp_panel_content = map(active_model_category) do m_cat
        if m_cat == "Linear Model" || m_cat == "Mixed Model"
            Bonito.DOM.div(
                Bonito.DOM.h3("ERP Explorer", 
                    style="font-size: 15px; margin: 6px 0; color: #333;"),
                Bonito.DOM.div(
                    Bonito.DOM.span("Brain topoplot is only available for Multi-channel Model.",
                        style="font-style:italic; color:#888; padding: 20px; display: block;"),
                    style="padding: 10px; background: #f9f9f9; border: 1px solid #ddd; border-radius: 4px; margin-top: 20px;"
                ),
                style="padding: 10px;"
            )
        else
            Bonito.DOM.div(
                Bonito.DOM.h3("ERP Explorer", 
                    style="font-size: 15px; margin: 6px 0; color: #333;"),
                Bonito.DOM.div(
                    brain_fig,
                    style="margin-bottom: 12px; width: 100%; max-width: 400px; height: auto; overflow: hidden; display: block; box-sizing: border-box;"
                ),
                style="padding: 10px;"
            )
        end
    end
    
    return (
        brain_fig = brain_fig,
        erp_panel_content = erp_panel_content
    )
end