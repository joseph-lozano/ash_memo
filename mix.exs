defmodule AshMemo.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ash_memo,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs(),
      source_url: "https://github.com/joseph-lozano/ash_memo",
      homepage_url: "https://github.com/joseph-lozano/ash_memo"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.5"},
      {:spark, "~> 2.2"},
      {:ash_postgres, "~> 2.6"},

      # Dev/Test dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:usage_rules, "~> 0.1.23", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    An Ash framework extension that provides automatic caching for calculations
    with configurable TTL and eviction strategies using PostgreSQL storage.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/joseph-lozano/ash_memo"
      },
      maintainers: ["Joseph Lozano"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: "https://github.com/joseph-lozano/ash_memo"
    ]
  end
end
