defmodule SideTask.Mixfile do
  use Mix.Project

  def project do
    [app: :sidetask,
     version: "0.1.0",
     elixir: "~> 1.0",
     source_url: "https://github.com/MSch/sidetask",
     licenses: ["Apache 2.0"],
     deps: deps]
  end

  def application do
    [applications: [:logger, :sidejob]]
  end

  defp deps do
    [
      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.6", only: :dev},
      {:sidejob, "~> 2.0"},
    ]
  end
end
