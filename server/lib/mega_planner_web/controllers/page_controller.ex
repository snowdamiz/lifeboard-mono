defmodule MegaPlannerWeb.PageController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Notes
  alias MegaPlanner.Notes.Page

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, %{"notebook_id" => notebook_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    opts = case params["tag_ids"] do
      nil -> []
      "" -> []
      tag_ids when is_binary(tag_ids) -> [tag_ids: String.split(tag_ids, ",")]
      tag_ids when is_list(tag_ids) -> [tag_ids: tag_ids]
    end

    with notebook when not is_nil(notebook) <- Notes.get_household_notebook(user.household_id, notebook_id) do
      pages = Notes.list_pages(notebook.id, opts)
      json(conn, %{data: Enum.map(pages, &page_to_json/1)})
    else
      nil -> {:error, :not_found}
    end
  end

  def create(conn, %{"notebook_id" => notebook_id, "page" => page_params}) do
    user = Guardian.Plug.current_resource(conn)

    with notebook when not is_nil(notebook) <- Notes.get_household_notebook(user.household_id, notebook_id),
         page_params <- page_params |> Map.put("notebook_id", notebook.id) |> Map.put("user_id", user.id),
         {:ok, %Page{} = page} <- Notes.create_page(page_params) do
      conn
      |> put_status(:created)
      |> json(%{data: page_to_json(page)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Notes.get_household_page(user.household_id, id) do
      nil -> {:error, :not_found}
      page -> json(conn, %{data: page_to_json(page)})
    end
  end

  def update(conn, %{"id" => id, "page" => page_params}) do
    user = Guardian.Plug.current_resource(conn)

    with page when not is_nil(page) <- Notes.get_household_page(user.household_id, id),
         {:ok, %Page{} = page} <- Notes.update_page(page, page_params) do
      json(conn, %{data: page_to_json(page)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with page when not is_nil(page) <- Notes.get_household_page(user.household_id, id),
         {:ok, %Page{}} <- Notes.delete_page(page) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp page_to_json(page) do
    %{
      id: page.id,
      title: page.title,
      content: page.content,
      notebook_id: page.notebook_id,
      links: Enum.map(page.links || [], &link_to_json/1),
      tags: Enum.map(page.tags || [], &tag_to_json/1),
      inserted_at: page.inserted_at,
      updated_at: page.updated_at
    }
  end

  defp link_to_json(link) do
    %{
      id: link.id,
      link_type: link.link_type,
      linked_id: link.linked_id
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
