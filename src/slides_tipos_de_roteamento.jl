using Graphs
using StableRNGs
using CairoMakie
using GraphMakie
using NetworkLayout
using DataFrames
using CSV

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
    node_colors[path] .= color
    for i in 1:length(path)-1
        edge_idx = edge_ids[(min(path[i], path[i+1]), max(path[i], path[i+1]))]
        edge_colors[edge_idx] = color
    end
end

function get_minimal_path(g::AbstractGraph, source, target)::Vector
    dijkstra_result = dijkstra_shortest_paths(g, source)
    path::Vector{Int64} = []
    vertex = target
    while vertex != source
        append!(path, vertex)
        vertex = dijkstra_result.parents[vertex]
    end
    append!(path, source)
    reverse!(path)
    path
end




N::Int64 = 20
g = grid([N, N])
edge_map = create_edge_map(g)
target::Int64 = N^2 / 2 - N / 2
node_colors = fill(:black, nv(g))
edge_colors = fill(:black, ne(g))

#random walk
rw_source::Int64 = 1
walk = randomwalk(g, rw_source, N^4; rng=StableRNG(1007))
walk_path = walk[1:findfirst(x -> x == target, walk)]
color_path!(edge_map, :orange;
    node_colors=node_colors,
    edge_colors=edge_colors,
    path=walk_path)

#minimal path
node_colors[N] = :blue
mp_source::Integer = N
minimal_path = get_minimal_path(g, mp_source, target)
color_path!(edge_map, :blue;
    node_colors=node_colors,
    edge_colors=edge_colors,
    path=minimal_path)
#limited visibility
k = N / 3

lv_source::Integer = N * N
lv_path = begin
    dist_matrix = floyd_warshall_shortest_paths(g).dists
    path = Int[lv_source]
    curr = lv_source
    rng = StableRNG(1006)
    while dist_matrix[curr, target] > k
        curr = rand(rng, neighbors(g, curr))
        push!(path, curr)
    end
    append!(path, get_minimal_path(g, curr, target)[2:end])
    path
end
color_path!(edge_map, :green;
    node_colors=node_colors,
    edge_colors=edge_colors,
    path=lv_path)

node_colors[target] = :red

node_sizes = [c == :black ? 5 : 15 for c in node_colors]

node_sizes[[rw_source,mp_source,lv_source, target]] .= 25
edge_widths = [c == :black ? 1.0 : 4.0 for c in edge_colors]

f, ax, p = graphplot(g; layout=Stress(), node_color=node_colors, edge_color=edge_colors, node_size=node_sizes, edge_width=edge_widths)

hidedecorations!(ax)
hidespines!(ax)
save("thesis/assets_slides/modelos_roteamento.svg", f)


paths_data =
    CSV.write("thesis/assets_slides/roteamentos_comprimentos.csv", sort(DataFrame(
            routing=["Caminhada aleatória", "Mínimos caminhos", "Visibilidade limitada"],
            path_length=[length(walk_path) - 1, length(minimal_path) - 1, length(lv_path) - 1]
        ), :path_length))

f