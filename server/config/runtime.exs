import Config

# =============================================================================
# Step 1: Load .env file (dev/test only)
# In production, Fly.io secrets are already in the environment
# =============================================================================
if config_env() in [:dev, :test] do
  env_file = Path.join([__DIR__, "..", ".env"])

  if File.exists?(env_file) do
    # Manually parse .env file and set environment variables
    # (More reliable than Dotenvy on Windows)
    env_file
    |> File.read!()
    |> String.split("\n")
    |> Enum.each(fn line ->
      line = String.trim(line)

      # Skip empty lines and comments
      unless line == "" or String.starts_with?(line, "#") do
        case String.split(line, "=", parts: 2) do
          [key, value] ->
            key = String.trim(key)
            value = value |> String.trim() |> String.trim("\"") |> String.trim("'")
            System.put_env(key, value)

          _ ->
            :ok
        end
      end
    end)

    IO.puts("[INFO] Loaded environment from: #{env_file}")
  else
    IO.puts("\n[WARNING] .env file not found at: #{env_file}")
    IO.puts("Copy env.example to .env and configure your credentials.\n")
  end
end

# =============================================================================
# Step 2: Configure OAuth (all environments)
# Works with both .env (dev) and Fly secrets (prod)
# =============================================================================
if google_client_id = System.get_env("GOOGLE_CLIENT_ID") do
  config :ueberauth, Ueberauth.Strategy.Google.OAuth,
    client_id: google_client_id,
    client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
else
  if config_env() in [:dev, :test] do
    IO.puts("[WARNING] GOOGLE_CLIENT_ID not set - Google OAuth disabled")
  end
end

if github_client_id = System.get_env("GITHUB_CLIENT_ID") do
  config :ueberauth, Ueberauth.Strategy.Github.OAuth,
    client_id: github_client_id,
    client_secret: System.get_env("GITHUB_CLIENT_SECRET")
end

# =============================================================================
# Step 3: Production-specific configuration
# =============================================================================
if config_env() == :prod do
  # Frontend URL for OAuth redirects
  if frontend_url = System.get_env("FRONTEND_URL") do
    config :mega_planner, frontend_url: frontend_url
  end

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :mega_planner, MegaPlanner.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :mega_planner, MegaPlannerWeb.Endpoint,
    server: true,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :mega_planner, MegaPlanner.Guardian,
    secret_key: System.get_env("GUARDIAN_SECRET_KEY") || secret_key_base
end
