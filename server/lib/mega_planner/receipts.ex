defmodule MegaPlanner.Receipts do
  @moduledoc """
  The Receipts context handles shopping trips, stores, purchases, and brands.
  """

  import Ecto.Query, warn: false
  require Logger
  alias MegaPlanner.Repo
  alias MegaPlanner.Receipts.{Store, Trip, Stop, Brand, Purchase, Unit, FormatCorrection, TaxIndicatorMeaning}
  alias MegaPlanner.Budget
  alias MegaPlanner.Tags.Tag
  alias Ecto.Multi

  # Stores

  @doc """
  Returns the list of stores for a household.
  """
  def list_stores(household_id) do
    from(s in Store, where: s.household_id == ^household_id, order_by: [asc: s.name])
    |> Repo.all()
  end

  @doc """
  Gets a single store.
  """
  def get_store(id) do
    Repo.get(Store, id)
  end

  @doc """
  Gets a store for a specific household.
  """
  def get_household_store(household_id, id) do
    Repo.get_by(Store, id: id, household_id: household_id)
  end

  @doc """
  Creates a store.
  """
  def create_store(attrs \\ %{}) do
    %Store{}
    |> Store.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a store by ID. Raises if not found.
  """
  def get_store!(id) do
    Repo.get!(Store, id)
  end

  @doc """
  Finds a store by name for a household.
  Returns nil if not found.
  """
  def find_store_by_name(_household_id, nil), do: nil
  def find_store_by_name(household_id, name) do
    from(s in Store,
      where: s.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", s.name, ^name),
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Finds a store by store_id for a household.
  Returns nil if not found.
  """
  def find_store_by_store_id(_household_id, nil), do: nil
  def find_store_by_store_id(_household_id, ""), do: nil
  def find_store_by_store_id(household_id, store_id) do
    from(s in Store,
      where: s.household_id == ^household_id,
      where: s.store_id == ^store_id,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Updates a store.
  """
  def update_store(%Store{} = store, attrs) do
    store
    |> Store.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a store.
  """
  def delete_store(%Store{} = store) do
    Repo.delete(store)
  end

  @doc """
  Returns a combined list of inventory items for a store (manual items + receipts).
  """
  def list_store_inventory(%Store{} = store) do
    # 1. Fetch manual inventory items for this store
    manual_items =
      from(i in MegaPlanner.Inventory.Item,
        where: i.store == ^store.name,
        select: %{
          id: i.id,
          source: "manual",
          brand: i.brand,
          name: i.name,
          unit: i.unit_of_measure,
          price: i.price_per_unit, # Or price_per_count depending on preference
          date: i.updated_at
        }
      )
      |> Repo.all()

    # 2. Fetch recent unique purchases for this store
    receipt_items =
      from(p in Purchase,
        join: s in assoc(p, :stop),
        where: s.store_id == ^store.id,
        # We want distinct items, ideally the most recent one
        # Postgres DISTINCT ON is perfect here
        distinct: [p.brand, p.item],
        order_by: [asc: p.brand, asc: p.item, desc: p.inserted_at],
        select: %{
          id: p.id,
          source: "receipt",
          brand: p.brand,
          name: p.item,
          unit: p.unit_measurement,
          price: p.price_per_unit,
          date: p.inserted_at
        }
      )
      |> Repo.all()

    # Combine and sort
    (manual_items ++ receipt_items)
    |> Enum.sort_by(& &1.date, {:desc, Date})
  end

  def update_store_inventory_item(store_id, item_id, source, attrs, propagate \\ false) do
    store = Repo.get!(Store, store_id)

    result = case source do
      "manual" ->
        item = Repo.get!(MegaPlanner.Inventory.Item, item_id)
        update_inventory_item_with_propagation(item, store, attrs, propagate)

      "receipt" ->
        purchase = Repo.get!(Purchase, item_id)
        update_purchase_item_with_propagation(purchase, store, attrs, propagate)

      _ ->
        {:error, :invalid_source}
    end

    # Global usage_mode sync (runs after the Multi transaction)
    if Map.has_key?(attrs, "usage_mode") || Map.has_key?(attrs, :usage_mode) do
      new_mode = attrs["usage_mode"] || attrs[:usage_mode]

      case source do
        "manual" ->
          item = Repo.get!(MegaPlanner.Inventory.Item, item_id)
          item = Repo.preload(item, :sheet)
          if item.brand && item.name do
            sync_usage_mode_globally(item.sheet.household_id, item.brand, item.name, item_id, new_mode, :inventory)
          end

        "receipt" ->
          purchase = Repo.get!(Purchase, item_id)
          if purchase.brand && purchase.item do
            sync_usage_mode_globally(purchase.household_id, purchase.brand, purchase.item, item_id, new_mode, :purchase)
          end

        _ -> :ok
      end
    end

    result
  end

  defp update_inventory_item_with_propagation(item, store, attrs, propagate) do
    Multi.new()
    |> Multi.update(:item, MegaPlanner.Inventory.Item.changeset(item, attrs))
    |> run_propagation_if_needed(item, store, attrs, propagate, :manual)
    |> Repo.transaction()
  end

  defp update_purchase_item_with_propagation(purchase, store, attrs, propagate) do
    Multi.new()
    |> Multi.update(:purchase, Purchase.changeset(purchase, attrs))
    |> run_propagation_if_needed(purchase, store, attrs, propagate, :receipt)
    |> Repo.transaction()
  end

  defp run_propagation_if_needed(multi, original_item, store, attrs, true, _type) do
    # For each changed attribute, update other items that share the OLD value and the same BRAND
    # Note: We assume 'brand' is the grouping key. If brand itself changes, we update items with the OLD brand.
    
    allowed_keys = [:brand, :unit_of_measure, :unit_measurement, :unit, :price, :price_per_unit]

    Enum.reduce(allowed_keys, multi, fn key_atom, m ->
      # Check both string and atom keys in attrs
      new_value = Map.get(attrs, Atom.to_string(key_atom)) || Map.get(attrs, key_atom)
      
      # We only proceed if the key was actually present in the attrs (meaning it was part of the update payload)
      # and the value is not nil (or we accept setting to nil? for now assume payload contains change)
      # Actually, distinguishing "key present with nil" vs "key missing" is important.
      # Map.get returns nil for missing.
      # But StoreController passes a map where keys exist.
      # Only if key_str is in Map.keys(attrs) should we proceed.
      
      key_str = Atom.to_string(key_atom)
      key_exists = Map.has_key?(attrs, key_str) or Map.has_key?(attrs, key_atom)
      
      if key_exists do
        old_value = Map.get(original_item, key_atom)
        
        # Cast new value based on expected type for the key
        new_value = cast_propagation_value(key_atom, new_value)
        
        # If value changed and old_value was not nil (meaning the field existed in original_item)
        if old_value != nil and old_value != new_value do
           inv_field = inventory_field_map(key_atom)
           purch_field = purchase_field_map(key_atom)
           
           m = if inv_field do
             Multi.update_all(m,
               "propagate_manual_#{key_atom}_#{System.unique_integer()}",
               from(i in MegaPlanner.Inventory.Item,
                 where: i.store == ^store.name and i.brand == ^original_item.brand and field(i, ^inv_field) == ^old_value
               ),
               set: [{inv_field, new_value}]
             )
           else
             m
           end
           
           if purch_field do
             Multi.update_all(m,
               "propagate_receipt_#{key_atom}_#{System.unique_integer()}",
               from(p in Purchase,
                 join: s in assoc(p, :stop),
                 where: s.store_id == ^store.id and p.brand == ^original_item.brand and field(p, ^purch_field) == ^old_value
               ),
               set: [{purch_field, new_value}]
             )
           else
             m
           end
        else
          m
        end
      else
        m
      end
    end)
  end
  defp run_propagation_if_needed(multi, _item, _store, _attrs, false, _type), do: multi

  defp purchase_field_map(:unit_of_measure), do: :unit_measurement
  defp purchase_field_map(:name), do: :item
  defp purchase_field_map(:item), do: :item
  defp purchase_field_map(:brand), do: :brand
  defp purchase_field_map(:unit_measurement), do: :unit_measurement
  defp purchase_field_map(:price_per_unit), do: :price_per_unit
  defp purchase_field_map(_), do: nil # Don't map unknown fields

  defp inventory_field_map(:unit_measurement), do: :unit_of_measure
  defp inventory_field_map(:unit_of_measure), do: :unit_of_measure
  defp inventory_field_map(:name), do: :name
  defp inventory_field_map(:item), do: :name
  defp inventory_field_map(:brand), do: :brand
  defp inventory_field_map(:price_per_unit), do: :price_per_unit
  defp inventory_field_map(:price), do: :price_per_unit
  defp inventory_field_map(_), do: nil

  defp cast_propagation_value(key, value) when key in [:price, :price_per_unit] do
    case value do
      nil -> nil
      "" -> nil
      v when is_binary(v) -> 
        case Decimal.parse(v) do
          {d, _} -> d
          :error -> nil
        end
      v -> v
    end
  end
  defp cast_propagation_value(_key, value), do: value


  # Drivers

  alias MegaPlanner.Receipts.Driver

  @doc """
  Returns the list of drivers for a household.
  """
  def list_drivers(household_id) do
    from(d in Driver, where: d.household_id == ^household_id, order_by: [asc: d.name])
    |> Repo.all()
  end

  @doc """
  Gets a single driver.
  """
  def get_driver(id) do
    Repo.get(Driver, id)
  end

  @doc """
  Creates a driver.
  """
  def create_driver(attrs \\ %{}) do
    %Driver{}
    |> Driver.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a driver.
  """
  def update_driver(%Driver{} = driver, attrs) do
    driver
    |> Driver.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a driver.
  """
  def delete_driver(%Driver{} = driver) do
    Repo.delete(driver)
  end

  # Trips

  @doc """
  Returns the list of trips for a household.
  """
  def list_trips(household_id, opts \\ []) do
    Logger.debug("[LIST_TRIPS] household=#{household_id} opts=#{inspect(opts)}")
    query = from t in Trip,
      where: t.household_id == ^household_id,
      order_by: [desc: t.trip_start],
      preload: [:driver, stops: [:store, purchases: [:tags]]]

    results = query
    |> filter_trips_by_date_range(opts)
    |> Repo.all()
    
    Logger.debug("[LIST_TRIPS] Found #{length(results)} trips: #{inspect(Enum.map(results, fn t -> %{id: t.id, trip_start: t.trip_start, stops: length(t.stops || [])} end))}")
    results
  end

  defp filter_trips_by_date_range(query, opts) do
    case {Keyword.get(opts, :start_date), Keyword.get(opts, :end_date)} do
      {nil, nil} -> query
      {start_date, nil} -> 
        start_dt = to_datetime(start_date, :start)
        from t in query, where: t.trip_start >= ^start_dt
      {nil, end_date} -> 
        end_dt = to_datetime(end_date, :end)
        from t in query, where: t.trip_start <= ^end_dt
      {start_date, end_date} -> 
        start_dt = to_datetime(start_date, :start)
        end_dt = to_datetime(end_date, :end)
        from t in query, where: t.trip_start >= ^start_dt and t.trip_start <= ^end_dt
    end
  end

  defp to_datetime(%Date{} = date, :start), do: DateTime.new!(date, ~T[00:00:00])
  defp to_datetime(%Date{} = date, :end), do: DateTime.new!(date, ~T[23:59:59.999999])
  defp to_datetime(dt, _) when is_struct(dt, DateTime), do: dt
  defp to_datetime(val, _), do: val

  @doc """
  Gets a single trip with stops and purchases.
  """
  def get_trip(id) do
    Trip
    |> Repo.get(id)
    |> Repo.preload(stops: [:store, purchases: [:tags]])
  end

  @doc """
  Gets a trip by ID. Raises if not found.
  """
  def get_trip!(id) do
    Trip
    |> Repo.get!(id)
    |> Repo.preload(stops: [:store, purchases: [:tags]])
  end

  @doc """
  Gets a trip for a specific household.
  """
  def get_household_trip(household_id, id) do
    Trip
    |> Repo.get_by(id: id, household_id: household_id)
    |> Repo.preload([:driver, stops: [:store, purchases: [:tags]]])
  end

  @doc """
  Creates a trip.
  """
  def create_trip(attrs \\ %{}) do
    Logger.debug("[CREATE_TRIP] attrs=#{inspect(attrs)}")
    %Trip{}
    |> Trip.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, trip} -> 
        trip = Repo.preload(trip, [:driver, stops: [:store, purchases: [:tags]]])
        Logger.debug("[CREATE_TRIP] SUCCESS id=#{trip.id} trip_start=#{inspect(trip.trip_start)}")
        {:ok, trip}
      error -> 
        Logger.debug("[CREATE_TRIP] ERROR #{inspect(error)}")
        error
    end
  end

  @doc """
  Finds an existing trip for the given date and household, or creates a new one.
  Used for same-day consolidation: multiple receipts from the same day are grouped
  into a single trip with multiple stops.
  """
  def find_or_create_trip_for_date(household_id, date, attrs) do
    # Look for an existing trip on this date
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    existing = Repo.one(
      from t in Trip,
      where: t.household_id == ^household_id,
      where: t.trip_start >= ^start_of_day and t.trip_start <= ^end_of_day,
      order_by: [asc: t.trip_start],
      limit: 1,
      preload: [:driver, stops: [:store, purchases: [:tags]]]
    )

    if existing do
      Logger.debug("[FIND_OR_CREATE_TRIP] Found existing trip #{existing.id} for #{date}")
      {:ok, existing}
    else
      Logger.debug("[FIND_OR_CREATE_TRIP] No existing trip for #{date}, creating new one")
      create_trip(attrs)
    end
  end

  @doc """
  Updates a trip.
  """
  def update_trip(%Trip{} = trip, attrs) do
    trip
    |> Trip.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, trip} -> {:ok, Repo.preload(trip, [:driver, stops: [:store, purchases: [:tags]]], force: true)}
      error -> error
    end
  end

  @doc """
  Deletes a trip and all associated stops, purchases, and budget entries.
  """
  def delete_trip(%Trip{} = trip) do
    trip = Repo.preload(trip, stops: [purchases: :budget_entry])
    
    Repo.transaction(fn ->
      # Unlink Calendar Tasks linked to this trip
      from(t in MegaPlanner.Calendar.Task, where: t.trip_id == ^trip.id)
      |> Repo.update_all(set: [trip_id: nil])
      
      # Unlink Inventory Items linked to this trip
      from(i in MegaPlanner.Inventory.Item, where: i.trip_id == ^trip.id)
      |> Repo.update_all(set: [trip_id: nil, stop_id: nil, purchase_id: nil])

      # Delete all purchases first (their budget entries are cascade-deleted
      # by the DB via ON DELETE CASCADE on budget_entries.purchase_id)
      Enum.each(trip.stops, fn stop ->
        Enum.each(stop.purchases || [], fn purchase ->
          case Repo.delete(purchase) do
            {:ok, _} -> :ok
            {:error, changeset} -> 
              Repo.rollback(changeset)
          end
        end)
      end)
      
      # Delete the trip (which cascades to stops)
      case Repo.delete(trip) do
        {:ok, deleted_trip} -> deleted_trip
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Updates the date of a trip and its associated budget entries.
  """
  def update_trip_date(trip_id, date, start_time) do
    # Ensure start_time is present for DateTime creation
    start_time = start_time || ~T[12:00:00]
    dt_result = DateTime.new(date, start_time)
    
    # Only proceed if we have a valid date/time
    case dt_result do
      {:ok, trip_start} ->
        trip = 
          Trip
          |> Repo.get(trip_id)
          |> Repo.preload(stops: [purchases: :budget_entry])

        if trip do
          Multi.new()
          |> Multi.update(:trip, Trip.changeset(trip, %{trip_start: trip_start}))
          |> fn multi ->
            Enum.reduce(trip.stops, multi, fn stop, m_stop ->
              Enum.reduce(stop.purchases || [], m_stop, fn purchase, m_purch ->
                if purchase.budget_entry do
                  Multi.update(m_purch, "update_entry_#{purchase.budget_entry.id}", 
                    Budget.Entry.changeset(purchase.budget_entry, %{date: date}))
                else
                  m_purch
                end
              end)
            end)
          end.()
          |> Repo.transaction()
        else
          {:error, :not_found}
        end
      _ -> {:error, :invalid_date_or_time}
    end
  end

  # Stops

  @doc """
  Lists stops for a trip.
  """
  def list_stops(trip_id) do
    from(s in Stop,
      where: s.trip_id == ^trip_id,
      order_by: [asc: s.position],
      preload: [:store, purchases: [:tags]]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single stop.
  """
  def get_stop(id) do
    Stop
    |> Repo.get(id)
    |> Repo.preload([:store, purchases: [:tags]])
  end

  @doc """
  Creates a stop.
  """
  def create_stop(attrs \\ %{}) do
    %Stop{}
    |> Stop.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, stop} -> {:ok, Repo.preload(stop, [:store, purchases: [:tags]])}
      error -> error
    end
  end

  @doc """
  Creates a stop for a specific trip.
  """
  def create_stop(trip_id, attrs) when is_binary(trip_id) do
    attrs
    |> Map.put("trip_id", trip_id)
    |> create_stop()
  end

  @doc """
  Updates a stop.
  """
  def update_stop(%Stop{} = stop, attrs) do
    stop
    |> Stop.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, stop} -> {:ok, Repo.preload(stop, [:store, purchases: [:tags]], force: true)}
      error -> error
    end
  end

  @doc """
  Deletes a stop and all associated purchases and budget entries.
  """
  def delete_stop(%Stop{} = stop) do
    stop = Repo.preload(stop, purchases: :budget_entry)
    
    Repo.transaction(fn ->
      # Unlink Inventory Items linked to this stop
      from(i in MegaPlanner.Inventory.Item, where: i.stop_id == ^stop.id)
      |> Repo.update_all(set: [stop_id: nil, purchase_id: nil])

      # Delete all purchases (their budget entries are cascade-deleted
      # by the DB via ON DELETE CASCADE on budget_entries.purchase_id)
      Enum.each(stop.purchases || [], fn purchase ->
        case Repo.delete(purchase) do
          {:ok, _} -> :ok
          {:error, changeset} -> 
            Repo.rollback(changeset)
        end
      end)
      
      # Delete the stop
      case Repo.delete(stop) do
        {:ok, deleted_stop} -> deleted_stop
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  # Brands

  @doc """
  Returns the list of brands for a household.
  """
  def list_brands(household_id, opts \\ []) do
    query = from b in Brand,
      where: b.household_id == ^household_id,
      order_by: [asc: b.name]

    query
    |> filter_brands_by_search(opts)
    |> Repo.all()
  end

  defp filter_brands_by_search(query, opts) do
    case Keyword.get(opts, :search) do
      nil -> query
      "" -> query
      search -> from b in query, where: ilike(b.name, ^"%#{search}%")
    end
  end

  @doc """
  Gets a single brand.
  """
  def get_brand(id) do
    Repo.get(Brand, id)
  end

  @doc """
  Searches brands by name (for autocomplete).
  """
  def search_brands(household_id, query) do
    from(b in Brand,
      where: b.household_id == ^household_id and ilike(b.name, ^"%#{query}%"),
      order_by: [asc: b.name],
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Creates a brand.
  """
  def create_brand(attrs \\ %{}) do
    %Brand{}
    |> Brand.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a brand.
  """
  def update_brand(%Brand{} = brand, attrs) do
    brand
    |> Brand.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets a brand by name for a household.
  Returns nil if not found.
  """
  def get_brand_by_name(_household_id, nil), do: nil
  def get_brand_by_name(household_id, name) do
    from(b in Brand,
      where: b.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", b.name, ^name),
      limit: 1
    )
    |> Repo.one()
  end

  # Units

  @doc """
  Returns the list of units for a household.
  """
  def list_units(household_id) do
    from(u in Unit, where: u.household_id == ^household_id, order_by: [asc: u.name])
    |> Repo.all()
  end

  @doc """
  Creates a unit.
  """
  def create_unit(attrs \\ %{}) do
    %Unit{}
    |> Unit.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a unit by name or creates it if it doesn't exist.
  """
  def get_or_create_unit(household_id, name) do
    case Repo.get_by(Unit, household_id: household_id, name: name) do
      nil -> create_unit(%{household_id: household_id, name: name})
      unit -> {:ok, unit}
    end
  end

  @doc """
  Gets a unit by name for a household.
  Returns nil if not found.
  """
  def get_unit_by_name(_household_id, nil), do: nil
  def get_unit_by_name(household_id, name) do
    from(u in Unit,
      where: u.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", u.name, ^name),
      limit: 1
    )
    |> Repo.one()
  end

  # Purchases

  @doc """
  Returns the list of purchases for a household.
  """
  def list_purchases(household_id, opts \\ []) do
    query = from p in Purchase,
      where: p.household_id == ^household_id,
      order_by: [desc: p.inserted_at],
      preload: [:budget_entry, :stop, :tags]

    query
    |> filter_purchases_by_stop(opts)
    |> filter_purchases_by_brand(opts)
    |> filter_purchases_by_source(opts)
    |> Repo.all()
  end

  defp filter_purchases_by_stop(query, opts) do
    case Keyword.get(opts, :stop_id) do
      nil -> query
      stop_id -> from p in query, where: p.stop_id == ^stop_id
    end
  end

  defp filter_purchases_by_brand(query, opts) do
    case Keyword.get(opts, :brand) do
      nil -> query
      brand -> from p in query, where: ilike(p.brand, ^"%#{brand}%")
    end
  end

  defp filter_purchases_by_source(query, opts) do
    case Keyword.get(opts, :source_id) do
      nil -> query
      source_id -> 
        from p in query,
          join: e in assoc(p, :budget_entry),
          where: e.source_id == ^source_id
    end
  end

  @doc """
  Gets a single purchase.
  """
  def get_purchase(id) do
    Purchase
    |> Repo.get(id)
    |> Repo.preload([:budget_entry, :stop, :tags])
  end

  @doc """
  Creates a purchase along with its associated budget entry.
  """
  def create_purchase(attrs \\ %{}) do
    Logger.debug("[CREATE_PURCHASE] attrs=#{inspect(Map.drop(attrs, ["user_id", "household_id"]))}")
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids", [])
    {stop_id, attrs} = Map.pop(attrs, "stop_id")
    household_id = attrs["household_id"]
    user_id = attrs["user_id"]

    # Create the budget entry first
    # Date should always be provided by the client in their local timezone
    # If missing, we use UTC today as a fallback (this shouldn't normally happen)
    date = attrs["date"] || (
      Logger.warning("Purchase created without date, falling back to UTC today. This may cause timezone issues.")
      Date.utc_today()
    )
    Logger.debug("[CREATE_PURCHASE] stop_id=#{inspect(stop_id)} date=#{inspect(date)} brand=#{inspect(attrs["brand"])} item=#{inspect(attrs["item"])}")
    
    # Get store name from stop (if stop exists) and create/get expense source
    store_name = get_store_name_for_stop(stop_id)
    source_id = 
      case store_name do
        nil -> nil
        name ->
          case Budget.get_or_create_source_for_store(household_id, user_id, name) do
            {:ok, source} when not is_nil(source) -> source.id
            _ -> nil
          end
      end

    budget_attrs = %{
      "household_id" => household_id,
      "user_id" => user_id,
      "date" => date,
      "amount" => attrs["total_price"],
      "type" => "expense",
      "notes" => "Purchase: #{attrs["brand"]} - #{attrs["item"]}",
      "source_id" => source_id
    }
    Logger.debug("[CREATE_PURCHASE] budget_attrs=#{inspect(budget_attrs)}")

    Repo.transaction(fn ->
      with {:ok, entry} <- Budget.create_entry(budget_attrs),
           _ <- Logger.debug("[CREATE_PURCHASE] Budget entry created: id=#{entry.id} date=#{inspect(entry.date)}"),
           purchase_attrs <- Map.put(attrs, "budget_entry_id", entry.id),
           purchase_attrs <- (if stop_id, do: Map.put(purchase_attrs, "stop_id", stop_id), else: purchase_attrs),
           _ <- Logger.debug("[CREATE_PURCHASE] Inserting purchase with stop_id=#{inspect(stop_id)} budget_entry_id=#{entry.id}"),
           changeset <- Purchase.changeset(%Purchase{}, purchase_attrs),
           {:ok, purchase} <- Repo.insert(changeset),
           _ <- Logger.debug("[CREATE_PURCHASE] Purchase inserted: id=#{purchase.id} stop_id=#{inspect(purchase.stop_id)} budget_entry_id=#{inspect(purchase.budget_entry_id)}"),
           purchase <- update_purchase_tags(purchase, tag_ids),
           {:ok, _entry} <- Budget.update_entry(entry, %{"purchase_id" => purchase.id}) do
        
        # Try to create inventory item, but don't fail the whole transaction if it errors
        try do
          case MegaPlanner.Inventory.create_item_from_purchase(purchase) do
            {:ok, inv_item} ->
              Logger.debug("[CREATE_PURCHASE] Inventory item created: #{inv_item.id}")
            {:error, reason} ->
              Logger.debug("[CREATE_PURCHASE] Inventory item error: #{inspect(reason)}")
            other ->
              Logger.debug("[CREATE_PURCHASE] Inventory item unexpected: #{inspect(other)}")
          end
        rescue
          e ->
            Logger.debug("[CREATE_PURCHASE] Inventory item exception: #{inspect(e)}")
        end
        
        upsert_brand_defaults(purchase)
        final = Repo.preload(purchase, [:budget_entry, :stop, :tags], force: true)
        Logger.debug("[CREATE_PURCHASE] DONE purchase.id=#{final.id} budget_entry_id=#{inspect(final.budget_entry_id)} stop_id=#{inspect(final.stop_id)} stop=#{inspect(final.stop && final.stop.trip_id)}")
        final
      else
        {:error, reason} -> 
          Logger.debug("[CREATE_PURCHASE] FAILED: #{inspect(reason)}")
          Repo.rollback(reason)
        error -> 
          Logger.debug("[CREATE_PURCHASE] FAILED (other): #{inspect(error)}")
          Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, purchase} ->
        # After transaction succeeds, ensure a task exists for the trip
        # This is done outside the transaction to avoid complications
        if purchase.stop && purchase.stop.trip_id do
          Logger.debug("[CREATE_PURCHASE] Ensuring task for trip #{purchase.stop.trip_id}")
          try do
            MegaPlanner.Calendar.ensure_task_for_trip(
              purchase.stop.trip_id,
              purchase.household_id,
              attrs["user_id"],
              date: purchase.budget_entry && purchase.budget_entry.date
            )
          rescue
            e ->
              Logger.warning("[CREATE_PURCHASE] ensure_task_for_trip failed: #{inspect(e)}")
          end
        end
        {:ok, purchase}
      error ->
        error
    end
  end

  # Helper to get store name from a stop
  defp get_store_name_for_stop(nil), do: nil
  defp get_store_name_for_stop(stop_id) do
    stop = get_stop(stop_id)
    cond do
      stop && stop.store -> stop.store.name
      stop && stop.store_name -> stop.store_name
      true -> nil
    end
  end

  @doc """
  Updates a purchase.
  """
  def update_purchase(%Purchase{} = purchase, attrs) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids")

    purchase
    |> Purchase.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, purchase} ->
        purchase = if tag_ids != nil, do: update_purchase_tags(purchase, tag_ids), else: purchase
        
        # Update budget entry if total_price changed
        if Map.has_key?(attrs, "total_price") do
          purchase = Repo.preload(purchase, :budget_entry)
          if purchase.budget_entry do
            case Budget.update_entry(purchase.budget_entry, %{"amount" => attrs["total_price"]}) do
              {:ok, _} -> :ok
              {:error, changeset} -> Repo.rollback(changeset)
            end
          end
        end

        # Sync usage_mode globally to all purchases and inventory items with same brand+item
        if Map.has_key?(attrs, "usage_mode") && purchase.brand && purchase.item do
          new_mode = attrs["usage_mode"]

          # Update all other purchases with same brand+item in the household
          from(p in Purchase,
            where: p.household_id == ^purchase.household_id,
            where: p.id != ^purchase.id,
            where: fragment("LOWER(?) = LOWER(?)", p.brand, ^purchase.brand),
            where: fragment("LOWER(?) = LOWER(?)", p.item, ^purchase.item)
          )
          |> Repo.update_all(set: [usage_mode: new_mode])

          # Update all inventory items with same brand+name in the household's sheets
          from(i in MegaPlanner.Inventory.Item,
            join: s in MegaPlanner.Inventory.Sheet, on: i.sheet_id == s.id,
            where: s.household_id == ^purchase.household_id,
            where: fragment("LOWER(?) = LOWER(?)", i.brand, ^purchase.brand),
            where: fragment("LOWER(?) = LOWER(?)", i.name, ^purchase.item)
          )
          |> Repo.update_all(set: [usage_mode: new_mode])
        end
        

        
        upsert_brand_defaults(purchase)

        {:ok, Repo.preload(purchase, [:budget_entry, :stop, :tags], force: true)}
      error -> error
    end
  end

  defp update_purchase_tags(purchase, tag_ids) when is_list(tag_ids) do
    tags = from(t in Tag, where: t.id in ^tag_ids) |> Repo.all()
    purchase
    |> Repo.preload(:tags)
    |> Purchase.tags_changeset(tags)
    |> Repo.update!()
  end

  defp update_purchase_tags(purchase, _), do: purchase

  @doc """
  Deletes a purchase and its budget entry.
  """
  def delete_purchase(%Purchase{} = purchase) do
    purchase = Repo.preload(purchase, :budget_entry)
    
    Repo.transaction(fn ->
      # 1. Unlink from Inventory Items (to avoid FK constraint on inventory_items.purchase_id)
      from(i in MegaPlanner.Inventory.Item, where: i.purchase_id == ^purchase.id)
      |> Repo.update_all(set: [purchase_id: nil])

      # 2. Delete the purchase. The DB has ON DELETE CASCADE on
      # budget_entries.purchase_id, so the budget entry is automatically deleted.
      with {:ok, _purchase} <- Repo.delete(purchase) do
        :ok
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Calculates tax based on store tax rate.
  """
  def calculate_tax(nil, _amount, _taxable), do: Decimal.new(0)
  
  def calculate_tax(store_id, amount, taxable) when taxable do
    case get_store(store_id) do
      nil -> Decimal.new(0)
      store -> 
        tax_rate = store.tax_rate || get_default_tax_rate(store.state)
        Decimal.mult(amount, tax_rate)
    end
  end

  def calculate_tax(_store_id, _amount, _taxable), do: Decimal.new(0)

  defp get_default_tax_rate("IN"), do: Decimal.new("0.07")
  defp get_default_tax_rate("MI"), do: Decimal.new("0.06")
  defp get_default_tax_rate(_), do: Decimal.new(0)

  @doc """
  Returns suggestions for auto-populate based on brand name.
  """
  def suggest_for_brand(household_id, brand_name, opts \\ []) do
    # Get brand if it exists
    brand = from(b in Brand,
      where: b.household_id == ^household_id and ilike(b.name, ^brand_name),
      limit: 1
    ) |> Repo.one()

    # Get recent purchases with this brand
    store_id = Keyword.get(opts, :store_id)
    
    query = from(p in Purchase,
      where: p.household_id == ^household_id and ilike(p.brand, ^brand_name),
      order_by: [desc: p.inserted_at],
      limit: 5,
      preload: [:tags]
    )
    
    query = if store_id do
      from p in query,
        join: s in assoc(p, :stop),
        where: s.store_id == ^store_id
    else
      query
    end

    recent_purchases = Repo.all(query)

    # ALSO fetch from Inventory Items to fill gaps
    # We map them to look like purchases so the frontend can consume them easily
    inventory_items = from(i in MegaPlanner.Inventory.Item,
      where: i.brand == ^brand_name and not is_nil(i.store_code),
      order_by: [desc: i.updated_at],
      limit: 5,
      preload: [:tags]
    ) |> Repo.all()

    # Convert inventory items to purchase-like structures
    inventory_as_purchases = Enum.map(inventory_items, fn item -> 
      %Purchase{
        id: item.id, # differentiate?
        brand: item.brand,
        item: item.name,
        unit_measurement: item.unit_of_measure,
        count: item.count,
        count_unit: item.count_unit,
        price_per_count: item.price_per_count,
        units: nil, # item doesn't strictly have units/price_per_unit separate the same way? actually it does
        price_per_unit: item.price_per_unit,
        taxable: item.taxable,
        # tax_rate? Inventory item doesn't store tax rate usually, maybe calculate?
        total_price: item.total_price,
        store_code: item.store_code,
        item_name: item.item_name,
        tags: item.tags,
        inserted_at: item.inserted_at,
        updated_at: item.updated_at
      }
    end)

    %{
      brand: brand,
      recent_purchases: recent_purchases ++ inventory_as_purchases
    }
  end

  @doc """
  Returns suggestions for auto-populate based on item name.
  """
  def suggest_for_item(household_id, item_name) do
    from(p in Purchase,
      where: p.household_id == ^household_id and ilike(p.item, ^"%#{item_name}%"),
      order_by: [desc: p.inserted_at],
      limit: 10,
      preload: [:tags],
      distinct: p.brand
    )
    |> Repo.all()
    |> Enum.group_by(& &1.brand)
    |> Enum.map(fn {brand, purchases} ->
      %{
        brand: %{name: brand},
        recent_purchases: purchases
      }
    end)
  end

  @doc """
  Adds selected purchases to inventory sheets.
  """
  def add_purchases_to_inventory(purchase_ids, sheet_assignments) do
    alias MegaPlanner.Inventory
    
    Repo.transaction(fn ->
      Enum.each(purchase_ids, fn purchase_id ->
        purchase = get_purchase(purchase_id)
        sheet_id = Map.get(sheet_assignments, purchase_id)
        
        if sheet_id do
          # Create inventory item from purchase
          item_attrs = %{
            "sheet_id" => sheet_id,
            "name" => purchase.item,
            "brand" => purchase.brand,
            "quantity" => Decimal.to_integer(purchase.count || Decimal.new(0)),
            "unit_measurement" => purchase.unit_measurement,
            "count" => purchase.count,
            "price_per_count" => purchase.price_per_count,
            "price_per_unit" => purchase.price_per_unit,
            "taxable" => purchase.taxable,
            "total_price" => purchase.total_price,
            "store_code" => purchase.store_code,
            "item_name" => purchase.item_name,
            "usage_mode" => purchase.usage_mode || "count"
          }
          
          case Inventory.create_item(item_attrs) do
            {:ok, _item} -> :ok
            {:error, reason} -> Repo.rollback(reason)
          end
        end
      end)
    end)
  end

  defp upsert_brand_defaults(purchase) do
    # We only want to update defaults if we have a valid brand name
    if is_binary(purchase.brand) and purchase.brand != "" do
      # Normalize brand name for search/lookup
      brand_name = String.trim(purchase.brand)
      
      # Find validation/existing brand
      existing_brand = Repo.get_by(Brand, household_id: purchase.household_id, name: brand_name)
      
      tag_ids = Enum.map(purchase.tags, & &1.id)
      
      attrs = %{
        "default_item" => purchase.item,
        "default_unit_measurement" => purchase.unit_measurement,
        "default_count_unit" => purchase.count_unit,
        "default_quantity_per_count" => purchase.units,
        "default_unit_measurement_per_count" => purchase.unit_measurement,
        "default_tags" => tag_ids
      }

      case existing_brand do
        nil ->
          # Create new brand with these defaults
          create_brand(Map.merge(attrs, %{
            "name" => brand_name, 
            "household_id" => purchase.household_id
          }))
        
        brand ->
          # Update existing brand defaults
          update_brand(brand, attrs)
      end
    end
    
    # Always return the purchase to keep the pipe/with chain flowing smoothly
    purchase
  end



  @doc """
  Searches stores by name.
  """
  def search_stores(household_id, query) do
    from(s in Store,
      where: s.household_id == ^household_id and (ilike(s.name, ^"%#{query}%") or ilike(s.store_code, ^"%#{query}%")),
      order_by: [asc: s.name],
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Returns distinct store codes matching the query.
  """
  def suggest_store_codes(household_id, query) do
    purchases_codes = from(p in Purchase,
      where: p.household_id == ^household_id and not is_nil(p.store_code) and ilike(p.store_code, ^"%#{query}%"),
      select: p.store_code,
      distinct: true,
      order_by: [asc: p.store_code],
      limit: 10
    )
    |> Repo.all()

    inventory_codes = from(i in MegaPlanner.Inventory.Item,
      join: s in assoc(i, :sheet),
      where: s.household_id == ^household_id and not is_nil(i.store_code) and ilike(i.store_code, ^"%#{query}%"),
      select: i.store_code,
      distinct: true,
      order_by: [asc: i.store_code],
      limit: 10
    )
    |> Repo.all()

    (purchases_codes ++ inventory_codes)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.take(10)
  end

  @doc """
  Returns distinct receipt item names matching the query.
  """
  def suggest_receipt_item_names(household_id, query) do
    purchase_names = from(p in Purchase,
      where: p.household_id == ^household_id and not is_nil(p.item_name) and ilike(p.item_name, ^"%#{query}%"),
      select: p.item_name,
      distinct: true,
      order_by: [asc: p.item_name],
      limit: 10
    )
    |> Repo.all()

    inventory_names = from(i in MegaPlanner.Inventory.Item,
      join: s in assoc(i, :sheet),
      where: s.household_id == ^household_id and not is_nil(i.item_name) and ilike(i.item_name, ^"%#{query}%"),
      select: i.item_name,
      distinct: true,
      order_by: [asc: i.item_name],
      limit: 10
    )
    |> Repo.all()

    (purchase_names ++ inventory_names)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.take(10)
  end

  @doc """
  Returns distinct item names matching the query.
  """
  def suggest_names(household_id, query) do
    purchases = from(p in Purchase,
      where: p.household_id == ^household_id and ilike(p.item, ^"%#{query}%"),
      select: p.item,
      distinct: true,
      order_by: [asc: p.item],
      limit: 10
    )
    |> Repo.all()

    inventory = from(i in MegaPlanner.Inventory.Item,
      join: s in assoc(i, :sheet),
      where: s.household_id == ^household_id and ilike(i.name, ^"%#{query}%"),
      select: i.name,
      distinct: true,
      order_by: [asc: i.name],
      limit: 10
    )
    |> Repo.all()

    (purchases ++ inventory)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.take(10)
  end

  # Format Corrections (for learning from user edits)

  @doc """
  Upserts a format correction record to store user's preferred formatting.
  Used to learn from how users correct OCR text.
  
  Learns:
  - Brand name preferences
  - Item name formatting
  - Unit preferences
  - Quantity interpretations
  - Unit quantity (volume/weight) preferences
  """
  def upsert_format_correction(attrs) do
    changeset = FormatCorrection.changeset(%FormatCorrection{}, attrs)
    
    Repo.insert(changeset,
      on_conflict: {:replace, [
        :corrected_brand, 
        :corrected_item, 
        :corrected_unit,
        :corrected_quantity,
        :corrected_unit_quantity,
        :preference_notes,
        :updated_at
      ]},
      conflict_target: [:household_id, :raw_text]
    )
  end

  @doc """
  Gets a format correction by raw text for a household.
  """
  def get_format_correction(household_id, raw_text) do
    from(fc in FormatCorrection,
      where: fc.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", fc.raw_text, ^raw_text),
      limit: 1
    )
    |> Repo.one()
  end

  # Tax Indicator Meanings

  @doc """
  Gets the meaning of a tax indicator for a specific store.
  Returns nil if no custom meaning has been defined.
  """
  def get_tax_indicator_meaning(household_id, store_name, indicator) do
    from(tim in TaxIndicatorMeaning,
      where: tim.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", tim.store_name, ^store_name),
      where: fragment("UPPER(?) = UPPER(?)", tim.indicator, ^indicator),
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Gets all tax indicator meanings for a store.
  """
  def list_tax_indicator_meanings(household_id, store_name) do
    from(tim in TaxIndicatorMeaning,
      where: tim.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", tim.store_name, ^store_name),
      order_by: [asc: tim.indicator]
    )
    |> Repo.all()
  end

  @doc """
  Upserts a tax indicator meaning.
  Used when user corrects the AI's interpretation of a tax indicator.
  """
  def upsert_tax_indicator_meaning(attrs) do
    changeset = TaxIndicatorMeaning.changeset(%TaxIndicatorMeaning{}, attrs)
    
    Repo.insert(changeset,
      on_conflict: {:replace, [:is_taxable, :description, :default_tax_rate, :updated_at]},
      conflict_target: [:household_id, :store_name, :indicator]
    )
  end

  @doc """
  Applies learned tax indicator meanings to an item.
  Returns the item with updated taxable/tax_rate fields if a meaning is found.
  """
  def apply_tax_indicator_meaning(item, household_id, store_name) do
    indicator = item[:tax_indicator] || item["tax_indicator"]
    
    if indicator && indicator != "" do
      case get_tax_indicator_meaning(household_id, store_name, indicator) do
        nil -> item
        meaning ->
          item
          |> Map.put(:taxable, meaning.is_taxable)
          |> Map.put(:tax_rate, meaning.default_tax_rate)
      end
    else
      item
    end
  end

  @doc false
  defp sync_usage_mode_globally(household_id, brand, item_name, exclude_id, new_mode, source_type) do
    # Update all purchases with same brand+item in the household
    purchase_query = from(p in Purchase,
      where: p.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", p.brand, ^brand),
      where: fragment("LOWER(?) = LOWER(?)", p.item, ^item_name)
    )
    purchase_query = if source_type == :purchase do
      from(p in purchase_query, where: p.id != ^exclude_id)
    else
      purchase_query
    end
    Repo.update_all(purchase_query, set: [usage_mode: new_mode])

    # Update all inventory items with same brand+name in the household
    item_query = from(i in MegaPlanner.Inventory.Item,
      join: s in MegaPlanner.Inventory.Sheet, on: i.sheet_id == s.id,
      where: s.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", i.brand, ^brand),
      where: fragment("LOWER(?) = LOWER(?)", i.name, ^item_name)
    )
    item_query = if source_type == :inventory do
      from(i in item_query, where: i.id != ^exclude_id)
    else
      item_query
    end
    Repo.update_all(item_query, set: [usage_mode: new_mode])
  end
end

