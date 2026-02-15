"""
Visualization utilities for plots and topoplots
"""

using WGLMakie
using Colors
using ColorSchemes
using Observables

"""
    draw_head_outline!(ax)

Draw stylized head outline (circle with nose and ears) on axis.

# Arguments
- `ax`: Makie axis object
"""
function draw_head_outline!(ax)
    θ = range(0, 2π, length=100)
    
    # Head circle
    lines!(ax, cos.(θ), sin.(θ), color=:black, linewidth=2)
    
    # Nose
    lines!(ax, [0.0, -0.15, 0.15, 0.0], [1.0, 1.15, 1.15, 1.0], color=:black, linewidth=2)
    
    # Left ear
    lines!(ax, [-1.0, -1.1, -1.1, -1.0], [0.15, 0.15, -0.15, -0.15], color=:black, linewidth=2)
    
    # Right ear
    lines!(ax, [1.0, 1.1, 1.1, 1.0], [0.15, 0.15, -0.15, -0.15], color=:black, linewidth=2)
end

"""
    plot_expexplorer_topoplot(multichannel_data, positions, time_point, viz_mode)

Generate topoplot colors based on multichannel EEG data.

# Arguments
- `multichannel_data`: n_samples × n_channels matrix
- `positions`: Vector of electrode positions (not used in current implementation)
- `time_point`: Time sample index
- `viz_mode`: "Amplitude", "RMS", "Peak Detection", or "Mean"

# Returns
Tuple of (colors, amplitudes) where colors are RGBA values for each electrode
"""
function plot_expexplorer_topoplot(multichannel_data, positions, time_point, viz_mode)
    try
        n_samples, n_channels = size(multichannel_data)
        
        # Select data based on visualization mode
        if viz_mode == "Amplitude"
            time_idx = min(max(1, time_point), n_samples)
            amplitudes = multichannel_data[time_idx, :]
        elseif viz_mode == "RMS"
            metrics = ERPExplorer.calculate_erp_metrics(multichannel_data)
            amplitudes = metrics[:rms]
        elseif viz_mode == "Peak Detection"
            metrics = ERPExplorer.calculate_erp_metrics(multichannel_data)
            amplitudes = metrics[:peak_amplitude]
        else  # Mean
            metrics = ERPExplorer.calculate_erp_metrics(multichannel_data)
            amplitudes = metrics[:mean_amplitude]
        end
        
        # Normalize amplitudes to [0, 1]
        amp_min, amp_max = extrema(amplitudes)
        amp_range = amp_max - amp_min
        if amp_range > 0
            norm_amps = (amplitudes .- amp_min) ./ amp_range
        else
            norm_amps = fill(0.5, length(amplitudes))
        end
        
        # Generate colors (currently uniform blue)
        colors = fill(RGBAf(0.2, 0.4, 0.9, 0.85), length(amplitudes))
        
        return colors, amplitudes
    catch e
        return fill(RGBAf(0.5, 0.5, 0.5, 0.8), length(positions)), zeros(length(positions))
    end
end

"""
    compute_cumulative_signal(all_results_dict)

Compute cumulative ERP signal from multiple component tabs.

# Arguments
- `all_results_dict`: Dictionary mapping tab_id => simulation result

# Returns
Tuple of (cumulative_clean, cumulative_noisy, reference_time, events_df)
"""
function compute_cumulative_signal(all_results_dict)
    if isempty(all_results_dict)
        return Point2f[(0, 0)], Point2f[(0, 0)], Float64[], DataFrame()
    end
    
    # Find longest signal as reference
    max_length = 0
    reference_time = Float64[]
    for (tab_id, res) in all_results_dict
        if !isnothing(res) && res.err == "" && length(res.time) > max_length
            max_length = length(res.time)
            reference_time = res.time
        end
    end
    
    if max_length == 0
        return Point2f[(0, 0)], Point2f[(0, 0)], Float64[], DataFrame()
    end
    
    # Sum all signals
    cumulative_clean_y = zeros(max_length)
    cumulative_noisy_y = zeros(max_length)
    
    for (tab_id, res) in all_results_dict
        if isnothing(res) || res.err != "" || isempty(res.clean)
            continue
        end
        
        clean_y = [p[2] for p in res.clean]
        noisy_y = [p[2] for p in res.noisy]
        len = min(length(clean_y), max_length)
        
        cumulative_clean_y[1:len] .+= clean_y[1:len]
        cumulative_noisy_y[1:len] .+= noisy_y[1:len]
    end
    
    cumulative_clean = Point2f.(reference_time, cumulative_clean_y)
    cumulative_noisy = Point2f.(reference_time, cumulative_noisy_y)
    
    # Extract events from first valid result
    events_df = DataFrame()
    for (tab_id, res) in all_results_dict
        if !isnothing(res) && !isempty(res.events)
            events_df = res.events
            break
        end
    end
    
    return cumulative_clean, cumulative_noisy, reference_time, events_df
end