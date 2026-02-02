defmodule MegaPlannerWeb.InventorySheetController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Inventory
  alias MegaPlanner.Inventory.Sheet

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    tag_ids = parse_tag_ids(params)
    sheets = Inventory.list_sheets(user.household_id, tag_ids)
    json(conn, %{data: Enum.map(sheets, &sheet_to_json/1)})
  end

  defp parse_tag_ids(%{"tag_ids" => tag_ids}) when is_binary(tag_ids) do
    tag_ids |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.filter(&(&1 != ""))
  end
  defp parse_tag_ids(_), do: nil

  def create(conn, %{"sheet" => sheet_params}) do
    user = Guardian.Plug.current_resource(conn)
    sheet_params = sheet_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %Sheet{} = sheet} <- Inventory.create_sheet(sheet_params) do
      conn
      |> put_status(:created)
      |> json(%{data: sheet_to_json(sheet)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Inventory.get_household_sheet(user.household_id, id) do
      nil -> {:error, :not_found}
      sheet -> json(conn, %{data: sheet_with_items_to_json(sheet)})
    end
  end

  def update(conn, %{"id" => id, "sheet" => sheet_params}) do
    user = Guardian.Plug.current_resource(conn)

    with sheet when not is_nil(sheet) <- Inventory.get_household_sheet(user.household_id, id),
         {:ok, %Sheet{} = sheet} <- Inventory.update_sheet(sheet, sheet_params) do
      json(conn, %{data: sheet_to_json(sheet)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with sheet when not is_nil(sheet) <- Inventory.get_household_sheet(user.household_id, id),
         {:ok, %Sheet{}} <- Inventory.delete_sheet(sheet) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp sheet_to_json(sheet) do
    %{
      id: sheet.id,
      name: sheet.name,
      columns: sheet.columns,
      tags: Enum.map(sheet.tags || [], &tag_to_json/1),
      inserted_at: sheet.inserted_at,
      updated_at: sheet.updated_at
    }
  end

  defp sheet_with_items_to_json(sheet) do
    sheet_to_json(sheet)
    |> Map.put(:items, Enum.map(sheet.items || [], &item_to_json/1))
  end

  defp item_to_json(item) do
    %{
      id: item.id,
      name: item.name,
      quantity: decimal_to_string(item.quantity),
      min_quantity: decimal_to_string(item.min_quantity),
      is_necessity: item.is_necessity,
      store: item.store,
      unit_of_measure: item.unit_of_measure,
      brand: item.brand,
      tags: Enum.map(item.tags || [], &tag_to_json/1),
      custom_fields: item.custom_fields,
      # Purchase/Trip/Store data for full data parity
      count: item.count,
      price_per_count: item.price_per_count,
      price_per_unit: item.price_per_unit,
      taxable: item.taxable,
      total_price: item.total_price,
      store_code: item.store_code,
      item_name: item.item_name,
      purchase_date: item.purchase_date,
      trip_id: item.trip_id,
      stop_id: item.stop_id,
      purchase_id: item.purchase_id
    }
  end

  defp tag_to_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color
    }
  end

  defp decimal_to_string(%Decimal{} = d), do: Decimal.to_string(d)
  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(val), do: to_string(val)

  # Trip Receipts

  def trip_receipts(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    receipts = Inventory.list_trip_receipts(user.household_id)
    json(conn, %{data: Enum.map(receipts, &trip_receipt_to_json/1)})
  end

  defp trip_receipt_to_json(receipt) do
    %{
      id: receipt.id,
      trip_id: receipt.trip_id,
      store_name: receipt.store_name,
      trip_start: receipt.trip_start,
      date: receipt.date,
      items: Enum.map(receipt.items, &item_to_json/1)
    }
  end
end
