defmodule MegaPlannerWeb.AuthController do
  use MegaPlannerWeb, :controller
  plug Ueberauth

  alias MegaPlanner.Accounts
  alias MegaPlanner.Guardian

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
    require Logger
    Logger.error("OAuth failure: #{inspect(fails)}")

    errors = Enum.map(fails.errors, fn error ->
      "#{error.message_key}: #{error.message}"
    end)

    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Authentication failed", details: errors})
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.find_or_create_user_from_oauth(auth.provider, auth) do
      {:ok, user} ->
        {:ok, tokens} = Guardian.create_tokens(user)

        # Redirect to frontend with both tokens
        frontend_url = Application.get_env(:mega_planner, :frontend_url, "http://localhost:5173")
        redirect_url = "#{frontend_url}/auth/callback?access_token=#{tokens.access_token}&refresh_token=#{tokens.refresh_token}"

        conn
        |> redirect(external: redirect_url)

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Failed to authenticate: #{inspect(reason)}"})
    end
  end

  @doc """
  Refresh the access token using a valid refresh token.
  POST /auth/refresh
  Body: { "refresh_token": "..." }
  """
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Guardian.exchange_refresh_token(refresh_token) do
      {:ok, new_access_token, _user} ->
        conn
        |> json(%{data: %{access_token: new_access_token}})

      {:error, :refresh_token_expired} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Refresh token expired. Please log in again."})

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid refresh token"})
    end
  end

  def refresh(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing refresh_token"})
  end

  def logout(conn, _params) do
    conn
    |> Guardian.Plug.sign_out()
    |> configure_session(drop: true)
    |> json(%{message: "Logged out successfully"})
  end
end
