module RhoVsAtrasoAdaptedCapacity
include("GraphTraffic.jl")
using .GraphTraffic.Engine
using .GraphTraffic.Schema
using .GraphTraffic.Topology
using .GraphTraffic.Analysis
using .GraphTraffic.Style
using .GraphTraffic.SharedData
using JSON
using LsqFit
using HDF5
using UUIDs
using Statistics
using Graphs
using DataFrames
import Graphs.Parallel
import IGraphs
using CSV
using CairoMakie
using LaTeXStrings


sampling_time = 100
num_samplings = 200
iterations = num_samplings * sampling_time
rhos = range_logarithmic(start=1e-2, stop=0.2, length=20)
free_flow_rate::Float64 = 0.99
minimal_capacity::Int = 1
multiplier::Float64 = 1
hdf5_filename::String = "varying_message_generation_adapted_capacity"

function generate_data()
    simulations::GraphTraffic.Schema.SimulationConfiguration = []
    barabasi, erdos, watts = connect_and_compare_graphs(
        barabasi_graph, erdos_graph, watts_graph
    )
    for (graph_type, g) in [(barabasi_name, barabasi), (erdos_name, erdos), (watts_name, watts)]
        graph_filename::String = temp_save_edgelist(g)
        for rho in rhos
            push!(simulations, SimulationConfigurationItem(uuid=UUIDs.uuid4(),
                routing_method="minimal_paths",
                graph_file_name=graph_filename,
                message_generation=rho,
                max_iterations=iterations,
                warm_up_iterations=Int(0.9 * iterations),
                graph_generation_info=Dict("graph_type" => graph_type, "is_adapted_capacity" => true),
                modifiers=[ModifierEdgeCapacity(free_flow_rate, sampling_time,
                    minimal_capacity, multiplier)],
                observers=GraphTraffic.Schema.ObserversUnion[ObserverEdgeCapacity(sampling_time)]
            ))
            push!(simulations, SimulationConfigurationItem(uuid=UUIDs.uuid4(),
                routing_method="minimal_paths",
                graph_file_name=graph_filename,
                message_generation=rho,
                max_iterations=iterations,
                warm_up_iterations=Int(0.9 * iterations),
                graph_generation_info=Dict("graph_type" => graph_type, "is_adapted_capacity" => false),
                observers=GraphTraffic.Schema.ObserversUnion[ObserverEdgeCapacity(sampling_time)]
            ))
        end
    end
    run_rust_cli(simulations, hdf5_filename, force_overwrite=true)
end


function __preprocess_data()
    open_raw_results(hdf5_filename, "r") do hfile
        data = map(hfile["simulations_results"]) do sim_result
            json_config = get_json(sim_result)
            msg_generation::Float64 = json_config.message_generation
            graph_type::String = json_config.graph_generation_info["graph_type"]
            is_adapted_capacity::Bool = json_config.graph_generation_info["is_adapted_capacity"]
            graph = get_graph(hfile["graphs"][get_graph_hdf5_uuid(sim_result)])
            E = ne(graph)
            capacities_over_time = get_edge_capacity(sim_result)
            capacities = reduce(hcat, values(capacities_over_time))
            total_capacity = sum(capacities, dims=1)
            mean_val = mean(total_capacity ./ E)
            std_val = std(total_capacity ./ E)
            return (
                graph_type=graph_type,
                is_adapted_capacity=is_adapted_capacity,
                msg_generation=msg_generation,
                mean_capacity_over_E=mean_val,
                std_capacity_over_E=std_val,
                avg_traveling_time=get_avg_traveling_time(sim_result)
            )
        end
        DataFrame(data)
    end

end


function plot()
    df = __preprocess_data()
    sort!(df, [:graph_type, :msg_generation])
    fig_traveling_time = Figure(size=(900, 550))
    fig_capacity = Figure(size=(450, 550))
    xlabel = L"Geração de mensagens ($\rho$)"
    ylabel_traveling_time = "Tempo médio de viagem"
    ax_capacity = Axis(fig_capacity[1, 1];
        xlabel=xlabel,
        ylabel="Capacidade total por aresta",
        log_x_style...,
    )

    ax_traveling_time_adapted = Axis(fig_traveling_time[1, 1];
        title="Capacidade adaptada",
        xlabel=xlabel,
        ylabel=ylabel_traveling_time,
        log_x_log_y_style...
    )

    ax_traveling_time_not_adapted = Axis(fig_traveling_time[1, 2];
        title="Capacidade fixa",
        xlabel=xlabel,
        ylabel=ylabel_traveling_time,
        log_x_log_y_style...
    )
    linkyaxes!(ax_traveling_time_adapted, ax_traveling_time_not_adapted)

    for sub_df in groupby(df, [:graph_type, :is_adapted_capacity])
        is_adapted = first(sub_df.is_adapted_capacity)
        graph_type = first(sub_df.graph_type)
        color = topology_to_color[graph_type]
        traveling_time_axis = is_adapted ? ax_traveling_time_adapted : ax_traveling_time_not_adapted
        scatter!(traveling_time_axis, sub_df.msg_generation, sub_df.avg_traveling_time,
            color=color, label=graph_type)
        errorbars!(ax_capacity, sub_df.msg_generation, sub_df.mean_capacity_over_E, sub_df.std_capacity_over_E,
            color=color, alpha=0.35)
        if is_adapted
            scatter!(ax_capacity, sub_df.msg_generation, sub_df.mean_capacity_over_E,
                color=color, label=graph_type)
        end
    end
    hlines!(ax_capacity, 1.0, color=:black, linestyle=:dash, label="Capacidade fixa")

    for ax in (ax_capacity, ax_traveling_time_adapted)
        axislegend(ax,
            position=:lt,
            margin=(15, 15, 15, 15),
            padding=(10, 10, 10, 10)
        )
    end
    save_figure("p_critico_travel_adapted_capacity", fig_traveling_time)
    save_figure("p_critico_capacity_adapted_capacity", fig_capacity)
end

const main = make_cli(generate_data, plot)
end

