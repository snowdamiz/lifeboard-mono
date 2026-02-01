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
      "address" => store_params["address"],
      "state" => store_params["state"],
      "store_code" => store_params["store_code"],
      "household_id" => household_id
    }

    case Receipts.create_store(attrs) do
      {:ok, store} -> store
      {:error, _} -> 
        # Try to find existing store
        Receipts.find_store_by_name(household_id, store_params["name"]) ||
          raise "Failed to create or find store"
    end
  end

  defp ensure_stop(trip_id, store, transaction, _household_id) do
    # Parse time from transaction
    time_arrived = parse_time(transaction["time"]) || ~T[12:00:00]
    
    # Get existing stops count for position
    trip = Receipts.get_trip!(trip_id)
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
  defp parse_time(time_string) do
    case Time.from_iso8601(time_string <> ":00") do
      {:ok, time} -> time
      _ -> nil
    end
  end

  defp create_purchases(items, stop, store, transaction, user, household_id) do
    alias MegaPlanner.Repo
    alias MegaPlanner.Receipts.Purchase
    
    date = parse_date(transaction["date"]) || Date.utc_today()

    Enum.map(items, fn item ->
      # Ensure brand exists
      brand = ensure_brand(item["brand"], household_id)
      
      # Ensure unit exists
      unit = if item["unit"], do: ensure_unit(item["unit"], household_id), else: nil

      # Save format correction if user edited this item
      save_format_correction_if_edited(item, household_id)

      # Create budget entry first
      {:ok, budget_entry} = create_budget_entry(
        item,
        store,
        date,
        user,
        household_id
      )

      # Create purchase directly (not using Receipts.create_purchase which creates its own budget entry)
      purchase_attrs = %{
        "brand" => brand.name,
        "item" => item["item"] || item["raw_text"] || "",
        "unit_measurement" => unit && unit.name,
        "count" => item["quantity"] || 1,
        "units" => item["unit_quantity"],
        "price_per_unit" => item["unit_price"],
        "total_price" => item["total_price"] || "0",
        "taxable" => item["taxable"] || false,
        "store_code" => item["store_code"],
        "item_name" => item["raw_text"],
        "stop_id" => stop && stop.id,
        "budget_entry_id" => budget_entry.id,
        "household_id" => household_id
      }

      changeset = Purchase.changeset(%Purchase{}, purchase_attrs)
      
      case Repo.insert(changeset) do
        {:ok, purchase} -> purchase
        {:error, changeset} ->
          require Logger
          Logger.error("Failed to create purchase: #{inspect(changeset)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Store format correction when user makes edits to learn from their preferences
  defp save_format_correction_if_edited(item, household_id) do
    raw_text = item["raw_text"]
    brand = item["brand"]
    item_name = item["item"]
    
    # Skip if no raw_text to learn from
    if is_nil(raw_text) or raw_text == "" do
      :ok
    else
      # Check if user made meaningful edits (not just AI-generated values)
      brand_edited = brand && brand != "" && !similar_text?(raw_text, brand)
      item_edited = item_name && item_name != "" && !similar_text?(raw_text, item_name)
      
      if brand_edited or item_edited do
        Receipts.upsert_format_correction(%{
          "household_id" => household_id,
          "raw_text" => raw_text,
          "corrected_brand" => if(brand_edited, do: brand, else: nil),
          "corrected_item" => if(item_edited, do: item_name, else: nil),
          "match_type" => "exact"
        })
      end
    end
  end

  # Check if two strings are similar (one contains most of the other)
  defp similar_text?(text1, text2) do
    t1 = String.downcase(text1 || "") |> String.trim()
    t2 = String.downcase(text2 || "") |> String.trim()
    
    String.contains?(t1, t2) or String.contains?(t2, t1)
  end


  defp ensure_brand(nil, household_id), do: ensure_brand("Generic", household_id)
  defp ensure_brand("", household_id), do: ensure_brand("Generic", household_id)
  defp ensure_brand(brand_name, household_id) do
    case Receipts.get_brand_by_name(household_id, brand_name) do
      nil ->
        {:ok, brand} = Receipts.create_brand(%{
          "name" => brand_name,
          "household_id" => household_id
        })
        brand
      brand -> brand
    end
  end

  defp ensure_unit(nil, _household_id), do: nil
  defp ensure_unit("", _household_id), do: nil
  defp ensure_unit(unit_name, household_id) do
    case Receipts.get_unit_by_name(household_id, unit_name) do
      nil ->
        {:ok, unit} = Receipts.create_unit(%{
          "name" => unit_name,
          "household_id" => household_id
        })
        unit
      unit -> unit
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
      "amount" => item["total_price"] || "0",
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
