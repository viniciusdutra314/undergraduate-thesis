include("src/GraphTraffic.jl")
include("src/watts_classical_plot.jl")
include("src/watts_messages_vs_time.jl")
include("src/rho_vs_atraso.jl")
include("src/rho_vs_atraso_adapted_capacity.jl")

const EXPERIMENTS = (
    WattsStrogatzBetaVsLAndC,
    WattsStrogatzClassicPlot,
    RhoVsAtraso,
    RhoVsAtrasoAdaptedCapacity
)

function run_experiments(mods; simulate::Bool=false, do_plot::Bool=false)
    total = length(mods)
    println("Experiments to run: $total")
    for (i, mod) in enumerate(mods)
        name = string(nameof(mod))
        println("[$i/$total] $name")
        if simulate
            println("  - simulate")
            sim_started = time_ns()
            getfield(mod, :generate_data)()
            sim_elapsed_s = (time_ns() - sim_started) / 1e9
            println("    simulate done in $(round(sim_elapsed_s; digits=2)) s")
        end
        if do_plot
            println("  - plot")
            plot_started = time_ns()
            getfield(mod, :plot)()
            plot_elapsed_s = (time_ns() - plot_started) / 1e9
            println("    plot done in $(round(plot_elapsed_s; digits=2)) s")
        end
    end
    return nothing
end

