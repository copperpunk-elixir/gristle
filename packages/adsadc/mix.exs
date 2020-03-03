defmodule Adsadc.MixProject do
  use Mix.Project

  def project do
    [
      app: :adsadc,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "adsadc"
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
    Package for interfacing with Sparkfun 12-bit ADC
    https://www.sparkfun.com/products/15334
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Greg Gradwell"],
      licenses: ["All rights reserved"],
      links: %{"Github" => "https://github.com/some-assembly-required/gristle/tree/master/packages/adsadc"},
      organization: "alh"
    ]
  end
end
