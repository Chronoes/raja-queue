defmodule RajaQueue.MixProject do
  use Mix.Project

  def project do
    [
      app: :raja_queue,
      version: "0.1.6",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {RajaQueue, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:exirc, "~> 1.1"},
      {:jason, "~> 1.1"},
      {:tesla, "~> 1.2.0"},
      {:hackney, "~> 1.15.0"}
    ]
  end
end
