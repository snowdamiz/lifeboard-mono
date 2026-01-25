defmodule MegaPlannerWeb.BudgetSourceController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Budget
  alias MegaPlanner.Budget.Source

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    sources = Budget.list_sources(user.household_id)
    json(conn, %{data: Enum.map(sources, &source_to_json/1)})
  end

  def create(conn, %{"source" => source_params}) do
    user = Guardian.Plug.current_resource(conn)
    source_params = source_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %Source{} = source} <- Budget.create_source(source_params) do
      conn
      |> put_status(:created)
      |> json(%{data: source_to_json(source)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Budget.get_household_source(user.household_id, id) do
      nil -> {:error, :not_found}
      source -> json(conn, %{data: source_to_json(source)})
    end
  end

  def update(conn, %{"id" => id, "source" => source_params}) do
    user = Guardian.Plug.current_resource(conn)

    with source when not is_nil(source) <- Budget.get_household_source(user.household_id, id),
         {:ok, %Source{} = source} <- Budget.update_source(source, source_params) do
      json(conn, %{data: source_to_json(source)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with source when not is_nil(source) <- Budget.get_household_source(user.household_id, id),
         {:ok, %Source{}} <- Budget.delete_source(source) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp source_to_json(source) do
    %{
      id: source.id,
      name: source.name,
      type: source.type,
      amount: source.amount,
      tags: Enum.map(source.tag_objects || [], &tag_to_json/1),
      inserted_at: source.inserted_at,
      updated_at: source.updated_at
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
