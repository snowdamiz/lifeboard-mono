defmodule MegaPlannerWeb.TagController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Tags
  alias MegaPlanner.Tags.Tag

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    tags = Tags.list_tags(user.household_id)
    json(conn, %{data: Enum.map(tags, &tag_to_json/1)})
  end

  def create(conn, %{"tag" => tag_params}) do
    user = Guardian.Plug.current_resource(conn)
    tag_params = tag_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %Tag{} = tag} <- Tags.create_tag(tag_params) do
      conn
      |> put_status(:created)
      |> json(%{data: tag_to_json(tag)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Tags.get_household_tag(user.household_id, id) do
      nil -> {:error, :not_found}
      tag -> json(conn, %{data: tag_to_json(tag)})
    end
  end

  def update(conn, %{"id" => id, "tag" => tag_params}) do
    user = Guardian.Plug.current_resource(conn)

    with tag when not is_nil(tag) <- Tags.get_household_tag(user.household_id, id),
         {:ok, %Tag{} = tag} <- Tags.update_tag(tag, tag_params) do
      json(conn, %{data: tag_to_json(tag)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with tag when not is_nil(tag) <- Tags.get_household_tag(user.household_id, id),
         {:ok, %Tag{}} <- Tags.delete_tag(tag) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp tag_to_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color,
      inserted_at: tag.inserted_at,
      updated_at: tag.updated_at
    }
  end
end
