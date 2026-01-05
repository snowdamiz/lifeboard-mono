defmodule MegaPlannerWeb.UserController do
  use MegaPlannerWeb, :controller

  def me(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    json(conn, %{
      data: %{
        id: user.id,
        email: user.email,
        name: user.name,
        avatar_url: user.avatar_url,
        household_id: user.household_id
      }
    })
  end
end
