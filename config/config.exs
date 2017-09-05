# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :wizard,
  ecto_repos: [Wizard.Repo]

# Default Sharepoint api client implementation
config :wizard,
  sharepoint_api_client: Wizard.Sharepoint.Api.Client

# Configures the endpoint
config :wizard, WizardWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "HNuJRF3LIeIS3onHPFeo40r6VYCLXgrgVh8LB0GkZ7v5Pi7aqorPW63nOjIsUVvk",
  render_errors: [view: WizardWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Wizard.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :guardian, Guardian,
  allowed_algos: ["HS512"], # optional
  verify_module: Guardian.JWT,  # optional
  issuer: "Wizard",
  ttl: { 30, :days },
  allowed_drift: 2000,
  verify_issuer: true, # optional
  secret_key: "GqlhHFPES0rBqEqNSHZayO8uQoNhnU0ymEAcMkU+oQiKZ6rP/M8l6FHYMvCaTpC3",
  serializer: Wizard.GuardianSerializer

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
