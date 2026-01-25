defmodule MegaPlannerWeb.PurchaseController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Receipts
  alias MegaPlanner.Receipts.Purchase

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    
    opts = []
    |> maybe_add_opt(:stop_id, params["stop_id"])
    |> maybe_add_opt(:brand, params["brand"])
    |> maybe_add_opt(:source_id, params["source_id"])

    purchases = Receipts.list_purchases(user.household_id, opts)
    json(conn, %{data: Enum.map(purchases, &purchase_to_json/1)})
  end

  def create(conn, %{"purchase" => purchase_params}) do
    File.write("debug_output.txt", "\n[#{DateTime.utc_now()}] CREATE PURCHASE Params: #{inspect(purchase_params)}\n", [:append])
    
    user = Guardian.Plug.current_resource(conn)
    purchase_params = purchase_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    case Receipts.create_purchase(purchase_params) do
      {:ok, purchase} ->
        File.write("debug_output.txt", "[#{DateTime.utc_now()}] SUCCESS: #{purchase.id}\n", [:append])
        conn
        |> put_status(:created)
        |> json(%{data: purchase_to_json(purchase)})
      {:error, reason} ->
        File.write("debug_output.txt", "[#{DateTime.utc_now()}] ERROR: #{inspect(reason)}\n", [:append])
        {:error, reason}
    end
  end

  def show(conn, %{"id" => id}) do
    case Receipts.get_purchase(id) do
      nil -> {:error, :not_found}
      purchase -> json(conn, %{data: purchase_to_json(purchase)})
    end
  end

  def update(conn, %{"id" => id, "purchase" => purchase_params}) do
    with purchase when not is_nil(purchase) <- Receipts.get_purchase(id),
         {:ok, %Purchase{} = purchase} <- Receipts.update_purchase(purchase, purchase_params) do
      json(conn, %{data: purchase_to_json(purchase)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    with purchase when not is_nil(purchase) <- Receipts.get_purchase(id),
         {:ok, _} <- Receipts.delete_purchase(purchase) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def suggest_by_brand(conn, %{"brand" => brand} = params) do
    user = Guardian.Plug.current_resource(conn)
    opts = []
    |> maybe_add_opt(:store_id, params["store_id"])
    
    suggestion = Receipts.suggest_for_brand(user.household_id, brand, opts)
    json(conn, %{data: suggestion_to_json(suggestion)})
  end

  def suggest_by_item(conn, %{"item" => item}) do
    user = Guardian.Plug.current_resource(conn)
    suggestions = Receipts.suggest_for_item(user.household_id, item)
    json(conn, %{data: Enum.map(suggestions, &suggestion_to_json/1)})
  end

  def add_to_inventory(conn, %{"purchase_ids" => purchase_ids, "sheet_assignments" => sheet_assignments}) do
    with {:ok, _} <- Receipts.add_purchases_to_inventory(purchase_ids, sheet_assignments) do
      send_resp(conn, :no_content, "")
    end
  end

  def suggest_stores(conn, %{"search" => search}) do
    user = Guardian.Plug.current_resource(conn)
    stores = Receipts.search_stores(user.household_id, search)
    json(conn, %{data: Enum.map(stores, &store_to_json/1)})
  end

  def suggest_store_codes(conn, %{"search" => search}) do
    user = Guardian.Plug.current_resource(conn)
    codes = Receipts.suggest_store_codes(user.household_id, search)
    json(conn, %{data: codes})
  end

  def suggest_receipt_items(conn, %{"search" => search}) do
    user = Guardian.Plug.current_resource(conn)
    names = Receipts.suggest_receipt_item_names(user.household_id, search)
    json(conn, %{data: names})
  end

  def suggest_items(conn, %{"search" => search}) do
    user = Guardian.Plug.current_resource(conn)
    names = Receipts.suggest_names(user.household_id, search)
    json(conn, %{data: names})
  end

  defp maybe_add_opt(opts, key, value) when is_binary(value) and value != "" do
    Keyword.put(opts, key, value)
  end
  defp maybe_add_opt(opts, _key, _value), do: opts

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
      tax_rate: purchase.tax_rate,
      total_price: purchase.total_price,
      store_code: purchase.store_code,
      item_name: purchase.item_name,
      tags: Enum.map(purchase.tags || [], &tag_to_json/1),
      inserted_at: purchase.inserted_at,
      updated_at: purchase.updated_at
    }
  end

  defp suggestion_to_json(suggestion) do
    %{
      brand: if(suggestion.brand, do: brand_to_json(suggestion.brand), else: suggestion[:brand]),
      recent_purchases: Enum.map(suggestion.recent_purchases || [], &purchase_to_json/1)
    }
  end

  defp brand_to_json(brand) when is_map(brand) and not is_struct(brand) do
    brand
  end

  defp brand_to_json(brand) do
    %{
      id: brand.id,
      name: brand.name,
      default_item: brand.default_item,
      default_unit_measurement: brand.default_unit_measurement,
      default_tags: brand.default_tags,
      image_url: brand.image_url
    }
  end

  defp tag_to_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color
    }
  end

  defp store_to_json(store) do
    %{
      id: store.id,
      name: store.name
    }
  end
end
