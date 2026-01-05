import Config

# Note: cache_static_manifest is not used since this is an API-only server
# If you add static assets later, run `mix phx.digest` and uncomment:
# config :mega_planner, MegaPlannerWeb.Endpoint,
#   cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info
