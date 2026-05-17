module WattsStrogatzClassicPlot
include("GraphTraffic.jl")
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


function plot()
    βs = range_logarithmic(start=1e-4, stop=1.0, length=1000)
    regular_lattice = watts_strogatz_given_m(N, E, 0.0)
    l_0 = avg_distance(regular_lattice)
    c_0 = avg_clustering(regular_lattice)
    graphs = connect_and_compare_graphs([LazyGraph(watts_strogatz_given_m, (N, E, β)) for β in βs]...)
    fig = Figure()
    ax = Axis(fig[1, 1],
        xlabel=L"$\beta$",
        ylabel="Porcentagem (100%)",
        xscale=log10,
    )

    l_values = zeros(length(βs))
    c_values = zeros(length(βs))
    Threads.@threads for i in eachindex(βs)
        l_values[i] = avg_distance(graphs[i])
        c_values[i] = avg_clustering(graphs[i])
    end

    scatter!(ax, βs, 100 * l_values ./ l_0, color="red", alpha=0.5, label=L"\frac{L}{L_0}")
    scatter!(ax, βs, 100 * c_values ./ c_0, color="blue", alpha=0.5, label=L"\frac{C}{C_0}")
    axislegend(ax, position=:rt)
    save_figure("watts_classical_plot", fig)
end


function generate_data()
end

main = make_cli(WattsStrogatzClassicPlot.generate_data, WattsStrogatzClassicPlot.plot)

end


if abspath(PROGRAM_FILE) == @__FILE__
    WattsStrogatzClassicPlot.main(ARGS)
end
