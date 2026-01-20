defmodule MegaPlannerWeb.StopController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Receipts
  alias MegaPlanner.Receipts.Stop

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, %{"trip_id" => trip_id}) do
    stops = Receipts.list_stops(trip_id)
    json(conn, %{data: Enum.map(stops, &stop_to_json/1)})
  end

  def create(conn, %{"trip_id" => trip_id, "stop" => stop_params}) do
    stop_params = Map.put(stop_params, "trip_id", trip_id)

    with {:ok, %Stop{} = stop} <- Receipts.create_stop(stop_params) do
      conn
      |> put_status(:created)
      |> json(%{data: stop_to_json(stop)})
    end
  end

  def update(conn, %{"id" => id, "stop" => stop_params}) do
    with stop when not is_nil(stop) <- Receipts.get_stop(id),
         {:ok, %Stop{} = stop} <- Receipts.update_stop(stop, stop_params) do
      json(conn, %{data: stop_to_json(stop)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    with stop when not is_nil(stop) <- Receipts.get_stop(id),
         {:ok, %Stop{}} <- Receipts.delete_stop(stop) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp stop_to_json(stop) do
    %{
      id: stop.id,
      trip_id: stop.trip_id,
      store_id: stop.store_id,
      store_name: stop.store_name || (stop.store && stop.store.name),
      store_address: stop.store_address || (stop.store && stop.store.address),
      notes: stop.notes,
      position: stop.position,
      purchases: Enum.map(stop.purchases || [], &purchase_to_json/1),
      inserted_at: stop.inserted_at
    }
  end

  defp purchase_to_json(purchase) do
    %{
      id: purchase.id,
      stop_id: purchase.stop_id,
      budget_entry_id: purchase.budget_entry_id,
      brand: purchase.brand,
      item: purchase.item,
      unit_measurement: purchase.unit_measurement,
      count: purchase.count,
      price_per_count: purchase.price_per_count,
      units: purchase.units,
      price_per_unit: purchase.price_per_unit,
      taxable: purchase.taxable,
      total_price: purchase.total_price,
      store_code: purchase.store_code,
      item_name: purchase.item_name,
      tags: Enum.map(purchase.tags || [], &tag_to_json/1),
      inserted_at: purchase.inserted_at,
      updated_at: purchase.updated_at
    }
  end

  defp tag_to_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color
    }
  end
end
