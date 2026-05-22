module GraphTraffic
export Engine, Topology, Analysis, Schema, Style, SharedData

module Style
export topology_to_color, log_x_log_y_style, log_x_style
using CairoMakie
const topology_to_color::Dict{String,String} = Dict("Barabási–Albert" => "red", "Erdős–Rényi" => "blue", "Rede Geométrica" => "green", "Watts–Strogatz" => "purple")
const log_x_log_y_style = (
    xscale=log10,
    yscale=log10,
    xminorticks=IntervalsBetween(9),
    yminorticks=IntervalsBetween(9),
    xminorticksvisible=true,
    yminorticksvisible=true,
    xminorgridvisible=true,
    yminorgridvisible=true,
    xgridcolor=:gray70,
    ygridcolor=:gray70,
    xminorgridcolor=:gray85,
    yminorgridcolor=:gray85,
    xlabelsize=18,
    ylabelsize=18,
    xticklabelsize=14,
    yticklabelsize=14
)

const log_x_style = (
    xscale=log10,
    xminorticks=IntervalsBetween(9),
    xminorticksvisible=true,
    xminorgridvisible=true,
    xgridcolor=:gray70,
    xminorgridcolor=:gray85,
    xlabelsize=18,
    xticklabelsize=14
)
end


module Schema
using UUIDs
using StructTypes
export RoutingMethod, ObserverEdgeQueue,
    ObserverEdgeReceivedMessages, ObserverEdgeCapacity, ObserverTotalMessages,
    ModifierEdgeCapacity, SimulationConfiguration, SimulationConfigurationItem,
    ObserversUnion, ModifiersUnion

struct RoutingMethod
    limited_visibility::UInt
end
StructTypes.StructType(::Type{RoutingMethod}) = StructTypes.Struct()

struct ObserverEdgeQueue
    type::String
end
ObserverEdgeQueue() = ObserverEdgeQueue("ObserverEdgeQueue")
StructTypes.StructType(::Type{ObserverEdgeQueue}) = StructTypes.Struct()

struct ObserverEdgeReceivedMessages
    type::String
end
ObserverEdgeReceivedMessages() = ObserverEdgeReceivedMessages("ObserverEdgeReceivedMessages")
StructTypes.StructType(::Type{ObserverEdgeReceivedMessages}) = StructTypes.Struct()

struct ObserverEdgeCapacity
    type::String
    update_interval::UInt
end
ObserverEdgeCapacity(update_interval::Integer; type::String="ObserverEdgeCapacity") =
    ObserverEdgeCapacity(type, update_interval)
StructTypes.StructType(::Type{ObserverEdgeCapacity}) = StructTypes.Struct()

struct ObserverTotalMessages
    type::String
end
ObserverTotalMessages() = ObserverTotalMessages("ObserverTotalMessages")
StructTypes.StructType(::Type{ObserverTotalMessages}) = StructTypes.Struct()

struct ModifierEdgeCapacity
    type::String
    free_flow_rate::Float64
    free_flow_sampling_time::Int
    minimal_capacity::Int
    multiplier::Float64
end
ModifierEdgeCapacity(free_flow_rate::Float64, free_flow_sampling_time::Int,
    minimal_capacity::Int, multiplier::Float64; type::String="ModifierEdgeCapacity") =
    ModifierEdgeCapacity(type, free_flow_rate, free_flow_sampling_time, minimal_capacity, multiplier)
StructTypes.StructType(::Type{ModifierEdgeCapacity}) = StructTypes.Struct()


const ObserversUnion = Union{ObserverEdgeQueue,ObserverEdgeReceivedMessages,ObserverEdgeCapacity,ObserverTotalMessages}
const ModifiersUnion = ModifierEdgeCapacity

struct SimulationConfigurationItem
    uuid::UUID
    routing_method::Union{String,RoutingMethod}
    graph_file_name::String
    message_generation::Float64
    max_iterations::UInt
    warm_up_iterations::Union{UInt,Nothing}
    random_seed::Union{UInt,Nothing}
    graph_generation_info::Union{Dict{String,Any},Nothing}
    modifiers::Union{Vector{ModifiersUnion},Nothing}
    observers::Union{Vector{ObserversUnion},Nothing}
end

SimulationConfigurationItem(;
    uuid, routing_method, graph_file_name, message_generation, max_iterations,
    warm_up_iterations=nothing, random_seed=nothing,
    graph_generation_info=nothing, modifiers=nothing, observers=nothing
) = SimulationConfigurationItem(
    uuid, routing_method, graph_file_name, message_generation,
    max_iterations, warm_up_iterations, random_seed, graph_generation_info,
    modifiers, observers
)

StructTypes.StructType(::Type{SimulationConfigurationItem}) = StructTypes.Struct()


const SimulationConfiguration = Vector{SimulationConfigurationItem}

end


module Engine
using ..Schema: SimulationConfiguration
using JSON
using HDF5

export run_rust_cli, raw_results_folder, open_raw_results

const raw_results_folder = normpath(@__DIR__, "..", "raw_results")

function run_rust_cli(config::SimulationConfiguration, filename::String; num_threads::Union{Integer,Nothing}=nothing,
    force_overwrite::Bool=false)
    run(`cargo install --git https://github.com/viniciusdutra314/GraphTraffic-rs --rev ed127dcdd65aeeca5f25765a695a08a6dcfd21cf --locked`)
    mktempdir() do temp_path
        temp_json_filename::String = joinpath(temp_path, "config.json")
        open(temp_json_filename, "w") do io
            JSON.json(io, config; pretty=true, omit_null=true)
        end
        complete_filename = joinpath(raw_results_folder, filename * ".hdf5")
        cli_cmd = `graph_traffic $temp_json_filename`
        cli_cmd = `$cli_cmd --output-file-hdf5 $complete_filename`
        if !isnothing(num_threads)
            cli_cmd = `$cli_cmd --threads $num_threads`
        end
        if force_overwrite
            cli_cmd = `$cli_cmd --force`
        end
        run(cli_cmd)
    end
end

function open_raw_results(f::Function, filename::AbstractString, mode::AbstractString="r"; kwargs...)
    HDF5.h5open(f, joinpath(raw_results_folder, filename) * ".hdf5", mode; kwargs...)
end

end
module Topology
using Graphs
import IGraphs
using StatsBase
using UUIDs
using HDF5
using Statistics

export connect_and_compare_graphs, get_graph, random_geometric_graph, watts_strogatz_given_m,
    temp_save_edgelist, save_edgelist, avg_distance, edge_betweeness_normalized, LazyGraph, avg_clustering

struct LazyGraph{F,Args}
    f::F
    args::Args
end

(g::LazyGraph)() = g.f(g.args...)

avg_clustering(g::SimpleGraph) = Statistics.mean(local_clustering_coefficient(g, 1:nv(g)))


function get_graph(sim_group::HDF5.Group)::SimpleGraph
    edgelist = sim_group["edgelist"]
    n = maximum(elem -> max(elem.source, elem.target), edgelist[:])
    # +1 because julia has the wrong index convention
    g = SimpleGraph(n + 1)
    for row in edgelist[:]
        add_edge!(g, Int(row.source) + 1, Int(row.target) + 1)
    end
    g
end
function connect_and_compare_graphs(graphs_generators::LazyGraph...;
    rtolerance::AbstractFloat=1e-2, max_iterations::Integer=100)::Vector{SimpleGraph}
    for _ in 1:max_iterations
        graphs = [__connect_graph!(graph()) for graph in graphs_generators]
        if (__are_the_graphs_comparable(graphs..., rtolerance=rtolerance))
            return graphs
        end
    end
    return
end

function __are_the_graphs_comparable(graphs::Graphs.SimpleGraph...; rtolerance::AbstractFloat=1e-2)::Bool
    num_nodes = nv(graphs[1])
    num_edges = ne(graphs[1])
    for graph in graphs
        n = nv(graph)
        m = ne(graph)
        rel_err_nodes = abs(n - num_nodes) / max(abs(num_nodes), eps(Float64))
        rel_err_edges = abs(m - num_edges) / max(abs(num_edges), eps(Float64))
        if rel_err_nodes > rtolerance || rel_err_edges > rtolerance
            return false
        end
    end
    return true
end

function __connect_graph!(g::Graphs.SimpleGraph)
    components = connected_components(g)
    while (length(components) > 1)
        component_a_vec, component_b_vec = StatsBase.sample(components, 2, replace=false)
        component_a = Set(component_a_vec)
        component_b = Set(component_b_vec)
        bridge_set = Set(bridges(g))
        cycle_edge_set = setdiff(Set(edges(g)), bridge_set)
        cycles_component_a = [e for e in cycle_edge_set if src(e) in component_a && dst(e) in component_a]
        cycles_component_b = [e for e in cycle_edge_set if src(e) in component_b && dst(e) in component_b]
        if !isempty(cycles_component_a) && !isempty(cycles_component_b)
            edge_a = rand(cycles_component_a)
            edge_b = rand(cycles_component_b)
            u, v = src(edge_a), dst(edge_a)
            x, y = src(edge_b), dst(edge_b)
            rem_edge!(g, u, v)
            rem_edge!(g, x, y)
            add_edge!(g, u, x)
            add_edge!(g, v, y)
        else
            vertex_a = rand(component_a)
            vertex_b = rand(component_b)
            add_edge!(g, vertex_a, vertex_b)
            @warn "Added 1 edge (degree sequence altered)."
        end
        components = connected_components(g)
    end
    return g
end

function random_geometric_graph(n::Integer, m_expected::Integer;
    r::AbstractFloat=sqrt(2 * m_expected / (pi * n * (n - 1)))
)::SimpleGraph
    g, _ = Graphs.euclidean_graph(n, 2, cutoff=r)
    return g
end

function watts_strogatz_given_m(n::Integer, m::Integer, β::AbstractFloat)::SimpleGraph
    k = div(2m, n)
    if !iseven(k)
        k += 1
    end
    return Graphs.watts_strogatz(n, k, β)
end
function temp_save_edgelist(g::SimpleGraph)::String
    temp_file = normpath(mktempdir(), string(uuid4(), ".edgelist"))
    save_edgelist(temp_file, g)
    temp_file
end


function save_edgelist(path::String, g::SimpleGraph)
    open(path, "w") do io
        println(io, Graphs.nv(g))
        println(io, Graphs.ne(g))
        for edge in Graphs.edges(g)
            println(io, Graphs.src(edge) - 1, " ", Graphs.dst(edge) - 1)
        end
    end
end

function avg_distance(g::SimpleGraph)::Float64
    converted_graph::IGraphs.IGraph = IGraphs.IGraph(g)
    IGraphs.LibIGraph.average_path_length(
        converted_graph, IGraphs.IGNull(),
        false, false)[1]
end

function edge_betweeness_normalized(g::SimpleGraph)::Vector{Float64}
    result = Ref{IGraphs.LibIGraph.igraph_vector_t}()
    IGraphs.LibIGraph.igraph_vector_init(result, Graphs.ne(g))
    converted_graph::IGraphs.IGraph = IGraphs.IGraph(g)
    IGraphs.LibIGraph.igraph_edge_betweenness(converted_graph.objref, C_NULL, result,
        IGraphs.LibIGraph.igraph_ess_all(IGraphs.LibIGraph.IGRAPH_EDGEORDER_ID),
        false, true)
    result_vec = Vector{Float64}(undef, Graphs.ne(g))
    for i in 1:Graphs.ne(g)
        result_vec[i] = IGraphs.LibIGraph.igraph_vector_get(result, i - 1)
    end
    return result_vec
end

end

module SharedData
using Graphs
using ..Topology: LazyGraph,
    random_geometric_graph, watts_strogatz_given_m
using CairoMakie
export erdos_name, barabasi_name, rgg_name, watts_name,
    barabasi_graph, erdos_graph, rgg_graph, watts_graph, βs_watts, N_watts, E_watts, watts_cmap
N = 5000
M = 3
E = N * M
β = 0.1
βs_watts = [2.5e-3, 5e-3, 1e-2, 5e-2]
N_watts = 3_000
E_watts = 9_000
watts_cmap = cgrad(cgrad(:inferno)[range(0, 0.75, length=256)])

barabasi_graph = LazyGraph(barabasi_albert, (N, M))
erdos_graph = LazyGraph(erdos_renyi, (N, E))
rgg_graph = LazyGraph(random_geometric_graph, (N, E))
watts_graph = LazyGraph(watts_strogatz_given_m, (N, E, β))
erdos_name = "Erdős–Rényi"
barabasi_name = "Barabási–Albert"
rgg_name = "Rede Geométrica"
watts_name = "Watts–Strogatz"

end


module Analysis
using Statistics
using ..Schema: SimulationConfigurationItem

using HDF5
using JSON
using Makie
using CSV
using DataFrames

export range_logarithmic, get_avg_delay, get_avg_traveling_time, get_json,
    get_observer_edge_queue, get_edge_capacity, save_dataframe_to_csv,
    save_figure, calculate_edge_free_flow_rate, get_graph_hdf5_uuid

function range_logarithmic(; start::AbstractFloat, stop::AbstractFloat, length::Integer)
    start_log10 = log10(start)
    stop_log10 = log10(stop)
    log_values = range(start_log10, stop_log10, length=length)
    return 10 .^ log_values
end

function get_avg_delay(sim_group::HDF5.Group)::Float64
    Statistics.mean(
        row.total_traveling_time / row.total_distance - 1.0
        for row in sim_group["vertices_attributes"][:]
        if row.total_distance != 0
    )
end

function get_avg_traveling_time(sim_group::HDF5.Group)::Float64
    Statistics.mean(
        row.total_traveling_time / row.num_arrived_msgs
        for row in sim_group["vertices_attributes"][:]
        if row.num_arrived_msgs != 0
    )
end

function get_graph_hdf5_uuid(sim_group::HDF5.Group)::String
    splitext(basename(get_json(sim_group).graph_file_name))[1]
end

function get_json(sim_group::HDF5.Group)
    JSON.lazy(String(sim_group["json_string"][:]))[]
end

function get_observer_edge_queue(sim::HDF5.Group)::Vector{Dict{UInt,UInt}}
    observers = sim["ObserverEdgeQueue"]
    result::Vector{Dict{UInt,UInt}} = [Dict{UInt,UInt}() for _ in 1:length(observers)]
    for edge_id in HDF5.keys(observers)
        dataset = observers[edge_id]
        result[parse(UInt, edge_id)+1] = Dict(dataset["keys"] .=> dataset["values"])
    end
    result
end

function get_edge_capacity(sim::HDF5.Group)::Dict{Int,Vector{Int}}
    h5_capacities = sim["ObserverEdgeCapacity"]
    result::Dict{Int,Vector{Int}} = Dict{Int,Vector{Int}}()
    for time in HDF5.keys(h5_capacities)
        result[parse(Int, time)] = h5_capacities[time]["capacities"][:]
    end
    result
end



function calculate_edge_free_flow_rate(sim::HDF5.Group)::Dict{Int,Vector{Float64}}
    capacities::Dict{Int,Vector{Int}} = get_edge_capacity(sim)
    edge_queue::Vector{Dict{Int,Int}} = get_observer_edge_queue(sim)

    calculate_edge_ffr(queue::Dict{Int,Int}, capacity::Int, total::Int) = sum(occuruences for (q_size, occuruences) in queue if q_size <= capacity; init=0.0) / total
    result = Dict{Int,Vector{Float64}}()
    for time in keys(capacities)
        total = sum(values(edge_queue[1]))
        result[time] = calculate_edge_ffr.(edge_queue, capacities[time], total)
    end
    result
end


function save_dataframe_to_csv(df::DataFrame, filename::String)
    out_dir = normpath(@__DIR__, "..", "thesis", "assets", "tables")
    mkpath(out_dir)
    CSV.write(joinpath(out_dir, "$filename.csv"), df)
end

function save_figure(title::String, fig::Makie.Figure)
    out_dir = normpath(@__DIR__, "..", "thesis", "assets", "plots")
    mkpath(out_dir)
    save(joinpath(out_dir, "$title.svg"), fig)
end
end
end
