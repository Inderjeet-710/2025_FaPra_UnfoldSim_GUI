"""
Main Time-Series Plot Component

Cumulative ERP visualization with multi-tab support and channel overlays.
"""

using WGLMakie
using Observables
using ColorSchemes
using Colors

"""
    create_main_plot(session, params...)

Create main time-series plot with cumulative signals, tab traces, and channel overlays.

Returns: (fig, legend_content)
"""
function create_main_plot(session, results, all_tab_results, component_tabs,
                         selected_hannings, selected_channels, active_model_category,
                         time_slider_throttled, channel_names_list, rainbow_colors,
                         CLEAN_SIGNAL_CHANNEL_IDX)
    
    # Create figure
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], 
              title="UnfoldSim + ERP Explorer (Cumulative)", 
              xlabel="Time (s)", 
              ylabel="µV",
              limits=(nothing, nothing, nothing, nothing),
              xgridvisible=false, 
              ygridvisible=true)
    
    # Observables for plot data
    cumulative_clean_obs = Observable(Point2f[(0, 0)])
    cumulative_noisy_obs = Observable(Point2f[(0, 0)])
    
    # Zero reference line
    hlines!(ax, [0.0], color=(:gray, 0.3), linewidth=0.5, linestyle=:dash)
    
    # Subject separators
    sep_xs_obs = Observable([0.0])
    sep_plot = vlines!(ax, sep_xs_obs, color=:black, linestyle=:dot, linewidth=2)
    sep_plot.visible[] = false
    
    # Tab lines (individual component traces)
    tab_line_data = [Observable(Point2f[(0, 0)]) for _ in 1:MAX_TABS]
    tab_line_visibility = [Observable(false) for _ in 1:MAX_TABS]
    
    tab_lines = []
    for i in 1:MAX_TABS
        line = lines!(ax, tab_line_data[i],
                     color=(TAB_COLORS[i], 0.5), 
                     linewidth=1.5, 
                     linestyle=:dash,
                     visible=tab_line_visibility[i])
        push!(tab_lines, line)
    end
    
    # Cumulative lines (main signals)
    cumulative_noisy_line = lines!(ax, cumulative_noisy_obs, 
                                   color=:gray, 
                                   linewidth=2.5, 
                                   label="Cumulative Noisy")
    cumulative_clean_line = lines!(ax, cumulative_clean_obs, 
                                   color=:red, 
                                   linewidth=3.0, 
                                   label="Cumulative Clean")
    
    # Channel lines (for multi-channel visualization)
    N_CHANNELS = length(channel_names_list)
    channel_line_data = [Observable(Point2f[(0, 0)]) for _ in 1:N_CHANNELS]
    channel_line_visibility = [Observable(false) for _ in 1:N_CHANNELS]
    
    channel_lines = []
    for i in 1:N_CHANNELS
        line = lines!(ax, channel_line_data[i],
                     color=rainbow_colors[i], 
                     linewidth=2.5,
                     visible=channel_line_visibility[i])
        push!(channel_lines, line)
    end
    
    # Update cumulative plot when tabs change
    on(all_tab_results) do all_results_dict
        try
            # Reset tab visibilities
            for i in 1:MAX_TABS
                tab_line_visibility[i][] = false
            end
            
            if isempty(all_results_dict)
                cumulative_clean_obs[] = Point2f[(0, 0)]
                cumulative_noisy_obs[] = Point2f[(0, 0)]
                sep_plot.visible[] = false
                return
            end
            
            # Compute cumulative signal
            cum_clean, cum_noisy, ref_time, events_df = compute_cumulative_signal(all_results_dict)
            cumulative_clean_obs[] = cum_clean
            cumulative_noisy_obs[] = cum_noisy
            
            # Show individual tab traces
            tab_idx = 1
            for (tab_id, res) in all_results_dict
                if tab_idx > MAX_TABS
                    break
                end
                if !isnothing(res) && res.err == "" && !isempty(res.clean)
                    tab_line_data[tab_idx][] = res.clean
                    tab_line_visibility[tab_idx][] = true
                    tab_idx += 1
                end
            end
            
            # Subject separators (for multi-subject designs)
            if !isempty(events_df) && hasproperty(events_df, :subject)
                subjs = sort(unique(events_df.subject))
                n_subjs = length(subjs)
                if n_subjs > 1 && !isempty(ref_time)
                    total_time = ref_time[end] - ref_time[1]
                    time_per_subject = total_time / n_subjs
                    sep_xs_obs[] = [ref_time[1] + i * time_per_subject for i in 1:(n_subjs-1)]
                    sep_plot.visible[] = true
                else
                    sep_plot.visible[] = false
                end
            else
                sep_plot.visible[] = false
            end
            
            autolimits!(ax)
            println("✓ Updated cumulative plot with $(length(all_results_dict)) tab(s)")
        catch e
            println("Cumulative plot update error: $e")
        end
    end
    
    # Update channel lines when selection changes
    onany(selected_channels, results, active_model_category) do sel_set, res, m_cat
        for i in 1:N_CHANNELS
            channel_line_visibility[i][] = false
        end
        
        if m_cat == "Multi-channel Model" && !isempty(sel_set) && res.err == "" && !isempty(res.time)
            for ch_idx in sel_set
                ch_idx == CLEAN_SIGNAL_CHANNEL_IDX && continue
                if ch_idx <= size(res.multichannel_clean, 2) && ch_idx <= N_CHANNELS
                    channel_line_data[ch_idx][] = Point2f.(res.time, res.multichannel_clean[:, ch_idx])
                    channel_line_visibility[ch_idx][] = true
                end
            end
            autolimits!(ax)
        end
    end
    
    # Hanning overlay (reference basis functions)
    hanning_plot_refs = Ref{Vector{Any}}([])
    
    onany(results, selected_hannings) do res, sel_hannings
        # Clear existing hanning overlays
        for plot in hanning_plot_refs[]
            try
                if plot in ax.scene.plots
                    delete!(ax, plot)
                end
            catch
            end
        end
        empty!(hanning_plot_refs[])
        
        if !isempty(sel_hannings) && res.err == "" && !isempty(res.time) && !isempty(res.clean)
            clean_y = [p[2] for p in res.clean]
            
            for preset_name in sel_hannings
                basis_y = if preset_name == "P100 (Positive)"
                    hanning_p100()
                elseif preset_name == "N170 (Negative)"
                    hanning_n170()
                elseif preset_name == "P300 (Positive)"
                    hanning_p300()
                elseif preset_name == "N400 (Negative)"
                    hanning_n400()
                else
                    continue
                end
                
                # Scale to match signal amplitude
                if !isempty(clean_y)
                    scale_factor = maximum(abs.(clean_y))
                    if scale_factor > 0
                        basis_y = basis_y .* scale_factor * 0.5
                    end
                end
                
                # Align time axis
                t_hanning = range(0, length=length(basis_y), step=1/100)
                if length(t_hanning) > length(res.time)
                    t_hanning = res.time[1:min(length(res.time), length(t_hanning))]
                    basis_y = basis_y[1:length(t_hanning)]
                else
                    basis_y_padded = zeros(length(res.time))
                    basis_y_padded[1:min(length(basis_y), length(res.time))] = 
                        basis_y[1:min(length(basis_y), length(res.time))]
                    basis_y = basis_y_padded
                    t_hanning = res.time
                end
                
                color = get(HANNING_COLORS, preset_name, :purple)
                plot = lines!(ax, t_hanning, basis_y, 
                            color=color, 
                            linewidth=2, 
                            label="$(preset_name)")
                push!(hanning_plot_refs[], plot)
            end
        end
    end
    
    # Create legend
    legend_content = create_legend_content(
        selected_channels, active_model_category, component_tabs,
        channel_names_list, rainbow_colors, CLEAN_SIGNAL_CHANNEL_IDX
    )
    
    return (
        fig = fig,
        legend_content = legend_content
    )
end