module RhoVsAtrasoAdaptedCapacity
include("GraphTraffic.jl")
using .GraphTraffic.Engine
using .GraphTraffic.Schema
using .GraphTraffic.Topology
using .GraphTraffic.Analysis
using .GraphTraffic.ColorPalette: topology_to_color
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


sampling_time = 200
num_samplings = 100
iterations = num_samplings * sampling_time
rhos = range_logarithmic(start=1e-3, stop=0.25, length=20)
free_flow_rate::Float64 = 0.99
minimal_capacity::Int = 1
multiplier::Float64 = 4
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
                warm_up_iterations=Int(0.8 * num_samplings),
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
                warm_up_iterations=Int(0.8 * num_samplings),
                graph_generation_info=Dict("graph_type" => graph_type, "is_adapted_capacity" => false),
                observers=GraphTraffic.Schema.ObserversUnion[ObserverEdgeCapacity(sampling_time)]
            ))
        end
    end
    run_rust_cli(simulations, hdf5_filename, force_overwrite=true)
end


function plot()
    open_raw_results(hdf5_filename, "r") do hfile
        fig_delay = Figure(size=(900, 550))
        fig_capacity = Figure(size=(900, 550))
        adaptado_title = "Capacidade adaptada"
        sem_adaptado_title = "Capacidade fixa"
        ax_capacity_adapted = Axis(fig_capacity[1, 1],
            xlabel=L"Geração de mensagens ($\rho$)",
            ylabel=L"\frac{\text{Capacidade total}}{E}",
            xscale=log10,
            yscale=log10,
            xlabelsize=18,
            ylabelsize=18,
            title=adaptado_title,
            titlesize=20,
            xticklabelsize=14,
            yticklabelsize=14
        )

        ax_capacity_not_adapted = Axis(fig_capacity[1, 2],
            xscale=log10,
            yscale=log10,
            xlabelsize=18,
            ylabelsize=18,
            title=sem_adaptado_title,
            titlesize=20,
            xticklabelsize=14,
            yticklabelsize=14
        )

        ax_delay_adapted = Axis(fig_delay[1, 1],
            xlabel=L"Geração de mensagens ($\rho$)",
            ylabel=L"Atraso médio ($\delta$)",
            xlabelsize=18,
            xscale=log10,
            yscale=log10,
            ylabelsize=18,
            title=adaptado_title,
            titlesize=20,
            xticklabelsize=14,
            yticklabelsize=14
        )

        ax_delay_not_adapted = Axis(fig_delay[1, 2],
            xlabelsize=18,
            xscale=log10,
            yscale=log10,
            ylabelsize=18,
            title=sem_adaptado_title,
            titlesize=20,
            xticklabelsize=14,
            yticklabelsize=14
        )

        sim_results = hfile["simulations_results"]
        y_max_delay = -Inf
        y_min_delay = Inf
        y_max_capacity = -Inf
        y_min_capacity = Inf
        legend_plots = Dict{String,Any}()
        for sim_result in sim_results
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

            target_delay_axis = is_adapted_capacity ? ax_delay_adapted : ax_delay_not_adapted
            target_capacity_axis = is_adapted_capacity ? ax_capacity_adapted : ax_capacity_not_adapted
            scatter!(target_delay_axis, msg_generation, get_avg_delay(sim_result),
                color=topology_to_color[graph_type], strokewidth=1.2)
            errorbars!(target_capacity_axis, [msg_generation], [mean_val], [std_val],
                color=topology_to_color[graph_type], linewidth=2, alpha=0.35)
            scatter!(target_capacity_axis, msg_generation, mean_val,
                color=topology_to_color[graph_type]
            )
            lines!(target_capacity_axis, [msg_generation], [mean_val],
                color=topology_to_color[graph_type])
            if !haskey(legend_plots, graph_type)
                legend_plots[graph_type] = scatter!(target_capacity_axis, Float64[], Float64[],
                    color=topology_to_color[graph_type], label=graph_type)
            end
            y_max_delay = max(y_max_delay, get_avg_delay(sim_result))
            y_min_delay = min(y_min_delay, get_avg_delay(sim_result))
            y_max_capacity = max(y_max_capacity, mean_val)
            y_min_capacity = min(y_min_capacity, mean_val)

        end
        for ax in (ax_delay_adapted, ax_delay_not_adapted)
            ylims!(ax, (0.8y_min_delay, 1.2y_max_delay))
        end

        for ax in (ax_capacity_adapted, ax_capacity_not_adapted)
            ylims!(ax, (0.8y_min_capacity, 1.2y_max_capacity))
        end
        # for (graph_type, plot) in legend_plots
        #     axislegend(ax_capacity_adapted, plot, position=:lt, framevisible=true, labelsize=12, patchsize=(18, 12))
        # end

        save_figure("p_critico_travel_adapted_capacity", fig_delay)
        save_figure("p_critico_capacity_adapted_capacity", fig_capacity)
    end
end

const main = make_cli(generate_data, plot)
end


if abspath(PROGRAM_FILE) == @__FILE__
    RhoVsAtrasoAdaptedCapacity.main(ARGS)
end
