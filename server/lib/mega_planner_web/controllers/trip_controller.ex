defmodule MegaPlannerWeb.TripController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Receipts
  alias MegaPlanner.Receipts.Trip

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    
    opts = []
    |> maybe_add_datetime(:start_date, params["start_date"])
    |> maybe_add_datetime(:end_date, params["end_date"])

    trips = Receipts.list_trips(user.household_id, opts)
    json(conn, %{data: Enum.map(trips, &trip_to_json/1)})
  end

  def create(conn, %{"trip" => trip_params}) do
    user = Guardian.Plug.current_resource(conn)
    trip_params = trip_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %Trip{} = trip} <- Receipts.create_trip(trip_params) do
      conn
      |> put_status(:created)
      |> json(%{data: trip_to_json(trip)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Receipts.get_household_trip(user.household_id, id) do
      nil -> {:error, :not_found}
      trip -> json(conn, %{data: trip_to_json(trip)})
    end
  end

  def update(conn, %{"id" => id, "trip" => trip_params}) do
    user = Guardian.Plug.current_resource(conn)

    with trip when not is_nil(trip) <- Receipts.get_household_trip(user.household_id, id),
         {:ok, %Trip{} = trip} <- Receipts.update_trip(trip, trip_params) do
      json(conn, %{data: trip_to_json(trip)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with trip when not is_nil(trip) <- Receipts.get_household_trip(user.household_id, id),
         {:ok, %Trip{}} <- Receipts.delete_trip(trip) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp maybe_add_datetime(opts, key, value) when is_binary(value) do
    # Try DateTime first, then fall back to Date
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> 
        Keyword.put(opts, key, datetime)
      _ -> 
        # Try parsing as just a date
        case Date.from_iso8601(value) do
          {:ok, date} -> Keyword.put(opts, key, date)
          _ -> opts
        end
    end
  end
  defp maybe_add_datetime(opts, _key, _value), do: opts

  defp trip_to_json(trip) do
    %{
      id: trip.id,
      driver: (Ecto.assoc_loaded?(trip.driver) && trip.driver && trip.driver.name) || nil,
      driver_id: trip.driver_id,
      trip_start: trip.trip_start,
      trip_end: trip.trip_end,
      notes: trip.notes,
      stops: Enum.map(trip.stops || [], &stop_to_json/1),
      inserted_at: trip.inserted_at,
      updated_at: trip.updated_at
    }
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
      time_arrived: format_time(stop.time_arrived),
      time_left: format_time(stop.time_left),
      purchases: Enum.map(stop.purchases || [], &purchase_to_json/1),
      inserted_at: stop.inserted_at
    }
  end

  defp format_time(nil), do: nil
  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")
  defp format_time(other), do: other

  defp purchase_to_json(purchase) do
    %{
      id: purchase.id,
      stop_id: purchase.stop_id,
      budget_entry_id: purchase.budget_entry_id,
      brand: purchase.brand,
      item: purchase.item,
      unit_measurement: purchase.unit_measurement,
      count: purchase.count,
      count_unit: purchase.count_unit,
      price_per_count: purchase.price_per_count,
      units: purchase.units,
      price_per_unit: purchase.price_per_unit,
      taxable: purchase.taxable,
      tax_rate: purchase.tax_rate,
      total_price: purchase.total_price,
      store_code: purchase.store_code,
      item_name: purchase.item_name,
      usage_mode: purchase.usage_mode,
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
