defmodule Vl53tof.MixProject do
  use Mix.Project

  def project do
    [
      app: :vl53tof,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Vl53tof"
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
      {:circuits_i2c, "~> 0.1"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp description do
    """
    Package for interfacing with Sparkfun VL53L1X Time-of-Flight sensor
    https://www.sparkfun.com/products/14722
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Greg Gradwell"],
      licenses: ["All rights reserved"],
      links: %{"Github" => "https://github.com/some-assembly-required/gristle/tree/master/packages/vl53tof"},
      organization: "alh"
    ]
  end
end
