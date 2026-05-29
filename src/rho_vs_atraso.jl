module RhoVsAtraso
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


const iterations = 1_000
const rho_for_betweeness = 1e-2
const hdf5_filename::String = "varying_message_generation"

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
                observers=[ObserverEdgeQueue(), ObserverEdgeCapacity(iterations - 1)]
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


function __preprocess_data()
    open_raw_results(hdf5_filename, "r") do hfile
        sim_results = hfile["simulations_results"]
        data = map(sim_results) do sim_result
            json_config = get_json(sim_result)
            free_flow_rates = sim_result["free_flow_rates"][string(iterations - 1)][:]
            return (
                msg_generation=Float64(json_config.message_generation),
                graph_type=String(json_config.graph_generation_info["graph_type"]),
                avg_delay=get_avg_delay(sim_result),
                avg_traveling_time=get_avg_traveling_time(sim_result),
                avg_free_flow=Statistics.mean(free_flow_rates)
            )
        end
        df = DataFrame(data)
        sort!(df, :graph_type)
        return df
    end
end


function __plot_rho_vs_efficiency(df_efficiency, df_rho_critico_estimado)
    size = (500, 500)
    fig_delay = Figure(size=size)
    fig_travel = Figure(size=size)
    fig_free_flow = Figure(size=size)
    ax_free_flow = Axis(fig_free_flow[1, 1];
        xlabel=L"Geração de mensagens ($\rho$)",
        ylabel="Fluxo livre médio (100%)",
        xscale=log10,
        yminorgridcolor=:gray85,
        yminorgridvisible=true,
        yminorticks=IntervalsBetween(9),)
    ylims!(ax_free_flow, 0, 110)
    ax_delay = Axis(fig_delay[1, 1];
        xlabel=L"Geração de mensagens ($\rho$)",
        ylabel=L"Atraso médio ($\delta$)",
        xscale=log10,
        yscale=log10,
    )
    ax_travel = Axis(fig_travel[1, 1];
        xlabel=L"Geração de mensagens ($\rho$)",
        ylabel="Tempo médio de viagem",
        xscale=log10,
        yscale=log10,
    )

    graph_avg_distance = Dict{String,Float64}()
    graph_stats = CSV.read("thesis/assets/tables/graph_stats.csv", DataFrame)
    graph_avg_distance = Dict(row.graph_type => row.L for row in eachrow(graph_stats))

    for (g_type, sub_df) in pairs(groupby(df_efficiency, :graph_type))
        color = topology_to_color[g_type.graph_type]
        scatter!(ax_delay, sub_df.msg_generation, sub_df.avg_delay,
            color=color, label=g_type.graph_type)
        scatter!(ax_travel, sub_df.msg_generation, sub_df.avg_traveling_time,
            color=color, label=g_type.graph_type)
        hlines!(ax_travel, graph_avg_distance[g_type.graph_type],
            color=color, linestyle=:dash, linewidth=3, alpha=0.5)
        scatter!(ax_free_flow, sub_df.msg_generation, 100 .* sub_df.avg_free_flow,
            color=color, label=g_type.graph_type)
        vlines!(ax_delay, df_rho_critico_estimado[df_rho_critico_estimado.graph_type.==g_type.graph_type, :rho_critico_estimado],
            color=color, linestyle=:dash, linewidth=3, alpha=0.7)
    end

    Legend(fig_delay[0, 1], ax_delay,
        orientation=:horizontal,
        nbanks=2,
        tellwidth=false,
        tellheight=true,
        labelsize=14,
        framevisible=true
    )

    Legend(fig_travel[0, 1], ax_travel,
        orientation=:horizontal,
        nbanks=2,
        tellwidth=false,
        tellheight=true,
        labelsize=14)
    Legend(fig_free_flow[0, 1], ax_free_flow,
        orientation=:horizontal,
        nbanks=2,
        tellwidth=false,
        tellheight=true,
        labelsize=14)

    save_figure("p_critico_delay", fig_delay)
    save_figure("p_critico_travel", fig_travel)
    save_figure("p_critico_free_flow", fig_free_flow)
end



function __preprocess_betweeness_data()
    open_raw_results(hdf5_filename, "r") do hfile
        simulations = hfile["simulations_results"]
        rho_val = argmin(x -> abs(x - rho_for_betweeness), rhos)
        target_keys = filter(sim -> get_json(simulations[sim]).message_generation == rho_val, keys(simulations))

        data = map(target_keys) do sim_key
            sim = simulations[sim_key]
            messages = [x.total_num_messages_processed for x in sim["edges_attributes"][:]]
            betweeness = hfile["graphs"][get_graph_hdf5_uuid(sim)]["edge_betweeness"][:]
            graph_type = get_json(sim).graph_generation_info["graph_type"]

            valid_idx = (messages .> 5e1)
            m_filtered = messages[valid_idx]
            b_filtered = betweeness[valid_idx]

            fit = LsqFit.curve_fit((x, p) -> p[1] .* x, b_filtered, m_filtered ./ iterations, [1.0])
            errors = LsqFit.stderror(fit)

            return (
                graph_type=graph_type,
                messages=messages,
                betweeness=betweeness,
                R_squared=Statistics.cor(m_filtered, b_filtered)^2,
                α=fit.param[1],
                Δα=errors[1],
            )
        end
        return DataFrame(data)
    end
end


function __plot_betweeness_vs_messages(df)
    fig = Figure(size=(700, 700))
    sort!(df, :graph_type)
    axes = []
    for (i, row_data) in enumerate(eachrow(df))
        row = (i - 1) ÷ 2 + 1
        col = (i - 1) % 2 + 1

        messages = row_data.messages
        betweeness = row_data.betweeness
        valid_idx = (messages .> 0) .& (betweeness .> 0)
        m_filtered = messages[valid_idx]
        b_filtered = betweeness[valid_idx]

        y_lims = (minimum(m_filtered) * 0.9, maximum(m_filtered) * 1.15)
        x_lims = (minimum(b_filtered) * 0.9, maximum(b_filtered) * 1.15)

        ax = Axis(fig[row, col];
            xlabel=L"Centralidade de intermediação ($b_e$)",
            ylabel="Mensagens",
            limits=(x_lims, y_lims),
            log_x_log_y_style...
        )
        push!(axes, ax)

        scatter!(ax, betweeness, messages, alpha=0.2,
            color=topology_to_color[row_data.graph_type], label=row_data.graph_type)

        axislegend(ax, position=:lt)
    end
    linkyaxes!(axes[1], axes[2:end]...)
    linkxaxes!(axes[1], axes[2:end]...)
    stats_df = select(df, Not([:messages, :betweeness]))
    save_dataframe_to_csv(stats_df, "betweeness_vs_messages")
    save_figure("p_critico_betweeness", fig)
    return fig
end


function plot()
    df_efficiency = __preprocess_data()
    df_betweeness = __preprocess_betweeness_data()
    println(df_betweeness)
    df_rho_critico_estimado = DataFrame(graph_type=String[], rho_critico_estimado=Float64[])
    N = GraphTraffic.SharedData.N
    for row in eachrow(df_betweeness)
        rho_critico_estimado = 1 / (N * maximum(row.betweeness))
        push!(df_rho_critico_estimado, (graph_type=row.graph_type, rho_critico_estimado=rho_critico_estimado))
    end
    __plot_betweeness_vs_messages(df_betweeness)
    __plot_rho_vs_efficiency(df_efficiency, df_rho_critico_estimado)
end
end

