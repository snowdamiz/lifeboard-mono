defmodule MegaPlannerWeb.Plugs.AuthPipeline do
  @moduledoc """
  Authentication pipeline using Guardian.

  If test mode has already set a current_user, this pipeline skips the Guardian checks.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # If test mode already authenticated, skip Guardian entirely
    if conn.assigns[:current_user] do
      # Test mode already set user - set Guardian claims so downstream works
      conn
      |> Plug.Conn.put_private(:guardian_default_resource, conn.assigns.current_user)
      |> Plug.Conn.put_private(:guardian_default_claims, %{"sub" => "test_mode"})
    else
      # Normal auth flow - run Guardian pipeline
      conn
      |> Guardian.Plug.VerifyHeader.call(Guardian.Plug.VerifyHeader.init(scheme: "Bearer"))
      |> Guardian.Plug.VerifySession.call(Guardian.Plug.VerifySession.init([]))
      |> Guardian.Plug.EnsureAuthenticated.call(Guardian.Plug.EnsureAuthenticated.init(
           error_handler: MegaPlannerWeb.Plugs.AuthErrorHandler
         ))
      |> Guardian.Plug.LoadResource.call(Guardian.Plug.LoadResource.init(
           module: MegaPlanner.Guardian,
           error_handler: MegaPlannerWeb.Plugs.AuthErrorHandler
         ))
    end
  end
end
