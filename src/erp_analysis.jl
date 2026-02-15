"""
ERP (Event-Related Potential) analysis and signal processing functions
"""

using Statistics
using LinearAlgebra

"""
Module containing ERP exploration and analysis functions
"""
module ERPExplorer
    using Statistics
    using LinearAlgebra
    
    export calculate_erp_metrics, create_topoplot_interpolation, detect_peaks
    
    """
        calculate_erp_metrics(data::Matrix)
    
    Calculate various ERP metrics from multichannel data.
    
    # Arguments
    - `data::Matrix`: n_samples × n_channels data matrix
    
    # Returns
    Dictionary containing:
    - `:rms`: Root mean square for each channel
    - `:peak_amplitude`: Maximum absolute amplitude
    - `:mean_amplitude`: Mean amplitude
    - `:std`: Standard deviation
    """
    function calculate_erp_metrics(data::Matrix)
        n_samples, n_channels = size(data)
        metrics = Dict(
            :rms => [sqrt(mean(data[:, i].^2)) for i in 1:n_channels],
            :peak_amplitude => [maximum(abs.(data[:, i])) for i in 1:n_channels],
            :mean_amplitude => [mean(data[:, i]) for i in 1:n_channels],
            :std => [std(data[:, i]) for i in 1:n_channels]
        )
        return metrics
    end
    
    """
        detect_peaks(signal::Vector, threshold::Float64=0.5)
    
    Detect peaks in a signal that exceed a threshold.
    
    # Arguments
    - `signal::Vector`: Input signal
    - `threshold::Float64`: Minimum absolute amplitude for peak detection
    
    # Returns
    Vector of indices where peaks occur
    """
    function detect_peaks(signal::Vector, threshold::Float64=0.5)
        peaks = Int[]
        for i in 2:length(signal)-1
            if abs(signal[i]) > threshold &&
               abs(signal[i]) > abs(signal[i-1]) &&
               abs(signal[i]) > abs(signal[i+1])
                push!(peaks, i)
            end
        end
        return peaks
    end
    
    """
        create_topoplot_interpolation(positions, values)
    
    Create interpolated topoplot values (placeholder implementation).
    """
    function create_topoplot_interpolation(positions, values)
        return values
    end
end

using .ERPExplorer

"""
    hanning_p100()

Generate P100 ERP component basis function (positive peak ~100ms)
"""
function hanning_p100()
    t = range(0, 0.5, length=100)
    y = exp.(-(t .- 0.1).^2 / (2*0.02^2)) * 2.0
    return y
end

"""
    hanning_n170()

Generate N170 ERP component basis function (negative peak ~170ms)
"""
function hanning_n170()
    t = range(0, 0.5, length=100)
    y = -exp.(-(t .- 0.17).^2 / (2*0.03^2)) * 1.5
    return y
end

"""
    hanning_p300()

Generate P300 ERP component basis function (positive peak ~300ms)
"""
function hanning_p300()
    t = range(0, 0.8, length=160)
    y = exp.(-(t .- 0.3).^2 / (2*0.05^2)) * 3.0
    return y
end

"""
    hanning_n400()

Generate N400 ERP component basis function (negative peak ~400ms)
"""
function hanning_n400()
    t = range(0, 0.8, length=160)
    y = -exp.(-(t .- 0.4).^2 / (2*0.06^2)) * 2.0
    return y
end

"""
    hanning(width, shift, sfreq)

Generate a Hanning window with specified width and temporal shift.

# Arguments
- `width`: Window width in samples
- `shift`: Temporal shift in samples
- `sfreq`: Sampling frequency
"""
function hanning(width, shift, sfreq)
    window = 0.5 .- 0.5 .* cos.(2π .* (0:width-1) ./ (width-1))
    padded = zeros(width + shift)
    padded[shift+1:end] .= window
    return padded
end