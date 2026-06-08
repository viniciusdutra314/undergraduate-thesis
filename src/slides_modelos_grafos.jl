using CairoMakie
using GraphMakie
using Graphs
using StableRNGs
using NetworkLayout

function plot_graph(g::AbstractGraph, color, layout::NetworkLayout.AbstractLayout)::Figure
    f, ax, _ = graphplot(g;
        node_color=color,
        edge_color=color,
        layout=layout
    )
    hidedecorations!(ax)
    hidespines!(ax)
    ax.aspect = DataAspect()
    f

end

barabasi = barabasi_albert(100, 4; rng=StableRNG(2000))
erdos = erdos_renyi(100, 400; rng=StableRNG(1005))
rgg, _ = euclidean_graph(500, 2; cutoff=0.1, rng=StableRNG(1003))
watts = watts_strogatz(100, 4, 1e-1; rng=StableRNG(1002))

f1 = plot_graph(rgg, RGBAf(to_color(:green), 0.8), Align(Stress(), pi))
f2 = plot_graph(barabasi, RGBAf(to_color(:red), 0.5), Stress())
f3 = plot_graph(erdos, RGBAf(to_color(:blue), 0.5), Stress())
f4 = plot_graph(watts, RGBAf(to_color(:purple), 1),
    Shell()
)

save("thesis/assets_slides/rgg.svg", f1)
save("thesis/assets_slides/barabasi.svg", f2)
save("thesis/assets_slides/erdos.svg", f3)
save("thesis/assets_slides/watts.svg", f4)
