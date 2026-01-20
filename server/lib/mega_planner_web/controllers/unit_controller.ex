defmodule MegaPlannerWeb.UnitController do
  use MegaPlannerWeb, :controller
  alias MegaPlanner.Receipts
  alias MegaPlanner.Receipts.Unit

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    units = Receipts.list_units(user.household_id)
    json(conn, %{data: Enum.map(units, &unit_to_json/1)})
  end

  def create(conn, %{"unit" => unit_params}) do
    user = Guardian.Plug.current_resource(conn)
    unit_params = Map.put(unit_params, "household_id", user.household_id)
    
    with {:ok, %Unit{} = unit} <- Receipts.create_unit(unit_params) do
      conn
      |> put_status(:created)
      |> json(%{data: unit_to_json(unit)})
    end
  end

  defp unit_to_json(unit) do
    %{
      id: unit.id,
      name: unit.name,
      household_id: unit.household_id,
      inserted_at: unit.inserted_at,
      updated_at: unit.updated_at
    }
  end
end
