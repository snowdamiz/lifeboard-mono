defmodule MegaPlannerWeb.BrandController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Receipts
  alias MegaPlanner.Receipts.Brand

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    
    opts = []
    |> maybe_add_search(params["search"])

    brands = Receipts.list_brands(user.household_id, opts)
    json(conn, %{data: Enum.map(brands, &brand_to_json/1)})
  end

  def search(conn, %{"q" => query}) do
    user = Guardian.Plug.current_resource(conn)
    
    if user do
      brands = Receipts.search_brands(user.household_id, query)
      json(conn, %{data: Enum.map(brands, &brand_to_json/1)})
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Authentication required"})
    end
  end

  def create(conn, %{"brand" => brand_params}) do
    user = Guardian.Plug.current_resource(conn)
    brand_params = Map.put(brand_params, "household_id", user.household_id)

    with {:ok, %Brand{} = brand} <- Receipts.create_brand(brand_params) do
      conn
      |> put_status(:created)
      |> json(%{data: brand_to_json(brand)})
    end
  end

  def update(conn, %{"id" => id, "brand" => brand_params}) do
    with brand when not is_nil(brand) <- Receipts.get_brand(id),
         {:ok, %Brand{} = brand} <- Receipts.update_brand(brand, brand_params) do
      json(conn, %{data: brand_to_json(brand)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp maybe_add_search(opts, value) when is_binary(value) and value != "" do
    Keyword.put(opts, :search, value)
  end
  defp maybe_add_search(opts, _value), do: opts

  defp brand_to_json(brand) do
    %{
      id: brand.id,
      name: brand.name,
      default_item: brand.default_item,
      default_unit_measurement: brand.default_unit_measurement,
      default_count_unit: brand.default_count_unit,
      default_tags: brand.default_tags,
      image_url: brand.image_url,
      inserted_at: brand.inserted_at,
      updated_at: brand.updated_at
    }
  end
end
