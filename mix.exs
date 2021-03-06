defmodule Wizard.Mixfile do
  use Mix.Project

  def project_version do
    case File.read("./.project_version") do
      {:ok, data} ->
        String.trim(data)
      {:error, _} ->
        if Mix.env == :dev do
          IO.puts("Create a .project_version file to set this project's version number")
        end
        "0.0.0"
    end
  end

  def project do
    [app: :wizard,
     version: project_version(),
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     start_permanent: Mix.env == :prod,
     dialyzer: [plt_add_deps: :transitive],
     aliases: aliases(),
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {Wizard.Application, []},
     extra_applications: [:logger, :runtime_tools]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:phoenix, "~> 1.3"},
     {:phoenix_pubsub, "~> 1.0"},
     {:ecto, "2.2.0-rc.0", override: true},
     {:phoenix_ecto, "~> 3.2"},
     {:postgrex, ">= 0.0.0"},
     {:phoenix_html, "~> 2.6"},
     {:gettext, "~> 0.11"},
     {:cowboy, "~> 1.0"},
     {:secure_random, "~> 0.5"},
     {:httpoison, "~> 0.13"},
     {:jose, "~> 1.8"},
     {:timex, "~> 3.0"},
     {:download, "~> 0.0.4"},
     {:imagineer, "~> 0.3.0"},
     {:flow, "~> 0.12.0"},
     {:guardian, "~> 1.0-beta"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:distillery, github: "bitwalker/distillery", runtime: false},
     {:ex_machina, git: "https://github.com/myobie/ex_machina.git", only: :test},
     {:dialyxir, "~> 0.5", only: :dev, runtime: false},
     {:quick_alias, "~> 0.1.0", only: :dev, runtime: false}]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"],
     "test": ["ecto.create --quiet", "ecto.migrate", "test"],
     "lint": ["compile", "dialyzer"]]
  end
end
