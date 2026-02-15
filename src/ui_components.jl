"""
UI component creation functions for the dashboard
"""

using Bonito
using WGLMakie
using Observables

"""
    create_event_variables_display(categorical_variables, continuous_variables)

Create a formatted display of current event variables.

# Arguments
- `categorical_variables`: Observable Dict of categorical vars
- `continuous_variables`: Observable Dict of continuous vars

# Returns
Observable string with formatted variable list
"""
function create_event_variables_display(categorical_variables, continuous_variables)
    return map(categorical_variables, continuous_variables) do cat_vars, cont_vars
        lines = String["📊 Current Event Variables:"]
        
        if !isempty(cat_vars)
            push!(lines, "\n🔤 Categorical:")
            for (name, levels) in cat_vars
                push!(lines, "  • $name = $(join(levels, ", "))")
            end
        end
        
        if !isempty(cont_vars)
            push!(lines, "\n📈 Continuous:")
            for (name, params) in cont_vars
                push!(lines, "  • $name = [$(params.min):$(params.max), $(params.steps) steps]")
            end
        end
        
        if isempty(cat_vars) && isempty(cont_vars)
            push!(lines, "  (No variables defined - using default)")
        end
        
        join(lines, "\n")
    end
end

"""
    create_tab_bar_ui(component_tabs, active_tab_id)

Create tab bar UI showing active tab and all available tabs.

# Arguments
- `component_tabs`: Observable vector of ComponentTab objects
- `active_tab_id`: Observable string of active tab ID

# Returns
Bonito DOM element
"""
function create_tab_bar_ui(component_tabs, active_tab_id)
    return map(component_tabs, active_tab_id) do tabs, active_id
        if isempty(tabs)
            return Bonito.DOM.div("No tabs")
        end
        
        active_idx = findfirst(t -> t.id == active_id, tabs)
        active_tab_obj = active_idx !== nothing ? tabs[active_idx] : tabs[1]
        tab_list = join([t.name for t in tabs], ", ")
        
        if length(tabs) > 1
            Bonito.DOM.div(
                Bonito.DOM.span("Active Tab: ", 
                    style="font-weight: bold; font-size: 12px; margin-right: 10px;"),
                Bonito.DOM.span("$(active_tab_obj.name)", 
                    style="font-weight: bold; font-size: 14px; margin-right: 15px; color: #4CAF50;"),
                Bonito.DOM.span("(All tabs: $tab_list)", 
                    style="font-size: 10px; color: #666;"),
                style="padding: 10px; background: #f5f5f5; border: 1px solid #ddd; border-radius: 4px 4px 0 0; display: flex; align-items: center;"
            )
        else
            Bonito.DOM.div(
                Bonito.DOM.span("Tab: $(active_tab_obj.name)", 
                    style="font-weight: bold; font-size: 12px;"),
                style="padding: 10px; background: #f5f5f5; border: 1px solid #ddd; border-radius: 4px 4px 0 0;"
            )
        end
    end
end

"""
    create_legend_content(selected_channels, active_model_category, component_tabs, 
                         channel_names_list, rainbow_colors, CLEAN_SIGNAL_CHANNEL_IDX)

Create dynamic legend showing all plot elements.

# Arguments
- `selected_channels`: Observable set of selected channel indices
- `active_model_category`: Observable model category string
- `component_tabs`: Observable vector of tabs
- `channel_names_list`: List of electrode names
- `rainbow_colors`: List of colors for channels
- `CLEAN_SIGNAL_CHANNEL_IDX`: Index of reference electrode

# Returns
Observable Bonito DOM element
"""
function create_legend_content(selected_channels, active_model_category, component_tabs,
                               channel_names_list, rainbow_colors, CLEAN_SIGNAL_CHANNEL_IDX)
    return map(selected_channels, active_model_category, component_tabs) do sel_set, m_cat, tabs
        # Base lines (always shown)
        base_items = [
            Bonito.DOM.div(
                Bonito.DOM.div(style="width: 40px; height: 3px; background: gray; display: inline-block; vertical-align: middle; margin-right: 8px;"),
                Bonito.DOM.span("Cumulative Noisy", style="font-size: 11px; vertical-align: middle;"),
                style="display: inline-block; margin-right: 25px;"
            ),
            Bonito.DOM.div(
                Bonito.DOM.div(style="width: 40px; height: 3px; background: red; display: inline-block; vertical-align: middle; margin-right: 8px;"),
                Bonito.DOM.span("Cumulative Clean", style="font-size: 11px; vertical-align: middle;"),
                style="display: inline-block; margin-right: 25px;"
            )
        ]
        
        # Per-tab component lines
        tab_items = []
        for (idx, tab) in enumerate(tabs)
            if idx > MAX_TABS
                break
            end
            
            color_sym = TAB_COLORS[idx]
            color_obj = parse(Colorant, string(color_sym))
            r = round(Int, clamp(red(color_obj), 0, 1) * 255)
            g = round(Int, clamp(green(color_obj), 0, 1) * 255)
            b = round(Int, clamp(blue(color_obj), 0, 1) * 255)
            hex = string("#", lpad(string(r, base=16), 2, "0"),
                              lpad(string(g, base=16), 2, "0"),
                              lpad(string(b, base=16), 2, "0"))
            
            push!(tab_items,
                Bonito.DOM.div(
                    Bonito.DOM.div(style="width: 40px; height: 2px; background: $hex; display: inline-block; vertical-align: middle; margin-right: 8px; border: 1px dashed gray;"),
                    Bonito.DOM.span(tab.name, style="font-size: 10px; vertical-align: middle;"),
                    style="display: inline-block; margin-right: 15px;"
                ))
        end
        
        # Selected electrode channel entries (only in Multi-channel Model)
        channel_items = []
        if m_cat == "Multi-channel Model" && !isempty(sel_set)
            sorted_sel = sort(collect(sel_set))
            for ch_idx in sorted_sel
                # Skip the reference clean-signal electrode
                ch_idx == CLEAN_SIGNAL_CHANNEL_IDX && continue
                
                if ch_idx <= length(channel_names_list) && ch_idx <= length(rainbow_colors)
                    ch_name  = string(channel_names_list[ch_idx])
                    ch_color = rainbow_colors[ch_idx]
                    r_val = round(Int, clamp(red(ch_color),   0, 1) * 255)
                    g_val = round(Int, clamp(green(ch_color), 0, 1) * 255)
                    b_val = round(Int, clamp(blue(ch_color),  0, 1) * 255)
                    hex_ch = string("#",
                        lpad(string(r_val, base=16), 2, "0"),
                        lpad(string(g_val, base=16), 2, "0"),
                        lpad(string(b_val, base=16), 2, "0"))
                    
                    push!(channel_items,
                        Bonito.DOM.div(
                            Bonito.DOM.div(
                                style="width: 40px; height: 3px; background: $hex_ch; display: inline-block; vertical-align: middle; margin-right: 8px;"
                            ),
                            Bonito.DOM.span(
                                "Ch: $ch_name",
                                style="font-size: 10px; vertical-align: middle; color: #333;"
                            ),
                            style="display: inline-block; margin-right: 15px;"
                        )
                    )
                end
            end
        end
        
        # Electrode section separator + entries
        channel_section = if !isempty(channel_items)
            vcat(
                [Bonito.DOM.span(
                    "| Electrodes: ",
                    style="font-size: 11px; color: #888; margin-right: 8px; vertical-align: middle;"
                )],
                channel_items
            )
        else
            []
        end
        
        Bonito.DOM.div(
            Bonito.DOM.span("Legend: ", style="font-weight: bold; font-size: 11px; margin-right: 15px;"),
            base_items..., tab_items..., channel_section...,
            style="padding: 10px; background: white; border: 1px solid #ddd; border-radius: 4px; display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin-top: 10px;"
        )
    end
end