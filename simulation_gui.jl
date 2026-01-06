using Bonito
using WGLMakie
using UnfoldSim
using DataFrames
using Distributions
using Random
using Statistics
using Observables
using StatsModels

# Helper for Hanning logic
function hanning(width, shift, sfreq)
    window = 0.5 .- 0.5 .* cos.(2π .* (0:width-1) ./ (width-1))
    padded = zeros(width + shift)
    padded[shift+1:end] .= window
    return padded
end

app = Bonito.App() do session

    # 1. DROP DOWN LIST
    model_category  = Bonito.Dropdown(["Linear Model", "Mixed Model", "Multi-channel Model"]; index=1)
    design_category = Bonito.Dropdown(["Single-subject design", "Repeat design", "Multi-subject design"]; index=1)
    onset_choice    = Bonito.Dropdown(["Uniform", "Log Normal", "No Onset"]; index=1)
    noise_choice    = Bonito.Dropdown(["White", "Pink", "Red", "No Noise"]; index=1)
    hanning_preset  = Bonito.Dropdown(["Custom", "N170 (Negative)", "N400 (Negative)", "P100 (Positive)", "P300 (Positive)"]; index=1)
    contrast_type   = Bonito.Dropdown(["DummyCoding", "EffectsCoding", "HelmertCoding", "SeqDiffCoding", "HypothesisCoding"]; index=1)

    # 2. TEXT FIELDS
    basis_txt   = Bonito.TextField("0.5 .- 0.5 .* cos.(2π .* (0:39) ./ 39)")
    formula_txt = Bonito.TextField("@formula(0 ~ 1 + condition)")
    hyp_matrix_txt = Bonito.TextField("[1 -1]")

    beta_slider    = Bonito.Slider(-10.0:0.5:10.0; value=2.0)
    contrast_slider = Bonito.Slider(-5.0:0.5:5.0; value=1.0)
    mixed_sigma    = Bonito.Slider(0.0:0.1:5.0; value=1.0)
    projection_txt = Bonito.TextField("[1.0, 0.5, -0.2]")

    # Design Params
    n_subjects      = Bonito.Slider(1:1:50; value=5)
    n_items         = Bonito.Slider(2:2:100; value=20)
    cond_txt        = Bonito.TextField("Dict(:condition => ['A', 'B'])")
    subj_btwn_txt   = Bonito.TextField("Dict(:group => ['Control', 'Patient'])")
    item_btwn_txt   = Bonito.TextField("Dict(:difficulty => ['Easy', 'Hard'])")
    both_within_txt = Bonito.TextField("Dict(:stimulus => ['Image', 'Text'])")
    event_order_txt = Bonito.TextField("shuffle")

    # Onset Params
    on_mu        = Bonito.Slider(-1.0:0.1:2.0; value=-0.5)
    on_sigma     = Bonito.Slider(0.1:0.1:1.0; value=0.5)
    on_offset    = Bonito.Slider(0:10:200; value=20)
    on_truncate  = Bonito.Slider(100:50:1000; value=500)
    u_width      = Bonito.Slider(10:10:200; value=50)
    u_offset_uni = Bonito.Slider(0:10:100; value=20)

    noise_lvl = Bonito.Slider(0:0.1:10.0; value=1.5)

    
    label_s = "font-weight: bold; font-size: 11px; margin-top: 8px; display: block; color: #444;"
    card_s  = "padding: 12px; border: 1px solid #e0e0e0; border-radius: 8px; background: #fff; margin-bottom: 12px;"

    # 3. HANNING 
    on(hanning_preset.value) do val
        if val == "Custom"
            basis_txt.value[] = "0.5 .- 0.5 .* cos.(2π .* (0:39) ./ 39)"
        elseif val == "N170 (Negative)"
            basis_txt.value[] = "-hanning(15, 10, 100)"
        elseif val == "N400 (Negative)"
            basis_txt.value[] = "-hanning(40, 20, 100)"
        elseif val == "P100 (Positive)"
            basis_txt.value[] = "hanning(10, 5, 100)"
        elseif val == "P300 (Positive)"
            basis_txt.value[] = "hanning(30, 15, 100)"
        end
        notify(basis_txt.value)
    end

    # 4. DYNAMIC UI 
    model_ui = Bonito.map(model_category.value) do m
        common_with_contrast = Bonito.DOM.div(
            Bonito.DOM.span("Basis Function", style=label_s), basis_txt,
            Bonito.DOM.span("Contrast Coding", style=label_s), contrast_type,
            Bonito.map(contrast_type.value) do c
                c == "HypothesisCoding" ?
                    Bonito.DOM.div(Bonito.DOM.span("Matrix", style=label_s), hyp_matrix_txt) :
                    Bonito.DOM.div()
            end
        )

        common_no_contrast = Bonito.DOM.div(
            Bonito.DOM.span("Basis Function", style=label_s), basis_txt
        )

        if m == "Linear Model"
            return Bonito.DOM.div(
                common_with_contrast,
                Bonito.DOM.span("Formula", style=label_s), formula_txt,
                Bonito.DOM.span("β (Intercept)", style=label_s), beta_slider,
                Bonito.DOM.span("Contrast", style=label_s), contrast_slider
            )
        elseif m == "Mixed Model"
            return Bonito.DOM.div(
                common_with_contrast,
                Bonito.DOM.span("Formula", style=label_s), formula_txt,
                Bonito.DOM.span("β", style=label_s), beta_slider,
                Bonito.DOM.span("σs (Random Effect)", style=label_s), mixed_sigma
            )
        else
            return Bonito.DOM.div(
                common_no_contrast,
                Bonito.DOM.span("Projection Vector", style=label_s), projection_txt
            )
        end
    end

    design_ui = Bonito.map(design_category.value) do d
        if d == "Single-subject design"
            return Bonito.DOM.div(
                Bonito.DOM.span("Single-subject configuration active.", style="font-style:italic; color:#888")
            )
        elseif d == "Repeat design"
            return Bonito.DOM.div(
                Bonito.DOM.span("Repeats", style=label_s), n_items,
            )
        else
            return Bonito.DOM.div(
                Bonito.DOM.span("Subjects", style=label_s), n_subjects,
                Bonito.DOM.span("Items", style=label_s), n_items,
            )
        end
    end

    onset_ui = Bonito.map(onset_choice.value) do o
        if o == "No Onset"
            return Bonito.DOM.span("No parameters needed.", style="font-style:italic; color:#888")
        elseif o == "Uniform"
            return Bonito.DOM.div(
                Bonito.DOM.span("Width", style=label_s), u_width,
                Bonito.DOM.span("Offset", style=label_s), u_offset_uni
            )
        else
            return Bonito.DOM.div(
                Bonito.DOM.span("μ (Mu)", style=label_s), on_mu,
                Bonito.DOM.span("σ (Sigma)", style=label_s), on_sigma,
                Bonito.DOM.span("Offset", style=label_s), on_offset,
                Bonito.DOM.span("Truncate Upper", style=label_s), on_truncate
            )
        end
    end

    # 5. Graph simulation call
    results = map(
        model_category.value,
        design_category.value,
        onset_choice.value,
        noise_choice.value,
        basis_txt.value,
        formula_txt.value,
        beta_slider.value,
        contrast_slider.value,
        mixed_sigma.value,
        n_items.value,
        n_subjects.value,
        on_mu.value,
        on_sigma.value,
        on_offset.value,
        on_truncate.value,
        u_width.value,
        u_offset_uni.value,
        contrast_type.value,
        hyp_matrix_txt.value,
        noise_lvl.value,
        projection_txt.value,  
    ) do m_cat, d_cat, o_cat, n_cat,
         b_str, f_str, b_val, c_val, s_val,
         ni, ns, o_mu, o_sig, o_off, o_tr,
         uw, uoff, c_type, h_str, n_lvl, proj_str

        try
            
            if m_cat == "Mixed Model" && (d_cat == "Single-subject design" || d_cat == "Repeat design")
                error("Configuration not possible: Mixed Model with Single-subject design and Repeat-design is invalid.")
            end

            coding = if c_type == "DummyCoding"
                DummyCoding()
            elseif c_type == "EffectsCoding"
                EffectsCoding()
            elseif c_type == "HelmertCoding"
                HelmertCoding()
            elseif c_type == "SeqDiffCoding"
                SeqDiffCoding()
            elseif c_type == "HypothesisCoding"
                h_mat = include_string(Main, h_str)
                HypothesisCoding(h_mat, levels=["A", "B"])
            else
                nothing
            end

            contrast_dict = isnothing(coding) ? Dict() : Dict(:condition => coding)

            event_order_fun = shuffle

            design = if d_cat == "Single-subject design"
                SingleSubjectDesign(
                    ; conditions = Dict(:condition => ["A", "B"]),
                      event_order_function = event_order_fun,
                )
            elseif d_cat == "Repeat design"
                SingleSubjectDesign(
                    ; conditions = Dict(:condition => ["A", "B"]),
                      event_order_function = event_order_fun,
                ) |> d -> RepeatDesign(d, ni)
            else
                MultiSubjectDesign(
                    n_subjects = ns,
                    n_items    = ni,
                    subjects_between = Dict(:subjectgroup => ["All"]),
                    items_between    = Dict(:condition => ["A", "B"]),
                    both_within      = Dict{Symbol,Vector}(),
                    event_order_function = event_order_fun,
                )
            end

            p_formula = if m_cat == "Mixed Model"
                include_string(Main, "@formula(0 ~ 1 + condition + (1 + condition | subject))")
            else
                include_string(Main, f_str)
            end

            p_basis = include_string(Main, b_str)
            
            
            projection_vec = if m_cat == "Multi-channel Model"
                try
                    include_string(Main, proj_str)
                catch
                    [1.0]
                end
            else
                [1.0]
            end

            comp = if m_cat == "Mixed Model"
                MixedModelComponent(
                    ; basis    = p_basis,
                      formula  = p_formula,
                      β        = [b_val, c_val],
                      σs       = Dict(:subject => [s_val, s_val]),
                      contrasts = contrast_dict,
                )
            elseif m_cat == "Multi-channel Model"
                LinearModelComponent(; basis=p_basis, formula=@formula(0 ~ 1), β=[b_val])
            else
                LinearModelComponent(
                    ; basis=p_basis,
                      formula=p_formula,
                      β=[b_val, c_val],
                      contrasts=contrast_dict,
                )
            end

            onsets = if o_cat == "Log Normal"
                LogNormalOnset(; μ=o_mu, σ=o_sig, offset=o_off, truncate_upper=o_tr)
            elseif o_cat == "Uniform"
                UniformOnset(; width=uw, offset=uoff)
            else
                NoOnset()
            end

            noise = if n_cat == "White"
                WhiteNoise(; noiselevel=n_lvl)
            elseif n_cat == "Pink"
                PinkNoise(; noiselevel=n_lvl)
            elseif n_cat == "Red"
                RedNoise(; noiselevel=n_lvl)
            else
                NoNoise()
            end

            rng = MersenneTwister(42)
            is_no_onset = o_cat == "No Onset"
            
            # Simulate data
            data,  _ = simulate(rng, design, comp, onsets, noise; return_epoched=is_no_onset) 
            clean, _ = simulate(rng, design, comp, onsets, NoNoise(); return_epoched=is_no_onset)

            # Extracting data for plotting 
            function extract_plot_vec(raw_data, m_cat, d_cat, ns)
                if m_cat == "Multi-channel Model" && d_cat == "Multi-subject design"
                    
                    if raw_data isa AbstractArray && ndims(raw_data) == 3
                      
                        avg_data = mean(raw_data, dims=3)
                        return vec(avg_data)
                    elseif raw_data isa Matrix
                        
                        if size(raw_data, 2) == ns
                           
                            return mean(raw_data, dims=2)[:, 1]
                        else
                            return raw_data[:, 1]
                        end
                    else
                        return raw_data
                    end
                else
                    
                    if raw_data isa AbstractArray && ndims(raw_data) == 3
                        return vec(raw_data[:, :, 1])
                    elseif raw_data isa Matrix
                        return raw_data[:, 1]
                    else
                        return raw_data
                    end
                end
            end

            y_noisy = extract_plot_vec(data, m_cat, d_cat, ns)
            y_clean = extract_plot_vec(clean, m_cat, d_cat, ns)
            
            t = range(0, length=length(y_noisy), step=1/100)

            return (noisy = Point2f.(t, y_noisy),
                    clean = Point2f.(t, y_clean),
                    err   = ""::String)
        catch e
            return (noisy = [Point2f(0, 0)],
                    clean = [Point2f(0, 0)],
                    err   = sprint(showerror, e)::String)
        end
    end

    # 6. LAYOUT 
    fig = Figure(size=(900, 800))
    ax  = Axis(fig[1, 1], title="UnfoldSim GUI", xlabel="Time (s)", ylabel="µV")

    # text box for error message
    text!(ax, 0.5, 0.5, text = map(d -> d.err, results), align = (:center, :center), color = :red, space = :relative)

    lines!(ax, map(d -> d.noisy, results), color=(:black, 0.4), label="Noisy")
    lines!(ax, map(d -> d.clean, results), color=:red, linewidth=2, label="Clean")
    axislegend(ax)

    sidebar = Bonito.DOM.div(
        Bonito.DOM.h3("Simulation Dashboard"),
        Bonito.DOM.div(Bonito.DOM.h4("Hanning Presets"), hanning_preset, style=card_s),
        Bonito.DOM.div(Bonito.DOM.h4("1. Model Configuration"), model_category, model_ui, style=card_s),
        Bonito.DOM.div(Bonito.DOM.h4("2. Design Configuration"), design_category, design_ui, style=card_s),
        Bonito.DOM.div(Bonito.DOM.h4("3. Onset Configuration"), onset_choice, onset_ui, style=card_s),
        Bonito.DOM.div(
            Bonito.DOM.h4("4. Global Noise"), noise_choice,
            Bonito.map(noise_choice.value) do n
                n == "No Noise" ?
                    Bonito.DOM.span("No parameters", style="font-style:italic; color:#888") :
                    noise_lvl
            end, style=card_s),
        style="grid-column: 1; padding: 20px; background: #f9f9f9; border-right: 1px solid #ddd; height: 100vh; overflow-y: auto;",
    )

    return Bonito.DOM.div(
        sidebar,
        Bonito.DOM.div(fig, style="grid-column: 2; padding: 20px;"),
        style="display: grid; grid-template-columns: 380px 1fr; font-family: sans-serif;",
    )
end

app