defmodule MegaPlannerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :mega_planner

  @session_options [
    store: :cookie,
    key: "_mega_planner_key",
    signing_salt: "mega_planner_signing",
    same_site: "Lax"
  ]

  plug Plug.Static,
    at: "/",
    from: :mega_planner,
    gzip: false,
    only: MegaPlannerWeb.static_paths()

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MegaPlannerWeb.Plugs.Cors
  plug MegaPlannerWeb.Router
end
