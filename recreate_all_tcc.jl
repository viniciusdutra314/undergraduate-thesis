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

function usage()
    println("Usage:")
    println("  julia --project=@. recreate_all_tcc.jl <simulate_all|plot_all|simulate_and_plot_all>")
    println()
    println("Commands:")
    println("  simulate_all            Run the simulations for all experiments")
    println("  plot_all                Recreate the plots for all experiments")
    println("  simulate_and_plot_all   Run simulations and plots for all experiments")
end


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


function main(args::Vector{String}=ARGS)
    if isempty(args)
        usage()
        return nothing
    end

    command = lowercase(args[1])
    if command in ("help", "-h", "--help")
        usage()
        return nothing
    end

    simulate, do_plot = if command == "simulate_all"
        true, false
    elseif command == "plot_all"
        false, true
    elseif command == "simulate_and_plot_all"
        true, true
    else
        error("Unknown command: $command")
    end

    println("Experiments:")
    for mod in EXPERIMENTS
        println("  - $(string(nameof(mod)))")
    end

    run_experiments(EXPERIMENTS; simulate=simulate, do_plot=do_plot)
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
