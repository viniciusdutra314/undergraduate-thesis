using PythonCall
ox = pyimport("osmnx")
plt = pyimport("matplotlib.pyplot")
place_name = "São Carlos, São Paulo, Brazil"

graph = ox.graph_from_place(place_name, network_type="drive")
fig, ax = ox.plot.plot_graph(graph)
fig.savefig("thesis/assets_slides/sao_carlos.svg")