module WattsStrogatzClassicPlot
include("GraphTraffic.jl")
using .GraphTraffic.Engine
using .GraphTraffic.Schema
using .GraphTraffic.Topology
using .GraphTraffic.Analysis
using .GraphTraffic.Style
using NPZ
using Graphs
using UUIDs
using CairoMakie
using Statistics
using HDF5

const βs = range_logarithmic(start=1e-4, stop=1.0, length=500)
const npz_filename = "raw_results/watts_classical_plot.npz"
function plot()
    data = npzread(npz_filename)
    l_values = data["l_values"]
    c_values = data["c_values"]
    l_0 = data["l_0"]
    c_0 = data["c_0"]

    fig = Figure()
    ax = Axis(fig[1, 1];
        xlabel=L"$\beta$",
        ylabel="Porcentagem (100%)",
        log_x_style...,
        yminorticks=IntervalsBetween(9),
        yminorgridcolor=:gray85,
        yminorticksvisible=true,
        yminorgridvisible=true,
    )

    scatter!(ax, βs, 100 * l_values ./ l_0, color="orangered", alpha=0.8, label=L"\frac{L}{L_0}")
    scatter!(ax, βs, 100 * c_values ./ c_0, color="seagreen1", alpha=0.8, label=L"\frac{C}{C_0}")
    axislegend(ax, position=:rt)
    save_figure("watts_classical_plot", fig)
end


function generate_data()
    N = GraphTraffic.SharedData.N_watts
    E = GraphTraffic.SharedData.E_watts
    regular_lattice = watts_strogatz_given_m(N, E, 0.0)
    l_0 = avg_distance(regular_lattice)
    c_0 = avg_clustering(regular_lattice)
    graphs = connect_and_compare_graphs([LazyGraph(watts_strogatz_given_m, (N, E, β)) for β in βs]...)

    l_values = zeros(length(βs))
    c_values = zeros(length(βs))
    Threads.@threads for i in eachindex(βs)
        l_values[i] = avg_distance(graphs[i])
        c_values[i] = avg_clustering(graphs[i])
    end

    npzwrite(npz_filename, Dict(
        "l_values" => l_values,
        "c_values" => c_values,
        "l_0" => l_0,
        "c_0" => c_0,
    ))
end
end
