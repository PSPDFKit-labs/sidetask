defmodule SideTask.Mixfile do
  use Mix.Project

  def project do
    [app: :sidetask,
     version: "1.1.2",
     elixir: ">= 1.2.0",
     source_url: "https://github.com/PSPDFKit-labs/sidetask",
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    [applications: [:logger, :sidejob]]
  end

  defp description do
    """
    SideTask is an alternative to Elixir's Task.Supervisor that uses Basho's sidejob library for
    better parallelism and to support capacity limiting of Tasks. All calls that start a new task
    require a sidejob resource as argument and can return `{:error, :overload}`.
    """
  end

  defp package do
    [maintainers: ["PSPDFKit"],
     licenses: ["MIT"],
     links: %{
       "GitHub" => "https://github.com/MSch/sidetask",
       "PSPDFKit" => "https://pspdfkit.com",
     },
     files: ["lib", "mix.exs", "README.md", "LICENSE"]]
  end

  defp deps do
    [
      {:earmark, "> 0.0.0", only: :dev},
      {:ex_doc, "> 0.0.0", only: :dev},
      {:sidejob, "~> 2.0"},
    ]
  end
end
