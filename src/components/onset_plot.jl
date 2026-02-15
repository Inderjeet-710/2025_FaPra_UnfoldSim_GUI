"""
Onset Distribution Plot Component

Visualizes the probability density of onset timing distributions.
"""

using WGLMakie
using Distributions
using Observables

"""
    create_onset_plot(session, results)

Create onset distribution visualization plot.

Returns: onset_plot_fig
"""
function create_onset_plot(session, results)
    # Create figure
    onset_plot_fig = Figure(size=(800, 200))
    onset_ax = Axis(onset_plot_fig[1,1], 
                    title="Onset Distribution Probability Density",
                    xlabel="Time Samples", 
                    ylabel="Density", 
                    titlesize=14, 
                    titlefont=:bold)
    
    # Update plot when results change
    on(results) do res
        try
            empty!(onset_ax)
            p = res.onset_params
            
            # Determine x-axis range
            max_x = if p.choice == "Uniform"
                map_to_offset(p.uoff) + map_to_width(p.w) + 50
            elseif p.choice == "Log Normal"
                map_to_offset(p.offset) + map_to_truncate(p.tru) + 50
            else
                200
            end
            
            x_range = range(0, max_x, length=500)
            
            # Plot distribution
            if p.choice == "Uniform"
                w = map_to_width(p.w)
                off = map_to_offset(p.uoff)
                y = [(xi >= off && xi <= off+w) ? 1/max(w, 1) : 0.0 for xi in x_range]
                lines!(onset_ax, x_range, y, color=:blue, linewidth=3)
                fill_between!(onset_ax, x_range, 0.0, y, color=(:blue, 0.2))
            elseif p.choice == "Log Normal"
                μ = map_to_mu(p.mu)
                σ = map_to_onset_sigma(p.sigma)
                off = map_to_offset(p.offset)
                trl = map_to_truncate_lower(p.trl)
                tru = map_to_truncate(p.tru)
                d = LogNormal(μ, σ)
                y = [(xi - off >= trl && xi - off <= tru && xi - off > 0) ? 
                     pdf(d, xi - off) : 0.0 for xi in x_range]
                lines!(onset_ax, x_range, y, color=:purple, linewidth=3)
                fill_between!(onset_ax, x_range, 0.0, y, color=(:purple, 0.2))
            end
            
            xlims!(onset_ax, 0, max_x)
        catch e
            println("Onset plot error: $e")
        end
    end
    
    return onset_plot_fig
end