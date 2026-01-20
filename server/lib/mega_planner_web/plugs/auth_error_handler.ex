defmodule MegaPlannerWeb.Plugs.AuthErrorHandler do
  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, reason}, _opts) do
    File.write("debug_output.txt", "[#{DateTime.utc_now()}] AUTH ERROR: Type: #{inspect(type)}, Reason: #{inspect(reason)}\n", [:append])
    body = Jason.encode!(%{error: to_string(type)})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, body)
  end
end
