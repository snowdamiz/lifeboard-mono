import Config

config :mega_planner,
  ecto_repos: [MegaPlanner.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  frontend_url: "http://localhost:5173"

config :mega_planner, MegaPlannerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [json: MegaPlannerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MegaPlanner.PubSub,
  live_view: [signing_salt: "mega_planner_salt"]

config :mega_planner, MegaPlanner.Guardian,
  issuer: "mega_planner",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || "dev_secret_key_change_in_production",
  # Access tokens expire in 15 minutes
  ttl: {15, :minutes},
  # Refresh tokens expire in 30 days
  token_ttl: %{
    "access" => {15, :minutes},
    "refresh" => {30, :days}
  }

config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :esbuild, :version, "0.25.0"

# Swoosh Mailer - adapters configured per environment
config :mega_planner, MegaPlanner.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client for production adapters
config :swoosh, :api_client, Swoosh.ApiClient.Finch

import_config "#{config_env()}.exs"
