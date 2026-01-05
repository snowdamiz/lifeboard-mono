defmodule MegaPlannerWeb.SearchController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Search

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, %{"q" => query}) do
    user = Guardian.Plug.current_resource(conn)
    results = Search.search(user.household_id, query)
    json(conn, %{data: results})
  end

  def index(conn, _params) do
    json(conn, %{data: %{tasks: [], inventory_items: [], budget_sources: [], pages: [], goals: [], habits: [], total: 0}})
  end
end
