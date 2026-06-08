using Graphs
using StableRNGs
using CairoMakie
using GraphMakie
using NetworkLayout

function create_edge_map(g::AbstractGraph)
    edges_collected = collect(Graphs.edges(g))
    Dict((min(e.src, e.dst), max(e.src, e.dst)) => i for (i, e) in enumerate(edges_collected))
end

function color_path!(
    edge_ids::Dict{Tuple{Int,Int},Int},
    color::Symbol;
    node_colors::Vector{Symbol},
    edge_colors::Vector{Symbol},
    path::Vector,
)

    node_colors[path[2:end-1]] .= color

    for i in 1:length(path)-1
        edge_idx = edge_ids[(min(path[i], path[i+1]), max(path[i], path[i+1]))]
        edge_colors[edge_idx] = color
    end
end



N::Int64 = 30
g = grid([N, N])
edge_map = create_edge_map(g)
source::Int64 = 1
target::Int64 = N^2 / 2 - N / 2
dijkstra_result = dijkstra_shortest_paths(g, source)
path::Vector{Int64} = []
vertex = target
while vertex != source
    append!(path, vertex)
    vertex = dijkstra_result.parents[vertex]
end
append!(path, source)
reverse!(path)
node_colors = fill(:black, nv(g))
edge_colors = fill(:black, ne(g))
node_colors[source] = :green
node_colors[target] = :red
color_path!(edge_map, :blue;
    node_colors=node_colors,
    edge_colors=edge_colors,
    path=path)


walk = randomwalk(g, source, N^4; rng=StableRNG(1003))
color_path!(edge_map, :orange;
    node_colors=node_colors,
    edge_colors=edge_colors,
    path=walk[1:findfirst(x -> x == target, walk)])

graphplot(g; layout=Stress(), node_color=node_colors, edge_color=edge_colors)