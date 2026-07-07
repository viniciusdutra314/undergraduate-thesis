module WattsStrogatzBetaVsLAndC
include("GraphTraffic.jl")
using .GraphTraffic.Engine
using .GraphTraffic.Schema
using .GraphTraffic.Topology
using .GraphTraffic.Analysis
using .GraphTraffic.Style
using Graphs
using UUIDs
using CairoMakie
using Statistics
using HDF5
const N = 3_000
const E = 9_000
const iterations = 1000
const rho = 1e-3
const repetitions = 10

const hdf5_filename = "watts_strogatz_varying_beta"

function generate_data()
    βs_watts = [2.5e-3, 5e-3, 1e-2, 5e-2]
    graphs = connect_and_compare_graphs([LazyGraph(watts_strogatz_given_m, (N, E, β)) for β in βs_watts]...)
    simulations::GraphTraffic.Schema.SimulationConfiguration = []
    for graph in graphs
        graph_filename = temp_save_edgelist(graph)
        for repetition in 1:repetitions
            push!(simulations, SimulationConfigurationItem(uuid=UUIDs.uuid4(),
                routing_method="minimal_paths",
                graph_file_name=graph_filename,
                message_generation=rho,
                max_iterations=iterations,
                observers=[ObserverTotalMessages("ObserverTotalMessages")],
            ))
        end
    end
    run_rust_cli(simulations, "watts_strogatz_varying_beta", force_overwrite=true)
end

function plot()
    open_raw_results(hdf5_filename, "r") do hfile
        x = 250
        fig = Figure(size=(4x, x))
        axes = [Axis(fig[1, i],
            xlabel=i == 1 ? "Tempo" : "",
            ylabel=i == 1 ? "Total de mensagens na rede" : "",
            xscale=log10
        ) for i in 1:4]
        sims = hfile["simulations_results"]

        l_to_messages = Dict{Float64,Vector{Vector{Float64}}}()
        for uuid in keys(sims)
            sim = sims[uuid]
            graph = get_graph(hfile["graphs"][get_graph_hdf5_uuid(sim)])
            l = avg_distance(graph)
            messages = Float64.(sim["ObserverTotalMessages"][:])
            push!(get!(l_to_messages, l, Vector{Vector{Float64}}()), messages)
        end
        ls = sort(collect(keys(l_to_messages)))
        p = sortperm(ls)
        ls = ls[p]
        full_cmap = cgrad(:inferno)
        truncated_cmap = cgrad(full_cmap[range(0, 0.75, length=256)])
        y_max = 0
        l_min, l_max = extrema(ls)
        for (ax, l) in zip(axes, ls)
            messages_matrix = reduce(hcat, l_to_messages[l])
            mean_messages = vec(mean(messages_matrix, dims=2))
            std_messages = vec(std(messages_matrix, dims=2))
            x_values = 1:length(mean_messages)
            μ_l = N * rho * l
            σ_l = sqrt(N * rho * (1 - rho)) * l
            n_color = (l - l_min) / (l_max - l_min) * 0.75
            color = truncated_cmap[n_color]
            lines!(ax, x_values, mean_messages, color=color, linewidth=2)
            band!(ax, x_values, mean_messages .- std_messages, mean_messages .+ std_messages, color=(color, 0.25))
            hlines!(ax, μ_l, color=:black, linestyle=:dash, linewidth=2)
            band!(ax, x_values, fill(μ_l - σ_l, length(mean_messages)), fill(μ_l + σ_l, length(mean_messages)), color=(color, 0.3))
            text!(ax, 3, μ_l, text=L"\mu", color=:black, align=(:left, :bottom), fontsize=18, font=:bold)
            text!(ax, 3, μ_l + 1.1σ_l, text=L"\mu + \sigma", color=:black, align=(:left, :bottom), fontsize=14)
            text!(ax, 3, μ_l - 1.1σ_l, text=L"\mu - \sigma", color=:black, align=(:left, :top), fontsize=14)
            y_max = max(y_max, maximum(mean_messages .+ std_messages), μ_l + σ_l)
        end
        for ax in axes
            ylims!(ax, (1, y_max * 1.2))
        end
        Colorbar(fig[:, end+1], limits=(l_min, l_max), colormap=truncated_cmap, label=L"Distância média $\langle L \rangle$")
        save_figure("watts_messages_vs_time", fig)
    end
end
end


