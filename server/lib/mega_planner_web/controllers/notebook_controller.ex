defmodule MegaPlannerWeb.NotebookController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Notes
  alias MegaPlanner.Notes.Notebook

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    notebooks = Notes.list_notebooks(user.household_id)
    json(conn, %{data: Enum.map(notebooks, &notebook_to_json/1)})
  end

  def create(conn, %{"notebook" => notebook_params}) do
    user = Guardian.Plug.current_resource(conn)
    notebook_params = notebook_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %Notebook{} = notebook} <- Notes.create_notebook(notebook_params) do
      conn
      |> put_status(:created)
      |> json(%{data: notebook_to_json(notebook)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Notes.get_household_notebook(user.household_id, id) do
      nil -> {:error, :not_found}
      notebook -> json(conn, %{data: notebook_to_json(notebook)})
    end
  end

  def update(conn, %{"id" => id, "notebook" => notebook_params}) do
    user = Guardian.Plug.current_resource(conn)

    with notebook when not is_nil(notebook) <- Notes.get_household_notebook(user.household_id, id),
         {:ok, %Notebook{} = notebook} <- Notes.update_notebook(notebook, notebook_params) do
      json(conn, %{data: notebook_to_json(notebook)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with notebook when not is_nil(notebook) <- Notes.get_household_notebook(user.household_id, id),
         {:ok, %Notebook{}} <- Notes.delete_notebook(notebook) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp notebook_to_json(notebook) do
    %{
      id: notebook.id,
      name: notebook.name,
      inserted_at: notebook.inserted_at,
      updated_at: notebook.updated_at
    }
  end
end
