defmodule MegaPlannerWeb.ReceiptUploadController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Receipts.ReceiptParser
  alias MegaPlanner.Receipts
  alias MegaPlanner.Budget

  action_fallback MegaPlannerWeb.FallbackController

  @doc """
  POST /api/receipts/scan
  
  Accepts a receipt image and returns parsed data with AI suggestions.
  The receipt image is not stored - only used for data extraction.
  """
  def scan(conn, %{"image" => image_data}) do
    require Logger
    
    try do
      Logger.info("Receipt scan request received, image size: #{String.length(image_data)} chars")

      user = Guardian.Plug.current_resource(conn)
      household_id = user.household_id
      
      Logger.info("User: #{user.id}, Household: #{household_id}")

      case ReceiptParser.parse_receipt_image(image_data, household_id) do
        {:ok, parsed_data} ->
          Logger.info("Receipt parsed successfully")
          conn
          |> put_status(:ok)
          |> json(%{data: parsed_data})

        {:error, reason} ->
          Logger.error("Receipt parsing failed: #{inspect(reason)}")
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: reason})
      end
    rescue
      e ->
        Logger.error("Exception in scan: #{Exception.message(e)}")
        Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error: #{Exception.message(e)}"})
    end
  end

  def scan(conn, _params) do
    require Logger
    Logger.error("Receipt scan called without image data")
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing 'image' parameter"})
  end

  @doc """
  POST /api/receipts/confirm
  
  Confirms parsed receipt data and creates entities:
  - Store (if new)
  - Stop (linked to trip if provided)
  - Purchases (with budget entries)
  - Brands (if new)
  - Units (if new)
  """
  def confirm(conn, params) do
    require Logger
    
    try do
      user = Guardian.Plug.current_resource(conn)
      household_id = user.household_id
      
      Logger.info("Receipt confirm request - user: #{user.id}, household: #{household_id}")
      Logger.debug("Receipt confirm params: #{inspect(params, limit: 500)}")

      with {:ok, result} <- create_receipt_entities(params, user, household_id) do
        Logger.info("Receipt confirm success - created #{result.created_count} purchases")
        conn
        |> put_status(:created)
        |> json(%{data: result})
      else
        {:error, reason} when is_binary(reason) ->
          Logger.error("Receipt confirm failed (string error): #{reason}")
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: reason})

        {:error, %Ecto.Changeset{} = changeset} ->
          Logger.error("Receipt confirm failed (changeset): #{inspect(changeset)}")
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_changeset_errors(changeset)})

        {:error, reason} ->
          Logger.error("Receipt confirm failed (other): #{inspect(reason)}")
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: inspect(reason)})
      end
    rescue
      e ->
        Logger.error("Exception in confirm: #{Exception.message(e)}")
        Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error: #{Exception.message(e)}"})
    end
  end

  defp create_receipt_entities(params, user, household_id) do
    alias MegaPlanner.Repo

    Repo.transaction(fn ->
      # 1. Create or get store
      store = ensure_store(params["store"], household_id)
      
      # 2. Create or get trip/stop if trip_id provided
      stop = if params["trip_id"] do
        ensure_stop(params["trip_id"], store, params["transaction"], household_id)
      else
        nil
      end

      # 3. Create purchases with budget entries
      purchases = create_purchases(
        params["items"] || [],
        stop,
        store,
        params["transaction"],
        user,
        household_id
      )

      %{
        store: serialize_store(store),
        stop_id: stop && stop.id,
        purchases: Enum.map(purchases, &serialize_purchase/1),
        created_count: length(purchases)
      }
    end)
  end


  defp ensure_store(%{"id" => id}, _household_id) when not is_nil(id) and id != "" do
    Receipts.get_store!(id)
  end

  defp ensure_store(nil, household_id) do
    # No store info provided, create a generic one
    attrs = %{
      "name" => "Unknown Store",
      "household_id" => household_id
    }

    case Receipts.create_store(attrs) do
      {:ok, store} -> store
      {:error, _} -> 
        Receipts.find_store_by_name(household_id, "Unknown Store") ||
          raise "Failed to create or find store"
    end
  end

  defp ensure_store(store_params, household_id) do
    attrs = %{
      "name" => store_params["name"] || "Unknown Store",
      "store_id" => store_params["store_id"],
      "street" => store_params["street"],
      "suite" => store_params["suite"],
      "city" => store_params["city"],
      "state" => store_params["state"],
      "zip_code" => store_params["zip_code"],
      "phone" => store_params["phone"],
      "address" => store_params["address"],
      "store_code" => store_params["store_code"],
      "household_id" => household_id
    }

    case Receipts.create_store(attrs) do
      {:ok, store} -> store
      {:error, _} -> 
        # Try to find existing store by store_id first, then by name
        find_existing_store(store_params, household_id) ||
          raise "Failed to create or find store"
    end
  end

  defp find_existing_store(store_params, household_id) do
    store_id = store_params["store_id"]
    if store_id && store_id != "" do
      Receipts.find_store_by_store_id(household_id, store_id)
    end || Receipts.find_store_by_name(household_id, store_params["name"])
  end

  defp ensure_stop(trip_id, store, transaction, _household_id) do
    # Parse time from transaction
    time_arrived = parse_time(transaction["time"]) || ~T[12:00:00]
    
    # Get existing trip and update its date if receipt has a different date
    trip = Receipts.get_trip!(trip_id)
    
    # Update trip_start and task date to match receipt date/time if available
    receipt_date = parse_date(transaction["date"])
    if receipt_date do
      # Always update trip_start with receipt date+time (fixes midnight default issue)
      new_trip_start = DateTime.new!(receipt_date, time_arrived, "Etc/UTC")
      Receipts.update_trip(trip, %{trip_start: new_trip_start})
      
      # Also update the associated task's date to match receipt date if different
      trip_date = if trip.trip_start, do: DateTime.to_date(trip.trip_start), else: nil
      if trip_date != receipt_date do
        case MegaPlanner.Calendar.get_task_by_trip_id(trip_id) do
          nil -> :ok
          task ->
            task_date = task.date
            if task_date != receipt_date do
              require Logger
              Logger.info("Updating task date from #{task_date} to #{receipt_date} based on receipt")
              MegaPlanner.Calendar.update_task(task, %{"date" => Date.to_iso8601(receipt_date)})
            end
        end
      end
    end
    
    position = length(trip.stops || []) + 1

    attrs = %{
      "trip_id" => trip_id,
      "store_id" => store.id,
      "store_name" => store.name,
      "position" => position,
      "time_arrived" => time_arrived,
      "time_left" => time_arrived
    }

    case Receipts.create_stop(trip_id, attrs) do
      {:ok, stop} -> stop
      {:error, _} -> nil
    end
  end

  defp parse_time(nil), do: nil
  defp parse_time(""), do: nil
  defp parse_time(time_string) do
    require Logger
    # Try parsing as ISO8601 time format (HH:MM or HH:MM:SS)
    # First, normalize the format - if it's "H:MM", pad to "HH:MM"
    normalized = cond do
      # Already has seconds
      String.match?(time_string, ~r/^\d{1,2}:\d{2}:\d{2}$/) ->
        time_string
      # Just HH:MM - add seconds
      String.match?(time_string, ~r/^\d{1,2}:\d{2}$/) ->
        time_string <> ":00"
      true ->
        time_string <> ":00"
    end
    
    # Pad hours if needed (e.g., "9:30:00" -> "09:30:00")
    normalized = case String.split(normalized, ":") do
      [h, m, s] when byte_size(h) == 1 -> "0" <> h <> ":" <> m <> ":" <> s
      _ -> normalized
    end
    
    case Time.from_iso8601(normalized) do
      {:ok, time} -> 
        Logger.debug("Parsed time '#{time_string}' -> #{time}")
        time
      {:error, reason} -> 
        Logger.warning("Failed to parse time '#{time_string}' (normalized: '#{normalized}'): #{inspect(reason)}")
        nil
    end
  end

  defp create_purchases(items, stop, store, transaction, user, household_id) do
    alias MegaPlanner.Repo
    alias MegaPlanner.Receipts.Purchase
    
    date = parse_date(transaction["date"]) || Date.utc_today()

    # First pass: create all purchases with raw brand/unit names
    # Don't create brand/unit entities yet - wait until purchase succeeds
    purchases = Enum.map(items, fn item ->
      # Save format correction to learn from user edits
      save_format_correction_if_edited(item, household_id)

      # Create budget entry first
      {:ok, budget_entry} = create_budget_entry(
        item,
        store,
        date,
        user,
        household_id
      )

      # Get raw brand/unit names - will create entities after purchase succeeds
      brand_name = normalize_brand_name(item["brand"])
      unit_name = item["unit"]

      # Create purchase with the raw brand/unit name strings
      # Note: All decimal fields must be converted to string for proper Ecto casting
      # (Ecto's :decimal type can't cast float numbers like 5.3 directly)
      
      purchase_attrs = %{
        "brand" => brand_name,
        "item" => item["item"] || item["raw_text"] || "",
        "unit_measurement" => unit_name,
        "count" => decimal_to_string(item["quantity"]) || "1",
        "units" => decimal_to_string(item["unit_quantity"]),
        "price_per_unit" => decimal_to_string(item["unit_price"]),
        "total_price" => decimal_to_string(item["total_price"]) || "0",
        "taxable" => item["taxable"] || false,
        "store_code" => item["store_code"],
        "item_name" => item["raw_text"],
        "usage_mode" => item["usage_mode"] || "count",
        "stop_id" => stop && stop.id,
        "budget_entry_id" => budget_entry.id,
        "household_id" => household_id
      }

      changeset = Purchase.changeset(%Purchase{}, purchase_attrs)
      
      case Repo.insert(changeset) do
        {:ok, purchase} -> 
          # Only NOW create brand/unit entities since purchase succeeded
          # This ensures we only create entities for user-confirmed items
          ensure_brand_for_confirmed_purchase(brand_name, household_id)
          if unit_name, do: ensure_unit_for_confirmed_purchase(unit_name, household_id)
          
          # Create the corresponding inventory item in the Purchases sheet
          MegaPlanner.Inventory.create_item_from_purchase(purchase)
          
          purchase
        {:error, changeset} ->
          require Logger
          Logger.error("Failed to create purchase: #{inspect(changeset)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    # Log what was learned for debugging
    require Logger
    Logger.info("Receipt confirm: created #{length(purchases)} purchases, saved format corrections for learning")
    
    purchases
  end

  # Normalize brand name - use "Generic" for empty/nil
  defp normalize_brand_name(nil), do: "Generic"
  defp normalize_brand_name(""), do: "Generic"
  defp normalize_brand_name(name), do: String.trim(name)

  # Store format correction when user makes edits to learn from their preferences
  # Enhanced to also learn unit and quantity preferences
  defp save_format_correction_if_edited(item, household_id) do
    raw_text = item["raw_text"]
    brand = item["brand"]
    item_name = item["item"]
    unit = item["unit"]
    quantity = item["quantity"]
    unit_quantity = item["unit_quantity"]
    
    # Skip if no raw_text to learn from
    if is_nil(raw_text) or raw_text == "" do
      :ok
    else
      # Check if user made meaningful edits (not just AI-generated values)
      brand_edited = brand && brand != "" && !similar_text?(raw_text, brand)
      item_edited = item_name && item_name != "" && !similar_text?(raw_text, item_name)
      unit_edited = unit && unit != ""
      quantity_edited = quantity && is_integer(quantity) && quantity != 1
      
      # unit_quantity can be string "16" or number 16 - check for any meaningful value
      unit_quantity_value = parse_unit_quantity(unit_quantity)
      unit_quantity_has_value = unit_quantity_value != nil
      
      require Logger
      Logger.info("Learning check for raw_text: #{raw_text}")
      Logger.info("  unit_quantity raw: #{inspect(unit_quantity)}, parsed: #{inspect(unit_quantity_value)}, has_value: #{unit_quantity_has_value}")
      
      if brand_edited or item_edited or unit_edited or quantity_edited or unit_quantity_has_value do
        result = Receipts.upsert_format_correction(%{
          "household_id" => household_id,
          "raw_text" => raw_text,
          "corrected_brand" => if(brand_edited, do: brand, else: nil),
          "corrected_item" => if(item_edited, do: item_name, else: nil),
          "corrected_unit" => if(unit_edited, do: unit, else: nil),
          "corrected_quantity" => if(quantity_edited, do: quantity, else: nil),
          "corrected_unit_quantity" => unit_quantity_value,
          "match_type" => "exact"
        })
        Logger.info("  Upsert result: #{inspect(result)}")
        result
      end
    end
  end


  defp parse_unit_quantity(nil), do: nil
  defp parse_unit_quantity(""), do: nil
  defp parse_unit_quantity(value) when is_binary(value) do
    case Decimal.parse(String.trim(value)) do
      {decimal, _} -> decimal
      :error -> nil
    end
  end
  defp parse_unit_quantity(value) when is_integer(value), do: Decimal.new(value)
  defp parse_unit_quantity(value) when is_float(value), do: Decimal.from_float(value)
  defp parse_unit_quantity(_), do: nil

  # Check if two strings are similar (one contains most of the other)
  defp similar_text?(text1, text2) do
    t1 = String.downcase(text1 || "") |> String.trim()
    t2 = String.downcase(text2 || "") |> String.trim()
    
    String.contains?(t1, t2) or String.contains?(t2, t1)
  end

  # Convert any value to string for Decimal field casting
  # Ecto's :decimal type can cast strings but not raw floats from JSON
  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(""), do: nil
  defp decimal_to_string(value) when is_number(value), do: to_string(value)
  defp decimal_to_string(value) when is_binary(value), do: value
  defp decimal_to_string(_), do: nil

  # Create brand entity only after purchase is confirmed
  defp ensure_brand_for_confirmed_purchase(brand_name, household_id) do
    case Receipts.get_brand_by_name(household_id, brand_name) do
      nil ->
        Receipts.create_brand(%{
          "name" => brand_name,
          "household_id" => household_id
        })
      _brand -> :ok
    end
  end

  # Create unit entity only after purchase is confirmed
  defp ensure_unit_for_confirmed_purchase(nil, _household_id), do: :ok
  defp ensure_unit_for_confirmed_purchase("", _household_id), do: :ok
  defp ensure_unit_for_confirmed_purchase(unit_name, household_id) do
    case Receipts.get_unit_by_name(household_id, unit_name) do
      nil ->
        Receipts.create_unit(%{
          "name" => unit_name,
          "household_id" => household_id
        })
      _unit -> :ok
    end
  end

  defp create_budget_entry(item, store, date, user, household_id) do
    # Get or create expense source for store
    {:ok, source} = Budget.get_or_create_source_for_store(
      household_id,
      user.id,
      store.name
    )

    Budget.create_entry(%{
      "date" => Date.to_iso8601(date),
      "amount" => decimal_to_string(item["total_price"]) || "0",
      "type" => "expense",
      "notes" => item["raw_text"],
      "source_id" => source && source.id,
      "user_id" => user.id,
      "household_id" => household_id
    })
  end

  defp parse_date(nil), do: nil
  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp serialize_store(store) do
    %{
      id: store.id,
      name: store.name,
      address: store.address,
      state: store.state,
      store_code: store.store_code
    }
  end

  defp serialize_purchase(purchase) do
    %{
      id: purchase.id,
      brand: purchase.brand,
      item: purchase.item,
      total_price: purchase.total_price,
      budget_entry_id: purchase.budget_entry_id
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
