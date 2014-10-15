defmodule SideTask.Mixfile do
  use Mix.Project

  def project do
    [app: :sidetask,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: [:logger, :sidejob]]
  end

  defp deps do
    [
      {:sidejob, github: "basho/sidejob", tag: "2.0.0"},
    ]
  end
end
