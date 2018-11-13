defmodule Txt.MixProject do
  use Mix.Project

  def project do
    [
      app: :txt,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [applications: [:logger, :plug_cowboy], mod: {Txt.Application, []}]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      {:pbkdf2_elixir, "~> 0.12"},
      {:distillery, "~> 2.0"}
    ]
  end
end
