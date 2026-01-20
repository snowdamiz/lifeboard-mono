defmodule MegaPlannerWeb.StoreController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Receipts
  alias MegaPlanner.Receipts.Store

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    stores = Receipts.list_stores(user.household_id)
    json(conn, %{data: Enum.map(stores, &store_to_json/1)})
  end

  def create(conn, %{"store" => store_params}) do
    user = Guardian.Plug.current_resource(conn)
    store_params = Map.put(store_params, "household_id", user.household_id)

    with {:ok, %Store{} = store} <- Receipts.create_store(store_params) do
      conn
      |> put_status(:created)
      |> json(%{data: store_to_json(store)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Receipts.get_household_store(user.household_id, id) do
      nil -> {:error, :not_found}
      store -> json(conn, %{data: store_to_json(store)})
    end
  end

  def update(conn, %{"id" => id, "store" => store_params}) do
    user = Guardian.Plug.current_resource(conn)

    with store when not is_nil(store) <- Receipts.get_household_store(user.household_id, id),
         {:ok, %Store{} = store} <- Receipts.update_store(store, store_params) do
      json(conn, %{data: store_to_json(store)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with store when not is_nil(store) <- Receipts.get_household_store(user.household_id, id),
         {:ok, %Store{}} <- Receipts.delete_store(store) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def get_inventory(conn, %{"store_id" => store_id}) do
    user = Guardian.Plug.current_resource(conn)

    with store when not is_nil(store) <- Receipts.get_household_store(user.household_id, store_id) do
      inventory = Receipts.list_store_inventory(store)
      json(conn, %{data: inventory})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def update_inventory_item(conn, %{"store_id" => store_id, "item_id" => item_id} = params) do
    user = Guardian.Plug.current_resource(conn)
    source = Map.get(params, "source")
    propagate = Map.get(params, "propagate", false)
    attrs = Map.drop(params, ["store_id", "item_id", "source", "propagate"])

    # Verify store access first
    with store when not is_nil(store) <- Receipts.get_household_store(user.household_id, store_id),
         {:ok, _result} <- Receipts.update_store_inventory_item(store.id, item_id, source, attrs, propagate) do
      
      # Return updated inventory list so UI can refresh
      inventory = Receipts.list_store_inventory(store)
      json(conn, %{data: inventory})
    else
      nil -> {:error, :not_found}
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to update item"})
    end
  end

  defp store_to_json(store) do
    %{
      id: store.id,
      name: store.name,
      address: store.address,
      state: store.state,
      store_code: store.store_code,
      tax_rate: store.tax_rate,
      inserted_at: store.inserted_at,
      updated_at: store.updated_at
    }
  end
end
