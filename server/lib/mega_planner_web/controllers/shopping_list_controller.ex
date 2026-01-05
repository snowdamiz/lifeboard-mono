defmodule MegaPlannerWeb.ShoppingListController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Inventory
  alias MegaPlanner.Inventory.ShoppingList

  action_fallback MegaPlannerWeb.FallbackController

  # Shopping Lists

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    lists = Inventory.list_shopping_lists(user.household_id)
    json(conn, %{data: Enum.map(lists, &list_to_json/1)})
  end

  def create(conn, %{"list" => list_params}) do
    user = Guardian.Plug.current_resource(conn)
    list_params = list_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %ShoppingList{} = list} <- Inventory.create_shopping_list(list_params) do
      conn
      |> put_status(:created)
      |> json(%{data: list_to_json(list)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Inventory.get_household_shopping_list(user.household_id, id) do
      nil -> {:error, :not_found}
      list -> json(conn, %{data: list_to_json(list)})
    end
  end

  def update_list(conn, %{"id" => id, "list" => list_params}) do
    user = Guardian.Plug.current_resource(conn)

    with list when not is_nil(list) <- Inventory.get_household_shopping_list(user.household_id, id),
         {:ok, %ShoppingList{} = updated_list} <- Inventory.update_shopping_list(list, list_params) do
      json(conn, %{data: list_to_json(updated_list)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete_list(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with list when not is_nil(list) <- Inventory.get_household_shopping_list(user.household_id, id),
         {:ok, _} <- Inventory.delete_shopping_list(list) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def generate(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    list = Inventory.generate_shopping_list(user.id, user.household_id)
    json(conn, %{data: list_to_json(list)})
  end

  # Shopping List Items

  def create_item(conn, %{"list_id" => list_id, "item" => item_params}) do
    user = Guardian.Plug.current_resource(conn)

    with list when not is_nil(list) <- Inventory.get_household_shopping_list(user.household_id, list_id) do
      item_params = item_params
        |> Map.put("shopping_list_id", list.id)
        |> Map.put("user_id", user.id)
        |> Map.put("household_id", user.household_id)

      case Inventory.create_shopping_item(item_params) do
        {:ok, item} ->
          conn
          |> put_status(:created)
          |> json(%{data: item_to_json(item)})
        error ->
          error
      end
    else
      nil -> {:error, :not_found}
    end
  end

  def update_item(conn, %{"list_id" => list_id, "id" => id, "item" => item_params}) do
    user = Guardian.Plug.current_resource(conn)

    with list when not is_nil(list) <- Inventory.get_household_shopping_list(user.household_id, list_id),
         item when not is_nil(item) <- Inventory.get_shopping_item(id),
         true <- item.shopping_list_id == list.id do

      # If marking as purchased, use the special function
      if item_params["purchased"] == true do
        case Inventory.mark_purchased(item) do
          {:ok, updated_item} ->
            json(conn, %{data: item_to_json(updated_item)})
          {:error, reason} ->
            {:error, reason}
        end
      else
        case Inventory.update_shopping_item(item, item_params) do
          {:ok, updated_item} ->
            json(conn, %{data: item_to_json(updated_item)})
          error ->
            error
        end
      end
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_found}
    end
  end

  def delete_item(conn, %{"list_id" => list_id, "id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with list when not is_nil(list) <- Inventory.get_household_shopping_list(user.household_id, list_id),
         item when not is_nil(item) <- Inventory.get_shopping_item(id),
         true <- item.shopping_list_id == list.id,
         {:ok, _} <- Inventory.delete_shopping_item(item) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_found}
      error -> error
    end
  end

  # Legacy endpoint - list all items across lists
  def all_items(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    items = Inventory.list_all_shopping_items(user.household_id)
    json(conn, %{data: Enum.map(items, &item_to_json/1)})
  end

  defp list_to_json(list) do
    %{
      id: list.id,
      name: list.name,
      is_auto_generated: list.is_auto_generated,
      notes: list.notes,
      items: Enum.map(list.items || [], &item_to_json/1),
      item_count: length(list.items || []),
      unpurchased_count: Enum.count(list.items || [], &(!&1.purchased)),
      inserted_at: list.inserted_at,
      updated_at: list.updated_at
    }
  end

  defp item_to_json(item) do
    base = %{
      id: item.id,
      name: item.name,
      quantity_needed: item.quantity_needed,
      purchased: item.purchased,
      shopping_list_id: item.shopping_list_id,
      inserted_at: item.inserted_at
    }

    if item.inventory_item do
      Map.put(base, :inventory_item, %{
        id: item.inventory_item.id,
        name: item.inventory_item.name,
        store: item.inventory_item.store,
        sheet_name: item.inventory_item.sheet.name
      })
    else
      base
    end
  end
end
