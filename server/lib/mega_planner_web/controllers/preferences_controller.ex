defmodule MegaPlannerWeb.PreferencesController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Accounts

  action_fallback MegaPlannerWeb.FallbackController

  def show(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    prefs = Accounts.get_or_create_preferences(user.id)
    json(conn, %{data: prefs_to_json(prefs)})
  end

  def update(conn, %{"preferences" => prefs_params}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, prefs} <- Accounts.set_preferences(user.id, prefs_params) do
      json(conn, %{data: prefs_to_json(prefs)})
    end
  end

  defp prefs_to_json(prefs) do
    %{
      id: prefs.id,
      nav_order: prefs.nav_order,
      dashboard_widgets: prefs.dashboard_widgets,
      theme: prefs.theme,
      settings: prefs.settings,
      updated_at: prefs.updated_at
    }
  end
end

