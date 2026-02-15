
"""
File I/O operations for simulation data and configuration
"""

using CSV
using DataFrames
using JSON3
using Dates

"""
    download_sim_files_smart(res, slider_config::Dict)

Save simulation data and events to CSV files with embedded configuration.

# Arguments
- `res`: Simulation result tuple
- `slider_config`: Dictionary of slider/parameter values

# Returns
Status message string
"""
function download_sim_files_smart(res, slider_config::Dict)
    try
        # Save multichannel data
        data_file = "simulation_data.csv"
        if size(res.multichannel_noisy, 1) > 0 && size(res.multichannel_noisy, 2) > 0
            data_df = DataFrame(res.multichannel_noisy, :auto)
            CSV.write(data_file, data_df)
        else
            empty_data = DataFrame(zeros(1, 1), :auto)
            CSV.write(data_file, empty_data)
        end
        
        # Save events with embedded metadata
        events_file = "simulation_events.csv"
        if !isempty(res.events)
            events_df = copy(res.events)
        else
            events_df = DataFrame(
                sample = [1],
                condition = ["A"],
                subject = [1],
                latency = [0.0]
            )
        end
        
        # Embed configuration as metadata
        config_json = JSON3.write(slider_config)
        events_df[!, :metadata] .= config_json
        CSV.write(events_file, events_df)
        
        return "✓ Saved: simulation_data.csv, simulation_events.csv ($(length(slider_config)) params)"
    catch e
        return "✗ Error saving files: $(sprint(showerror, e))"
    end
end

"""
    parse_uploaded_csv(csv_text::String)

Parse uploaded CSV text and extract embedded configuration.

# Arguments
- `csv_text`: Raw CSV file content as string

# Returns
Tuple of (DataFrame, config_dict) where config_dict may be empty
"""
function parse_uploaded_csv(csv_text::String)
    df = CSV.read(IOBuffer(csv_text), DataFrame)
    config = Dict{String, Any}()
    
    if hasproperty(df, :metadata)
        for row_idx in 1:min(5, nrow(df))
            try
                metadata_str = String(df.metadata[row_idx])
                if isempty(metadata_str) || ismissing(metadata_str)
                    continue
                end
                
                # Clean escaped quotes
                clean_str = replace(metadata_str, "\"\"" => "\"")
                clean_str = strip(clean_str)
                
                # Remove outer quotes if present
                if startswith(clean_str, "\"") && endswith(clean_str, "\"")
                    clean_str = clean_str[2:end-1]
                end
                
                # Extract JSON
                json_start = findfirst("{", clean_str)
                json_end   = findlast("}", clean_str)
                
                if json_start !== nothing && json_end !== nothing
                    json_str = clean_str[json_start[1]:json_end[1]]
                    config = JSON3.read(json_str, Dict{String, Any})
                    break
                end
            catch e
                continue
            end
        end
    end
    
    return df, config
end