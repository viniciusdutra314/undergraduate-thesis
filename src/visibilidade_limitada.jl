module VisibilidadeLimitada
include("GraphTraffic.jl")
using .GraphTraffic.Engine
using .GraphTraffic.Schema
using .GraphTraffic.Topology
using .GraphTraffic.Analysis
using .GraphTraffic.Style
using .GraphTraffic.SharedData
using Graphs
using UUIDs
using CairoMakie
using Statistics
using DataFrames
using HDF5
using NPZ

const sampling_time = 100
const num_samplings = 50
const iterations = num_samplings * sampling_time
const repetitions = 10
const free_flow_rate::Float64 = 0.99
const minimal_capacity::Int = 1
const multiplier::Float64 = 1
const rho::Float64 = 1e-1
const hdf5_filename = "visibilidade_limitada"

const β = βs_watts[3]
const color = (:midnightblue, 0.75)
function generate_data()
    g = first(connect_and_compare_graphs(LazyGraph(watts_strogatz_given_m, (N_watts, E_watts, β))))
    simulations::GraphTraffic.Schema.SimulationConfiguration = []
    distance_histogram::Vector{Int} = []
    graph_filename::String = temp_save_edgelist(g)
    distances = hcat(collect(Iterators.flatten([(dijkstra_shortest_paths(g, v).dists for v in vertices(g))]...))...)
    diameter = maximum(distances)
    for d in 1:diameter
        push!(distance_histogram, count(==(d), distances))
    end
    for k in 1:diameter
        for repetition in 1:repetitions
            push!(simulations, SimulationConfigurationItem(uuid=UUIDs.uuid4(),
                routing_method=RoutingMethod(k),
                graph_file_name=graph_filename,
                message_generation=rho,
                max_iterations=iterations,
                warm_up_iterations=Int(0.8 * iterations),
                observers=GraphTraffic.Schema.ObserversUnion[ObserverEdgeCapacity(sampling_time)],
                modifiers=[ModifierEdgeCapacity(free_flow_rate, sampling_time,
                    minimal_capacity, multiplier)],
            ))
        end
    end
    npzwrite("raw_results/$(hdf5_filename)_distance_histograms.npy", distance_histogram)
    run_rust_cli(simulations, hdf5_filename, force_overwrite=true)
end

function __preprocess_correlations()
    df = open_raw_results(hdf5_filename, "r") do hfile
        betweeness::Vector{Float64} = []
        graph_uuid = first(keys(hfile["graphs"]))
        g = get_graph(hfile["graphs"][graph_uuid])
        betweeness = edge_betweeness_normalized(g)
        sims = hfile["simulations_results"]
        data = map(sims) do sim
            json = get_json(sim)
            visibility::Int64 = json["routing_method"]["limited_visibility"]
            capacities_over_time = get_edge_capacity(sim)
            capacities_array = reduce(hcat, values(capacities_over_time))
            mean_capacity = mean(capacities_array, dims=2)
            valid_indices = findall(!=(1), mean_capacity)

            r_squared = if isempty(valid_indices)
                NaN
            else
                cor(mean_capacity[valid_indices], betweeness[valid_indices])^2
            end

            μ = mean(mean_capacity)
            σ = std(mean_capacity)
            return (
                visibility=visibility,
                r_squared=r_squared,
                cv_capacity=σ / μ,
                mean_capacity=μ,
                sigma_capacity=σ,
                avg_distance=get_avg_traveling_time(sim)
            )
        end
        df = DataFrame(data)
        df = combine(groupby(df, :visibility),
            :r_squared => mean => :r_squared_mean,
            :r_squared => std => :r_squared_std,
            :cv_capacity => mean => :cv_capacity_mean,
            :cv_capacity => std => :cv_capacity_std,
            :mean_capacity => mean => :mean_capacity_mean,
            :mean_capacity => std => :mean_capacity_std,
            :avg_distance => mean => :avg_distance_mean,
            :avg_distance => std => :avg_distance_std,
        )
        return filter(row -> !isnan(row.r_squared_mean), df)
    end
end

function __plot_correlations(df)


    fig = Figure(size=(750, 650))
    xticks = 0:10:maximum(df.visibility)
    sort!(df, :visibility)

    ax_intermediação = Axis(fig[1, 1];
        xlabel="Visibilidade",
        ylabel="Intermediação x Capacidade (R² x 100)",
        xticks=xticks,
        yticks=0:25:100,
    )
    ylims!(ax_intermediação, -5, 105)
    scatter!(ax_intermediação, df.visibility, 100 * df.r_squared_mean, color=color)
    errorbars!(ax_intermediação, df.visibility, 100 * df.r_squared_mean, 100 * df.r_squared_std, color=color, alpha=0.35)
    ax_spread = Axis(fig[1, 2];
        xlabel="Visibilidade",
        ylabel="Variação das capacidades (σ/μ x 100)",
        xticks=xticks,
    )
    scatter!(ax_spread, df.visibility, 100 * df.cv_capacity_mean, color=color)
    errorbars!(ax_spread, df.visibility, 100 * df.cv_capacity_mean, 100 * df.cv_capacity_std, color=color, alpha=0.35)

    ax_capacity = Axis(fig[2, 1];
        title="Capacidade Média",
        xlabel="Visibilidade",
        ylabel="Capacidade Média",
        xticks=xticks,
    )
    scatter!(ax_capacity, df.visibility, df.mean_capacity_mean, color=color)
    errorbars!(ax_capacity, df.visibility, df.mean_capacity_mean, df.mean_capacity_std, color=color, alpha=0.35)

    ax_distance = Axis(fig[2, 2];
        title="Tempo Médio de Viagem",
        xlabel="Visibilidade",
        ylabel="Tempo Médio (Passos)",
        xticks=xticks,
    )
    scatter!(ax_distance, df.visibility, df.avg_distance_mean, color=color)
    errorbars!(ax_distance, df.visibility, df.avg_distance_mean, df.avg_distance_std, color=color, alpha=0.35)
    colgap!(fig.layout, 18)
    rowgap!(fig.layout, 22)

    save_figure("visibilidade_limitada_correlations", fig)
    fig
end

function __plot_histograms()
    distance_histogram = npzread("raw_results/$(hdf5_filename)_distance_histograms.npy")
    freqs = distance_histogram ./ sum(distance_histogram)
    fig = Figure(size=(600, 600))
    ax = Axis(fig[1, 1],
        xlabel="Distância",
        ylabel="Porcentagem (100%)",
        yscale=log10,
    )
    barplot!(ax, 100 * freqs, label="Frequência", color=color)
    lines!(ax, 100 * (1.0 .- cumsum(freqs[1:(end-1)])), linewidth=2,
        label="Função Sobrevivência", color=:green, linestyle=:dash)
    axislegend(ax, position=:rt)
    save_figure("visibilidade_limitada_grid", fig)
    fig
end



function plot()
    df = __preprocess_correlations()
    __plot_histograms()
    __plot_correlations(df)
end

end


