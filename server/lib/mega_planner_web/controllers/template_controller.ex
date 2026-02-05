defmodule MegaPlannerWeb.TemplateController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Templates

  action_fallback MegaPlannerWeb.FallbackController

  def suggest(conn, %{"query" => query} = params) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
      user ->
        field_type = Map.get(params, "field_type", "title")
        templates = Templates.suggest_templates(user.household_id, field_type, query)
        json(conn, %{data: Enum.map(templates, &template_to_json/1)})
    end
  end

  defp template_to_json(value) when is_binary(value), do: %{value: value}
  defp template_to_json(%{value: value}), do: %{value: value}

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
