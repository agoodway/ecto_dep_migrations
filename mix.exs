defmodule EctoDepMigrations.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_dep_migrations,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      description: "A package to manage Ecto migrations from dependencies in Phoenix apps.",
      package: package(),
      deps: deps(),
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ]
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
      {:ecto_sql, "~> 3.10"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/yourorg/ecto_dep_migrations"},
      maintainers: ["Your Name"],
      files: ~w(lib priv mix.exs README.md LICENSE CHANGELOG.md usage-rules.md)
    ]
  end
end
