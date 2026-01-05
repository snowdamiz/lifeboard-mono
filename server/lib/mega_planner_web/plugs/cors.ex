defmodule MegaPlannerWeb.Plugs.Cors do
  @moduledoc """
  CORS plug that reads the allowed origin from runtime configuration.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    frontend_url = Application.get_env(:mega_planner, :frontend_url, "http://localhost:5173")

    conn
    |> put_resp_header("access-control-allow-origin", frontend_url)
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "authorization, content-type")
    |> put_resp_header("access-control-allow-credentials", "true")
    |> put_resp_header("access-control-max-age", "86400")
    |> handle_preflight()
  end

  defp handle_preflight(%{method: "OPTIONS"} = conn) do
    conn
    |> send_resp(204, "")
    |> halt()
  end

  defp handle_preflight(conn), do: conn
end

