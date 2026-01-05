import Config

config :mega_planner, MegaPlanner.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mega_planner_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :mega_planner, MegaPlannerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_that_is_at_least_64_bytes_long_for_development_only",
  watchers: []

config :mega_planner, dev_routes: true

# Use Swoosh Local adapter in development
config :mega_planner, MegaPlanner.Mailer, adapter: Swoosh.Adapters.Local

# Enable Swoosh mailbox preview in development
config :swoosh, :serve_mailbox, true
config :swoosh, :preview_port, 4001

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
