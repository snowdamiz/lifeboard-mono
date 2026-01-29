defmodule MegaPlannerWeb.HabitInventoryController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Goals
  alias MegaPlanner.Goals.HabitInventory

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    inventories = Goals.list_habit_inventories(user.household_id)
    json(conn, %{data: Enum.map(inventories, &inventory_to_json/1)})
  end

  def create(conn, %{"habit_inventory" => inventory_params}) do
    user = Guardian.Plug.current_resource(conn)
    inventory_params = Map.put(inventory_params, "household_id", user.household_id)

    case Goals.create_habit_inventory(inventory_params) do
      {:ok, %HabitInventory{} = inventory} ->
        conn
        |> put_status(:created)
        |> json(%{data: inventory_to_json(inventory)})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset.errors})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Goals.get_household_habit_inventory(user.household_id, id) do
      nil ->
        {:error, :not_found}
      inventory ->
        json(conn, %{data: inventory_to_json(inventory)})
    end
  end

  def update(conn, %{"id" => id, "habit_inventory" => inventory_params}) do
    user = Guardian.Plug.current_resource(conn)

    with inventory when not is_nil(inventory) <- Goals.get_household_habit_inventory(user.household_id, id),
         {:ok, %HabitInventory{} = inventory} <- Goals.update_habit_inventory(inventory, inventory_params) do
      json(conn, %{data: inventory_to_json(inventory)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with inventory when not is_nil(inventory) <- Goals.get_household_habit_inventory(user.household_id, id),
         {:ok, %HabitInventory{}} <- Goals.delete_habit_inventory(inventory) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp inventory_to_json(inventory) do
    %{
      id: inventory.id,
      name: inventory.name,
      color: inventory.color,
      position: inventory.position,
      coverage_mode: inventory.coverage_mode,
      linked_inventory_ids: inventory.linked_inventory_ids || [],
      day_start_time: inventory.day_start_time && Time.to_string(inventory.day_start_time),
      day_end_time: inventory.day_end_time && Time.to_string(inventory.day_end_time),
      inserted_at: inventory.inserted_at,
      updated_at: inventory.updated_at
    }
  end
end
