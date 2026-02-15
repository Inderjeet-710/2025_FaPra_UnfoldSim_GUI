"""
Global constants and configuration for UnfoldSim Dashboard
"""

# Performance tuning constants
const THROTTLE_DT = 0.05
const SLIDER_THROTTLE = 0.1
const SIMULATION_DEBOUNCE = 0.5

# Channel configuration
const CLEAN_SIGNAL_CHANNEL_NAME = :AF3

# Hanning preset colors
const HANNING_COLORS = Dict(
    "P100 (Positive)" => :blue,
    "N170 (Negative)" => :orange,
    "P300 (Positive)" => :green,
    "N400 (Negative)" => :magenta,
)

# Variable templates for event definition
const VARIABLE_TEMPLATES = Dict(
    "condition" => ["A", "B"],
    "stimulus_type" => ["face", "car", "house"],
    "task" => ["visual", "auditory", "tactile"],
    "emotion" => ["happy", "sad", "neutral", "angry"],
    "color" => ["red", "green", "blue"],
    "intensity" => (min=0.0, max=10.0, steps=5),
    "contrast" => (min=0.0, max=1.0, steps=10),
    "duration" => (min=100.0, max=500.0, steps=5),
    "frequency" => (min=1.0, max=20.0, steps=10)
)

# Tab colors for visualization
const TAB_COLORS = [:cyan, :magenta, :yellow, :lime, :orange, :purple, :pink, :brown, :navy, :olive]
const MAX_TABS = 10

# CSS Styles
const LABEL_STYLE = "font-weight: bold; font-size: 11px; margin-top: 8px; display: block; color: #444;"
const CARD_STYLE = "padding: 4px 6px; border: 1px solid #e0e0e0; border-radius: 4px; background: #fff; margin-bottom: 4px;"

# Design dropdown options
const DESIGN_DROPDOWN_OPTIONS = ["Single-subject design", "Repeat design", "Multi-subject design"]

# Categorical and continuous variable options
const CAT_VAR_OPTIONS = ["condition", "stimulus_type", "task", "emotion", "color"]
const CONT_VAR_OPTIONS = ["intensity", "contrast", "duration", "frequency"]

# Hanning preset options
const HANNING_PRESET_OPTIONS = ["Custom", "N170 (Negative)", "N400 (Negative)", "P100 (Positive)", "P300 (Positive)"]