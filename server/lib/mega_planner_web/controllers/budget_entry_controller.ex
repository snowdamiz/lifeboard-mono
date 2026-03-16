defmodule MegaPlannerWeb.BudgetEntryController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Budget
  alias MegaPlanner.Budget.Entry

  action_fallback MegaPlannerWeb.FallbackController

  alias Decimal

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    opts =
      []
      |> maybe_add_date(:start_date, params["start_date"])
      |> maybe_add_date(:end_date, params["end_date"])
      |> maybe_add_opt(:type, params["type"])
      |> maybe_add_list(:tag_ids, params["tag_ids"])

    entries = Budget.list_entries(user.household_id, opts)

    # helper to process entries
    json_data =
      entries
      |> aggregate_entries()
      |> Enum.map(&param_to_json/1)

    json(conn, %{data: json_data})
  end

  defp loaded_assoc(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded_assoc(nil), do: nil
  defp loaded_assoc(value), do: value

  defp loaded_list(%Ecto.Association.NotLoaded{}), do: []
  defp loaded_list(nil), do: []
  defp loaded_list(values) when is_list(values), do: values

  # Safely extract tags, handling NotLoaded.
  defp safe_tags(tags), do: loaded_list(tags)

  defp aggregate_entries(nil), do: []
  defp aggregate_entries([]), do: []

  defp aggregate_entries(entries) when is_list(entries) do
    {singles, stops} =
      Enum.reduce(entries, {[], %{}}, fn entry, {singles, stops} ->
        purchase = loaded_assoc(entry.purchase)
        stop = purchase && loaded_assoc(purchase.stop)

        cond do
          purchase && purchase.stop_id && stop ->
            # This is a trip purchase with a loaded stop, aggregate it
            stop_id = purchase.stop_id

            stops =
              Map.update(stops, stop_id, init_stop_group(entry, stop), fn group ->
                update_stop_group(group, entry)
              end)

            {singles, stops}

          true ->
            # Regular entry or independent purchase (or purchase without stop loaded)
            {[entry | singles], stops}
        end
      end)

    # Combine singles and aggregated stops
    aggregated_stops = Map.values(stops)
    singles ++ aggregated_stops
  end

  defp init_stop_group(entry, stop) do
    # Prefer the entry's linked source, fall back to deriving from stop
    source = get_entry_source(entry, stop)

    %{
      # Use stop ID as the entry ID
      id: stop.id,
      date: entry.date,
      amount: entry.amount,
      type: "expense",
      notes: stop.notes,
      source_id: source.id,
      source: source,
      tags: safe_tags(entry.tags),
      inserted_at: entry.inserted_at,
      updated_at: entry.updated_at,
      is_trip: true,
      stop: stop
    }
  end

  defp update_stop_group(group, entry) do
    %{
      group
      | amount: Decimal.add(group.amount, entry.amount),
        tags: (group.tags ++ safe_tags(entry.tags)) |> Enum.uniq_by(& &1.id)
    }
  end

  # Get source from entry if linked, otherwise derive from stop
  defp get_entry_source(entry, stop) do
    source = loaded_assoc(entry.source)

    if source do
      %{
        id: source.id,
        name: source.name
      }
    else
      get_stop_source(stop)
    end
  end

  defp get_stop_source(stop) do
    store = loaded_assoc(stop.store)

    name =
      if store, do: store.name, else: stop.store_name || "Unknown Store"

    %{
      id: if(stop.store_id, do: stop.store_id, else: "stop-store-#{stop.id}"),
      name: name
    }
  end

  # Dispatcher for JSON conversion (handles both Entry struct and Map from aggregation)
  defp param_to_json(%Entry{} = entry), do: entry_to_json(entry)
  defp param_to_json(map) when is_map(map), do: map_to_json(map)

  defp map_to_json(map) do
    %{
      id: map.id,
      date: map.date,
      amount: map.amount,
      type: map.type,
      notes: map.notes || "Trip to #{map.source.name}",
      source_id: map.source_id,
      source: map.source,
      tags: Enum.map(safe_tags(map.tags), &tag_to_json/1),
      inserted_at: map.inserted_at,
      updated_at: map.updated_at,
      is_trip: true,
      stop: if(Map.get(map, :stop), do: stop_to_json(map.stop), else: nil)
    }
  end

  defp stop_to_json(stop) do
    store = loaded_assoc(stop.store)

    %{
      id: stop.id,
      store_name: if(store, do: store.name, else: stop.store_name),
      notes: stop.notes,
      purchases: Enum.map(loaded_list(stop.purchases), &purchase_to_json/1)
    }
  end

  defp purchase_to_json(purchase) do
    %{
      id: purchase.id,
      brand: purchase.brand,
      item: purchase.item,
      count: purchase.count,
      count_unit: purchase.count_unit,
      price_per_count: purchase.price_per_count,
      units: purchase.units,
      unit_measurement: purchase.unit_measurement,
      price_per_unit: purchase.price_per_unit,
      total_price: purchase.total_price,
      item_name: purchase.item_name,
      usage_mode: purchase.usage_mode,
      store_code: purchase.store_code,
      taxable: purchase.taxable,
      tax_rate: purchase.tax_rate,
      tags: Enum.map(safe_tags(purchase.tags), &tag_to_json/1)
    }
  end

  def create(conn, %{"entry" => entry_params}) do
    user = Guardian.Plug.current_resource(conn)

    entry_params =
      entry_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %Entry{} = entry} <- Budget.create_entry(entry_params) do
      conn
      |> put_status(:created)
      |> json(%{data: entry_to_json(entry)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Budget.get_household_entry(user.household_id, id) do
      nil -> {:error, :not_found}
      entry -> json(conn, %{data: entry_to_json(entry)})
    end
  end

  def update(conn, %{"id" => id, "entry" => entry_params}) do
    user = Guardian.Plug.current_resource(conn)

    with entry when not is_nil(entry) <- Budget.get_household_entry(user.household_id, id),
         {:ok, %Entry{} = entry} <- Budget.update_entry(entry, entry_params) do
      json(conn, %{data: entry_to_json(entry)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with entry when not is_nil(entry) <- Budget.get_household_entry(user.household_id, id),
         {:ok, %Entry{}} <- Budget.delete_entry(entry) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp maybe_add_date(opts, key, value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> Keyword.put(opts, key, date)
      _ -> opts
    end
  end

  defp maybe_add_date(opts, _key, _value), do: opts

  defp maybe_add_opt(opts, key, value) when is_binary(value) and value != "" do
    Keyword.put(opts, key, value)
  end

  defp maybe_add_opt(opts, _key, _value), do: opts

  defp maybe_add_list(opts, key, value) when is_binary(value) and value != "" do
    list = String.split(value, ",")
    Keyword.put(opts, key, list)
  end

  defp maybe_add_list(opts, key, value) when is_list(value), do: Keyword.put(opts, key, value)
  defp maybe_add_list(opts, _key, _value), do: opts

  defp entry_to_json(entry) do
    source = loaded_assoc(entry.source)
    purchase = loaded_assoc(entry.purchase)
    stop = purchase && loaded_assoc(purchase.stop)
    store = stop && loaded_assoc(stop.store)

    source_name =
      cond do
        source ->
          source.name

        purchase ->
          if store do
            store.name
          else
            "Purchase: #{purchase.brand} - #{purchase.item}"
          end

        true ->
          nil
      end

    source_identifier =
      cond do
        source -> entry.source_id
        purchase -> "purchase-#{purchase.id}"
        true -> nil
      end

    source_obj =
      if source_name,
        do: %{id: source_identifier, name: source_name},
        else: nil

    %{
      id: entry.id,
      date: entry.date,
      amount: entry.amount,
      type: entry.type,
      notes: entry.notes,
      source_id: entry.source_id,
      source: source_obj,
      tags: Enum.map(safe_tags(entry.tags), &tag_to_json/1),
      inserted_at: entry.inserted_at,
      updated_at: entry.updated_at,
      is_trip: false
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
