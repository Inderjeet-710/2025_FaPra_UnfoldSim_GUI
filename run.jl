#!/usr/bin/env julia

"""
UnfoldSim Dashboard - Entry Point (Using Global Environment)

Run with: julia run.jl
"""

println("\n" * "="^70)
println("🚀 UnfoldSim Dashboard Starting...")
println("="^70 * "\n")

# DON'T activate local project - use global environment
# Pkg.activate(@__DIR__)  # <-- REMOVE THIS LINE

# Load and run the application
println("📦 Loading application...")
include("src/app.jl")

println("="^70)
println("📍 Navigate to the URL shown below in your browser")
println("="^70 * "\n")

# Run the app
app