defmodule MegaPlannerWeb.GoalCategoryController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Goals
  alias MegaPlanner.Goals.GoalCategory

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    categories = Goals.list_top_level_categories(user.household_id)
    json(conn, %{data: Enum.map(categories, &category_to_json/1)})
  end

  def create(conn, %{"category" => category_params}) do
    user = Guardian.Plug.current_resource(conn)
    category_params = Map.put(category_params, "household_id", user.household_id)

    with {:ok, %GoalCategory{} = category} <- Goals.create_goal_category(category_params) do
      conn
      |> put_status(:created)
      |> json(%{data: category_to_json(category)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Goals.get_household_goal_category(user.household_id, id) do
      nil ->
        {:error, :not_found}
      category ->
        json(conn, %{data: category_to_json(category)})
    end
  end

  def update(conn, %{"id" => id, "category" => category_params}) do
    user = Guardian.Plug.current_resource(conn)

    with category when not is_nil(category) <- Goals.get_household_goal_category(user.household_id, id),
         {:ok, %GoalCategory{} = category} <- Goals.update_goal_category(category, category_params) do
      json(conn, %{data: category_to_json(category)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with category when not is_nil(category) <- Goals.get_household_goal_category(user.household_id, id),
         {:ok, %GoalCategory{}} <- Goals.delete_goal_category(category) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp category_to_json(category) do
    %{
      id: category.id,
      name: category.name,
      color: category.color,
      position: category.position,
      parent_id: category.parent_id,
      parent: if(Ecto.assoc_loaded?(category.parent) && category.parent, do: %{
        id: category.parent.id,
        name: category.parent.name,
        color: category.parent.color
      }, else: nil),
      subcategories: if(Ecto.assoc_loaded?(category.subcategories), do: Enum.map(category.subcategories, fn sub ->
        %{
          id: sub.id,
          name: sub.name,
          color: sub.color,
          position: sub.position
        }
      end), else: []),
      inserted_at: category.inserted_at,
      updated_at: category.updated_at
    }
  end
end

