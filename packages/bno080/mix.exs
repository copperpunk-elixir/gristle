defmodule Bno080.MixProject do
  use Mix.Project

  def project do
    [
      app: :bno080,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "bno080"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:circuits_uart, "~> 0.1"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp description do
    """
    Package for interfacing with Sparkfun BNO080 IMU breakout board
    https://www.sparkfun.com/products/14686
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Greg Gradwell"],
      licenses: ["All rights reserved"],
      links: %{"Github" => "https://github.com/some-assembly-required/gristle/tree/master/packages/bno080"},
      organization: "alh"
    ]
  end
end
