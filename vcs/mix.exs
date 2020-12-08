defmodule Vcs.MixProject do
  use Mix.Project

  @app :vcs
  @version "0.1.0"
  @all_targets [:rpi0, :rpi, :rpi3, :rpi3a, :rpi4]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.10",
      archives: [nerves_bootstrap: "~> 1.9"],
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      aliases: [loadconfig: [&bootstrap/1]],
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host]
    ]
  end

  # Starting nerves_bootstrap adds the required aliases to Mix.Project.config()
  # Aliases are only added if MIX_TARGET is set.
  def bootstrap(args) do
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Common.Application, []},
      extra_applications: [:logger, :runtime_tools, :soap]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.7.0", runtime: false},
      {:shoehorn, "~> 0.7"},
      {:ring_logger, "~> 0.8.1"},
      {:toolshed, "~> 0.2.13"},

      # Dependencies for all targets except :host
      {:nerves_runtime, "~> 0.11.3", targets: @all_targets},
      {:nerves_pack, "~> 0.4", targets: @all_targets},
      {:nerves_ssh, "~> 0.2.1", targets: @all_targets},
      {:nerves_leds, "~> 0.8", targets: @all_targets},
      {:mdns_lite, "~> 0.4"},

      # Dependencies for specific targets
      {:nerves_system_rpi0, "~> 1.13", runtime: false, targets: :rpi0},
      {:nerves_system_rpi, "~> 1.13", runtime: false, targets: :rpi},
      {:nerves_system_rpi3, "~> 1.13", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a, "~> 1.13", runtime: false, targets: :rpi3a},
      {:nerves_system_rpi4, "~> 1.13", runtime: false, targets: :rpi4},
      # Package dependencies
      # {:vintage_net, "~> 0.9.2"},
      # {:vintage_net_wifi, "~> 0.9.1"},
      # {:vintage_net_ethernet, "~> 0.9.0"},
      {:elixir_uuid, "~> 1.2"},
      {:circuits_uart, "~> 1.4.2"},
      {:circuits_i2c, "~> 0.3.6"},
      {:circuits_gpio, "~> 0.4.6"},
      #Scenic dependencies
      {:scenic, "~> 0.10.3"},
      {:scenic_driver_glfw, "~> 0.10.1", targets: :host},
      {:scenic_sensor, "~> 0.7"},
      #Jason
      {:jason, "~> 1.2.2"},
      # MessagePack
      {:msgpax, "~> 2.2.4"},
      #Protobufs
      {:protobuf, "~> 0.7.1"},
      {:google_protos, "~> 0.1"},
      # RealFlight support
      {:soap, "~> 1.0.1"},
      {:httpoison, "~> 1.7.0"},
      {:sax_map, "~> 1.0"}
    ]
  end

  def release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod
    ]
  end
end
