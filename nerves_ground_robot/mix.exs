defmodule NervesGroundRobot.MixProject do
  use Mix.Project

  @app :nerves_ground_robot
  @version "0.1.0"
  @all_targets [:rpi0, :rpi3, :rpi3a, :rpi4]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.9",
      archives: [nerves_bootstrap: "~> 1.7"],
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
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.5.0", runtime: false},
      {:shoehorn, "~> 0.6"},
      {:ring_logger, "~> 0.6"},
      {:toolshed, "~> 0.2"},

      # Dependencies for all targets except :host
      {:nerves_runtime, "~> 0.6", targets: @all_targets},

      # Dependencies for specific targets
      {:nerves_system_rpi0, "~> 1.10", runtime: false, targets: :rpi0},
      {:nerves_system_rpi3, "~> 1.10", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a, "~> 1.10", runtime: false, targets: :rpi3a},
      {:nerves_system_rpi4, "~> 1.10", runtime: false, targets: :rpi4},

      # App dependencies
      {:circuits_i2c, "~> 0.1"},
      {:circuits_spi, "~> 0.1"},
      {:circuits_gpio, "~> 0.1"},
      {:circuits_uart, "~> 1.3"},
      {:vintage_net_wifi, "~> 0.7.0"}
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
