defmodule RentDivisionTelegram.MixProject do
  use Mix.Project

  def project do
    [
      app: :rent_division_telegram,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RentDivisionTelegram.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_gram, "~> 0.10"},
      {:tesla, "~> 1.2"},
      {:hackney, "~> 1.12"},
      {:jason, ">= 1.0.0"},
      {:httpoison, "~> 2.1"},
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end
end
