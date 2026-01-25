defmodule MegaPlannerWeb.InventoryItemController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Inventory
  alias MegaPlanner.Inventory.Item

  action_fallback MegaPlannerWeb.FallbackController

  def create(conn, %{"item" => item_params}) do
    user = Guardian.Plug.current_resource(conn)

    # Verify the sheet belongs to the household
    with sheet when not is_nil(sheet) <- Inventory.get_household_sheet(user.household_id, item_params["sheet_id"]),
         {:ok, %Item{} = item} <- Inventory.create_item(item_params) do
      conn
      |> put_status(:created)
      |> json(%{data: item_to_json(item)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def show(conn, %{"id" => id}) do
    case Inventory.get_item(id) do
      nil -> {:error, :not_found}
      item -> json(conn, %{data: item_to_json(item)})
    end
  end

  def update(conn, %{"id" => id, "item" => item_params}) do
    with item when not is_nil(item) <- Inventory.get_item(id),
         {:ok, %Item{} = item} <- Inventory.update_item(item, item_params) do
      json(conn, %{data: item_to_json(item)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    with item when not is_nil(item) <- Inventory.get_item(id),
         {:ok, %Item{}} <- Inventory.delete_item(item) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp item_to_json(item) do
    %{
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      min_quantity: item.min_quantity,
      is_necessity: item.is_necessity,
      store: item.store,
      unit_of_measure: item.unit_of_measure,
      brand: item.brand,
      tags: Enum.map(item.tags || [], &tag_to_json/1),
      custom_fields: item.custom_fields,
      sheet_id: item.sheet_id,
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
  end

  defp tag_to_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color
    }
  end

  # Find matching items across sheets

  def find_matching(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    brand = Map.get(params, "brand", "")
    name = Map.get(params, "name", "")
    
    items = Inventory.find_matching_items(user.household_id, brand, name)
    json(conn, %{data: Enum.map(items, &item_with_sheet_to_json/1)})
  end

  defp item_with_sheet_to_json(item) do
    item_to_json(item)
    |> Map.put(:sheet, %{
      id: item.sheet.id,
      name: item.sheet.name
    })
  end

  # Transfer item between sheets

  def transfer(conn, %{"source_id" => source_id, "target_sheet_id" => target_sheet_id, "quantity" => quantity}) do
    quantity = if is_binary(quantity), do: String.to_integer(quantity), else: quantity
    
    case Inventory.transfer_item(source_id, target_sheet_id, quantity) do
      {:ok, :ok} -> json(conn, %{success: true})
      {:error, :insufficient_quantity} -> 
        conn |> put_status(400) |> json(%{error: "Insufficient quantity"})
      {:error, :item_not_found} ->
        conn |> put_status(404) |> json(%{error: "Item not found"})
      {:error, reason} -> 
        conn |> put_status(400) |> json(%{error: inspect(reason)})
    end
  end
end
