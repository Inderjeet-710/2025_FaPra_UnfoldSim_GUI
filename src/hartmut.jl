"""
HArtMuT (Head Artifact Model Template) integration and electrode positioning
"""

using UnfoldSim

# Cached HArtMuT model instance to avoid repeated loading
if !@isdefined(CACHED_HARTMUT)
    const CACHED_HARTMUT = Hartmut()
    println("✓ Loaded HArtMuT model")
end

# Cached 2D electrode positions derived from HArtMuT 3D coordinates
if !@isdefined(CACHED_ELECTRODE_POSITIONS)
    const CACHED_ELECTRODE_POSITIONS = let
        h = CACHED_HARTMUT
        labels = h.electrodes["label"]
        pos_3d = h.electrodes["pos"]
        coords_2d = Dict{Symbol, Tuple{Float64, Float64}}()
        max_val = maximum(abs.(pos_3d[:, 1:2]))
        for i in 1:length(labels)
            x = pos_3d[i, 1] / max_val
            y = pos_3d[i, 2] / max_val
            coords_2d[Symbol(labels[i])] = (x, y)
        end
        coords_2d
    end
    println("✓ Cached $(length(CACHED_ELECTRODE_POSITIONS)) electrode positions")
end

"""
    get_electrode_positions()

Returns the cached dictionary of electrode positions.

# Returns
- `Dict{Symbol, Tuple{Float64, Float64}}`: Mapping of electrode names to 2D coordinates
"""
function get_electrode_positions()
    return CACHED_ELECTRODE_POSITIONS
end

"""
    get_hartmut_model()

Returns the cached HArtMuT model instance.

# Returns
- `Hartmut`: The HArtMuT head model object
"""
function get_hartmut_model()
    return CACHED_HARTMUT
end