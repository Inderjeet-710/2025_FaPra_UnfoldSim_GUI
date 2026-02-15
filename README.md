# UnfoldSimDashboard

An interactive dashboard for EEG/ERP simulation and exploration using UnfoldSim.jl and WGLMakie.

## Features

- Multi-channel EEG simulation with HArtMuT head model (227 channels)
- Interactive ERP component modeling (P100, N170, P300, N400)
- Custom event variable definitions (categorical and continuous)
- Multiple model types: Linear, Mixed, Multi-channel
- Real-time topoplot visualization
- Configuration save/load functionality
- Cumulative signal visualization across multiple components

## Installation
```bash
git clone <repository-url>
cd UnfoldSimDashboard
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Usage

Run the dashboard with a single command:
```bash
julia run.jl
```

Or from Julia REPL:
```julia
using Pkg
Pkg.activate(".")
include("run.jl")
```

## Project Structure
```
UnfoldSimDashboard/
├── run.jl                          # Entry point - run this!
├── Project.toml                    # Dependencies
├── README.md                       # This file
└── src/
    ├── app.jl                      # Application assembly
    ├── types.jl                    # Data structures
    ├── constants.jl                # Global constants
    ├── hartmut.jl                  # HArtMuT model integration
    ├── erp_analysis.jl             # ERP metrics and analysis
    ├── utils.jl                    # Helper functions
    ├── io_system.jl                # File I/O operations
    ├── viz_utils.jl                # Visualization utilities
    ├── ui_components.jl            # Reusable UI widgets
    └── components/
        ├── event_manager.jl        # Event variable management
        ├── tab_manager.jl          # Component tab system
        ├── simulation_engine.jl    # Simulation execution
        ├── main_plot.jl            # Time-series visualization
        ├── onset_plot.jl           # Onset distribution plot
        ├── topoplot.jl             # Brain topoplot
        └── sidebar.jl              # Sidebar UI layout
```

## Development

### Adding New Features

1. **New UI Component**: Add to `src/components/`
2. **New Utility Function**: Add to `src/utils.jl`
3. **New ERP Analysis**: Add to `src/erp_analysis.jl`
4. **New Constant**: Add to `src/constants.jl`

### Testing Individual Components
```julia
# Test event manager
include("src/types.jl")
include("src/constants.jl")
include("src/components/event_manager.jl")
```

## Dependencies

- Bonito.jl - Web UI framework
- WGLMakie.jl - GPU-accelerated plotting
- UnfoldSim.jl - ERP simulation
- DataFrames.jl - Data manipulation
- And more (see Project.toml)

## License

[Your License Here]