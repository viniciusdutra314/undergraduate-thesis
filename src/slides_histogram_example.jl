module HistogramExample
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


const sampling_time = 100
const num_samplings = 25
const iterations = num_samplings * sampling_time
const free_flow_rate::Float64 = 0.99
const minimal_capacity::Int = 1
const multiplier::Float64 = 1
const hdf5_filename::String = "histogram_example"

function generate_data()
    barabasi = barabasi_graph()
    graph_filename = temp_'_edgelist(barabasi)
    rho = 1e-1
    run_rust_cli([
            SimulationConfigurationItem(uuid=UUIDs.uuid4(),
                routing_method="minimal_paths",
                graph_file_name=graph_filename,
                message_generation=rho,
                max_iterations=iterations,
                warm_up_iterations=Int(24 * sampling_time - 1),
                modifiers=[ModifierEdgeCapacity(free_flow_rate, sampling_time,
                    minimal_capacity, multiplier)],
                observers=GraphTraffic.Schema.ObserversUnion[ObserverEdgeCapacity(sampling_time), ObserverEdgeQueue()]
            )], hdf5_filename, force_overwrite=true)
end

function plot()
    open_raw_results(hdf5_filename, "r") do hfile
        sim_results = hfile["simulations_results"]
        for sim in sim_results
            histogram_data = sim["ObserverEdgeQueue"]["2"]
            keys = Vector{Int64}()
            values = Vector{Int64}()
            for (key, value) in zip(histogram_data["keys"][:], histogram_data["values"][:])
                push!(keys, key)
                push!(values, value)
            end
            sorted_indices = sortperm(keys)
            keys = keys[sorted_indices]
            values = values[sorted_indices]
            fig = Figure()
            ax = Axis(fig[1, 1],
                xlabel="Quantidade de mensagens",
                ylabel="Frequência")
            total = sum(values)
            cumulative = cumsum(values) ./ total
            η = 0.9
            η_idx = findfirst(x -> x >= η, cumulative) - 1
            vlines!(ax, η_idx;
                color=:red, alpha=0.5, linestyle=:dash)
            hlines!(ax, η; color=:red, alpha=0.5, linestyle=:dash)
            barplot!(ax, keys, values ./ total)
            stairs!(ax, keys, cumulative, color=:gray)
            text!(ax, 0, η * 1.05; text=L"$\eta$", fontsize=24, color=:red)
            text!(ax, η_idx * 1.1, η * 0.90; text=L"$min\{C \in \mathbb{Z}^+ : F_e(C) \geq \eta\}$", fontsize=16, color=:black)

            save_figure("histogram_example", fig)
            return fig
        end

    end

end
end

