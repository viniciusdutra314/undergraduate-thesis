module VisibilidadeLimitada
include("GraphTraffic.jl")
using .GraphTraffic.Engine
using .GraphTraffic.Schema
using .GraphTraffic.Topology
using .GraphTraffic.Analysis
using .GraphTraffic.ColorPalette: topology_to_color
using .GraphTraffic.SharedData
using Graphs
using UUIDs
using CairoMakie
using Statistics
using HDF5
using NPZ


iterations = 10_000
N = 20
sampling_time::Int = div(iterations, N)
free_flow_rate::Float64 = 0.99
minimal_capacity::Int = 1
multiplier::Float64 = 4.0
rho = 1e-3
hdf5_filename = "visibilidade_limitada"

β_to_grid_position = Dict(
    βs_watts[4] => (1, 1),
    βs_watts[3] => (1, 2),
    βs_watts[2] => (2, 1),
    βs_watts[1] => (2, 2)
)

function plot_correlations()
    fig_correlations = Figure(size=(900, 900))
    β_to_axis = Dict{Float64, Axis}()
    for β in βs_watts
        row, col = β_to_grid_position[β]
        ax = Axis(fig_correlations[row, col], xlabel="Visibilidade", ylabel="Correção capacidade x intermediação")
        β_to_axis[β] = ax
    end

    

end


function plot_histograms()
    distance_histograms = NPZ.npzread("raw_results/$(hdf5_filename)_distance_histograms.npz")
    avg_lengths = Dict{Float64,Float64}()
    for (graph_type, histogram) in distance_histograms
        freqs = histogram ./ sum(histogram)
        avg_lengths[parse(Float64, graph_type)] = sum((1:length(freqs)) .* freqs)
    end
    mins = minimum(values(avg_lengths))
    maxs = maximum(values(avg_lengths))
    fig = Figure(size=(1000, 900))
    for β in βs_watts
        row, col = β_to_grid_position[β]
        histogram = distance_histograms[string(β)]
        ax = Axis(fig[row, col], xlabel="Distância", ylabel="Porcentagem (100%)",
            yscale=log10)
        freqs = histogram ./ sum(histogram)
        l = avg_lengths[β]
        t = (l - mins) / (maxs - mins)
        color = watts_cmap[t]
        barplot!(ax, 100 * freqs, color=color, label="Frequência")
        lines!(ax, 100 * (1.0 .- cumsum(freqs[1:end-1])), linewidth=2,
            label="Função Sobrevivência", color=:green, linestyle=:dash)
        axislegend(ax, position=:rt)
    end
    Colorbar(fig[1:2, 3], colormap=watts_cmap, label=L"Distância média $\langle L \rangle$", limits=(mins, maxs))
    save_figure("visibilidade_limitada_grid", fig)
end



function plot()
    plot_histograms()
end

function generate_data()
    graphs = connect_and_compare_graphs(
        [LazyGraph(watts_strogatz_given_m, (N_watts, E_watts, β)) for β in βs_watts]...
    )
    simulations::GraphTraffic.Schema.SimulationConfiguration = []
    distance_histograms = Dict{String,Vector{Int}}()
    for (g, β) in zip(graphs, βs_watts)
        graph_filename::String = temp_save_edgelist(g)
        graph_type = "$β"
        distances = hcat((dijkstra_shortest_paths(g, v).dists for v in vertices(g))...)
        diameter = maximum(distances)
        distance_histograms[graph_type] = [count(==(d), distances) for d in 1:diameter]
        for k in 1:diameter
            push!(simulations, SimulationConfigurationItem(uuid=UUIDs.uuid4(),
                routing_method=RoutingMethod(k),
                graph_file_name=graph_filename,
                message_generation=rho,
                max_iterations=iterations,
                graph_generation_info=Dict("graph_type" => graph_type),
                warm_up_iterations=Int(0.8 * N * sampling_time),
                observers=GraphTraffic.Schema.ObserversUnion[ObserverEdgeCapacity(sampling_time)],
                modifiers=[ModifierEdgeCapacity(free_flow_rate, sampling_time,
                    minimal_capacity, multiplier)],
            ))
        end
    end
    NPZ.npzwrite("raw_results/$(hdf5_filename)_distance_histograms.npz", distance_histograms)
    run_rust_cli(simulations, hdf5_filename, force_overwrite=true)
end

const main = make_cli(VisibilidadeLimitada.generate_data, VisibilidadeLimitada.plot)

end


