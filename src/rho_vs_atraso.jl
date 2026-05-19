module RhoVsAtraso
include("src/GraphTraffic.jl")
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


iterations = 1000
rhos = range_logarithmic(start=1e-3, stop=1.0, length=100)
hdf5_filename::String = "varying_message_generation"

function generate_data()
    simulations::GraphTraffic.Schema.SimulationConfiguration = []
    barabasi, erdos, rgg, watts = connect_and_compare_graphs(
        barabasi_graph, erdos_graph, rgg_graph, watts_graph
    )
    graph_stats = DataFrame(graph_type=String[], graph_filename=String[], N=Int[], E=Int[], D=Int[], L=Float64[], C=Float64[])
    for (graph_type, g) in [(barabasi_name, barabasi), (erdos_name, erdos), (rgg_name, rgg), (watts_name, watts)]
        graph_filename::String = temp_save_edgelist(g)
        push!(graph_stats, (
            graph_type=graph_type,
            graph_filename=graph_filename,
            N=nv(g),
            E=ne(g),
            L=avg_distance(g),
            C=Graphs.Parallel.global_clustering_coefficient(g),
            D=Graphs.diameter(g)
        ))
        for rho in rhos
            push!(simulations, SimulationConfigurationItem(uuid=UUIDs.uuid4(),
                routing_method="minimal_paths",
                graph_file_name=graph_filename,
                message_generation=rho,
                max_iterations=iterations,
                graph_generation_info=Dict("graph_type" => graph_type),
                modifiers=Vector{GraphTraffic.Schema.ModifiersUnion}(),
                observers=GraphTraffic.Schema.ObserversUnion[ObserverEdgeQueue("ObserverEdgeQueue"), ObserverEdgeCapacity("ObserverEdgeCapacity", iterations - 1)]
            ))
        end
    end
    save_dataframe_to_csv(graph_stats, "graph_stats")
    run_rust_cli(simulations, hdf5_filename, force_overwrite=true)
    open_raw_results(hdf5_filename, "r+") do hfile
        graphs_group = hfile["graphs"]
        for graph_group in graphs_group
            graph = get_graph(graph_group)
            graph_group["edge_betweeness"] = edge_betweeness_normalized(graph)
        end
        for simulation in hfile["simulations_results"]
            free_flow_rates = calculate_edge_free_flow_rate(simulation)
            group_free_flow_rates = HDF5.create_group(simulation, "free_flow_rates")
            for time in keys(free_flow_rates)
                group_free_flow_rates[string(time)] = free_flow_rates[time]
            end
        end
    end
end


function plot_p_vs_mensagens()
    open_raw_results(hdf5_filename, "r") do hfile
        fig_delay = Figure()
        fig_travel = Figure()
        fig_free_flow = Figure()
        ax_free_flow = Axis(fig_free_flow[1, 1],
            xlabel=L"Geração de mensagens ($\rho$)",
            ylabel="Fluxo livre",
            xscale=log10,
            yscale=log10,
            xlabelsize=18,
            ylabelsize=18
        )

        ax_delay = Axis(fig_delay[1, 1],
            xlabel=L"Geração de mensagens ($\rho$)",
            ylabel=L"Atraso médio ($\delta$)",
            xscale=log10,
            yscale=log10,
            xlabelsize=18,
            ylabelsize=18
        )
        ax_travel = Axis(fig_travel[1, 1],
            xlabel=L"Geração de mensagens ($\rho$)",
            ylabel="Tempo médio de viagem",
            xscale=log10,
            yscale=log10,
            xlabelsize=18,
            ylabelsize=18
        )

        sim_results = hfile["simulations_results"]

        plotted::Set{String} = Set{String}()
        for sim_result in sim_results
            json_config = get_json(sim_result)
            msg_generation::Float64 = json_config.message_generation
            graph_type::String = json_config.graph_generation_info["graph_type"]
            label = (graph_type in plotted) ? nothing : graph_type
            free_flow_rates = sim_result["free_flow_rates"]["999"][:]
            free_flow_rates_avg::Float64 = Statistics.mean(free_flow_rates)
            scatter!(ax_delay, msg_generation, get_avg_delay(sim_result),
                color=topology_to_color[graph_type], label=label)
            scatter!(ax_travel, msg_generation, get_avg_traveling_time(sim_result),
                color=topology_to_color[graph_type], label=label)
            scatter!(ax_free_flow, msg_generation, free_flow_rates_avg,
                color=topology_to_color[graph_type], label=label)
            push!(plotted, graph_type)
        end
        axislegend(ax_delay, position=:lt)
        axislegend(ax_travel, position=:lt)
        axislegend(ax_free_flow, position=:lt)
        save_figure("p_critico_delay", fig_delay)
        save_figure("p_critico_travel", fig_travel)
        save_figure("p_critico_free_flow", fig_free_flow)
    end
end



function plot_betweeness_vs_messages()
    open_raw_results(hdf5_filename, "r") do hfile
        simulations = hfile["simulations_results"]
        rho = argmin(x -> abs(x - 1e-2), rhos)
        sims_uuid::Matrix{String} = reshape(
            filter(sim -> get_json(simulations[sim]).message_generation == rho, keys(simulations)),
            (2, 2))
        fig = Figure()

        df = DataFrame(graph_type=String[], R_squared=Float64[], α=Float64[], Δα=Float64[], β=Float64[], Δβ=Float64[])
        for row in 1:2
            for col in 1:2
                sim = hfile["simulations_results"][sims_uuid[row, col]]
                messages = [x.total_num_messages_processed for x in sim["edges_attributes"][:]]
                betweeness = hfile["graphs"][get_graph_hdf5_uuid(sim)]["edge_betweeness"][:]
                valid_idx = (messages .> 0) .& (betweeness .> 0)
                m_filtered = messages[valid_idx]
                b_filtered = betweeness[valid_idx]
                y_lims = (minimum(m_filtered) * 0.9, maximum(m_filtered) * 1.15)
                x_lims = (minimum(b_filtered) * 0.9, maximum(b_filtered) * 1.15)

                ax = Axis(fig[row, col],
                    xlabel=L"Centralidade de intermediação ($b_e$)",
                    ylabel="Mensagens",
                    xscale=log10,
                    yscale=log10,
                    limits=(x_lims, y_lims)
                )
                scatter!(ax, betweeness, messages, alpha=0.2, color=topology_to_color[get_json(sim).graph_generation_info["graph_type"]])
                fit = LsqFit.curve_fit((x, p) -> p[1] .* x .+ p[2], betweeness, messages, [1.0, 1.0])
                errors = LsqFit.stderror(fit)
                push!(df, (
                    graph_type=get_json(sim).graph_generation_info["graph_type"],
                    R_squared=Statistics.cor(m_filtered, b_filtered)^2,
                    α=fit.param[1],
                    Δα=errors[1],
                    β=fit.param[2],
                    Δβ=errors[2]
                )
                )
            end
        end
        save_dataframe_to_csv(df, "betweeness_vs_messages")
        save_figure("p_critico_betweeness", fig)
    end
end

function plot()
    plot_betweeness_vs_messages()
    plot_p_vs_mensagens()
end

const main = make_cli(generate_data, plot)
end


if abspath(PROGRAM_FILE) == @__FILE__
    RhoVsAtraso.main(ARGS)
end
