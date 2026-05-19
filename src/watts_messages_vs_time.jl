module WattsStrogatzBetaVsLAndC
include("src/GraphTraffic.jl")
using .GraphTraffic.Engine
using .GraphTraffic.Schema
using .GraphTraffic.Topology
using .GraphTraffic.Analysis
using .GraphTraffic.ColorPalette: topology_to_color
using Graphs
using UUIDs
using CairoMakie
using Statistics
using HDF5
N = 3_000
E = 9_000
iterations = 1000
rho = 1e-3

hdf5_filename = "watts_strogatz_varying_beta"

function generate_data()
    βs = [2.5e-3, 5e-3, 1e-2, 5e-2]
    graphs = connect_and_compare_graphs([LazyGraph(watts_strogatz_given_m, (N, E, β)) for β in βs]...)
    simulations::GraphTraffic.Schema.SimulationConfiguration = []
    for graph in graphs
        graph_filename = temp_save_edgelist(graph)
        push!(simulations, SimulationConfigurationItem(uuid=UUIDs.uuid4(),
            routing_method="minimal_paths",
            max_visibility=nothing,
            graph_file_name=graph_filename,
            message_generation=rho,
            max_iterations=iterations,
            warm_up_iterations=nothing,
            random_seed=nothing,
            observers=[ObserverTotalMessages("ObserverTotalMessages")],
        ))
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

        ls = Float64[]
        for uuid in keys(sims)
            sim = sims[uuid]
            graph = get_graph(hfile["graphs"][get_graph_hdf5_uuid(sim)])
            push!(ls, avg_distance(graph))
        end
        p = sortperm(ls)
        ls = ls[p]
        sims_keys = collect(keys(sims))[p]
        full_cmap = cgrad(:inferno)
        truncated_cmap = cgrad(full_cmap[range(0, 0.75, length=256)])
        y_max = 0
        l_min, l_max = extrema(ls)
        for (uuid, ax, l) in zip(sims_keys, axes, ls)
            sim = sims[uuid]
            graph = get_graph(hfile["graphs"][get_graph_hdf5_uuid(sim)])
            messages = sim["ObserverTotalMessages"][:]
            avg_messages = messages
            μ_l = N * rho * l
            σ_l = sqrt(N * rho * (1 - rho)) * l
            n_color = (l - l_min) / (l_max - l_min) * 0.75
            color = truncated_cmap[n_color]
            scatter!(ax, avg_messages, alpha=0.15, color=color)
            hlines!(ax, μ_l, color=:black, linestyle=:dash, linewidth=2)
            band!(ax, 1:length(avg_messages), fill(μ_l - σ_l, length(avg_messages)), fill(μ_l + σ_l, length(avg_messages)), color=(color, 0.3))
            text!(ax, 3, μ_l, text=L"\mu", color=:black, align=(:left, :bottom), fontsize=18, font=:bold)
            text!(ax, 3, μ_l + 1.1σ_l, text=L"\mu + \sigma", color=:black, align=(:left, :bottom), fontsize=14)
            text!(ax, 3, μ_l - 1.1σ_l, text=L"\mu - \sigma", color=:black, align=(:left, :top), fontsize=14)
            y_max = max(y_max, maximum(avg_messages), μ_l + σ_l)
        end
        for ax in axes
            ylims!(ax, (1, y_max * 1.2))
        end
        Colorbar(fig[:, end+1], limits=(l_min, l_max), colormap=truncated_cmap, label=L"Distância média $\langle L \rangle$")
        save_figure("watts_messages_vs_time", fig)
    end
end
main = make_cli(WattsStrogatzBetaVsLAndC.generate_data, WattsStrogatzBetaVsLAndC.plot)

end


if abspath(PROGRAM_FILE) == @__FILE__
    WattsStrogatzBetaVsLAndC.main(ARGS)
end
