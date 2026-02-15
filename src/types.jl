"""
Data structures for UnfoldSim Dashboard
"""

"""
Represents a component tab in the UI with all its configuration
"""
mutable struct ComponentTab
    id::String
    name::String
    model_category::Any
    hanning_preset::Any
    contrast_type::Any
    basis_txt::Any
    formula_txt::Any
    projection_txt::Any
    beta_slider::Any
    contrast_slider::Any
    mixed_sigma::Any
    last_result::Any
end

"""
Named tuple type for simulation results
"""
const SimulationResult = NamedTuple{
    (:noisy, :clean, :multichannel_noisy, :multichannel_clean, :time, :events, :err, :onset_params),
    Tuple{Vector{Point2f}, Vector{Point2f}, Matrix{Float64}, Matrix{Float64}, Vector{Float64}, DataFrame, String, NamedTuple}
}

"""
Named tuple type for onset parameters
"""
const OnsetParams = NamedTuple{
    (:choice, :mu, :sigma, :offset, :trl, :tru, :w, :uoff),
    Tuple{String, Float64, Float64, Int, Int, Int, Int, Int}
}