defmodule MegaPlannerWeb.TemplateController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Templates

  action_fallback MegaPlannerWeb.FallbackController

  def suggest(conn, %{"type" => type, "query" => query}) do
    try do
      user = Guardian.Plug.current_resource(conn)
      
      if is_nil(user) or is_nil(user.household_id) do
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "User not authenticated or household not set"})
      else
        templates = Templates.suggest_templates(user.household_id, type, query)
        json(conn, %{data: templates})
      end
    rescue
      e ->
        IO.inspect(e, label: "Template Suggest Error")
        IO.inspect(__STACKTRACE__, label: "Stacktrace")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: Map.get(e, :message, inspect(e))})
    end
  end

  def create_text_template(conn, %{"type" => type, "value" => value}) do
    user = Guardian.Plug.current_resource(conn)
    
    {:ok, _template} = Templates.create_template(%{
      "field_type" => type,
      "value" => value,
      "household_id" => user.household_id
    })
    
    send_resp(conn, :no_content, "")
  end

  def delete_text_template(conn, %{"type" => type, "value" => value}) do
    user = Guardian.Plug.current_resource(conn)
    
    Templates.delete_template(user.household_id, type, value)
    
    send_resp(conn, :no_content, "")
  end
end
