defmodule MegaPlannerWeb.Plugs.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :mega_planner,
    module: MegaPlanner.Guardian,
    error_handler: MegaPlannerWeb.Plugs.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.VerifySession
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
