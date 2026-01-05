defmodule MegaPlannerWeb.TemplateController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Calendar
  alias MegaPlanner.Calendar.TaskTemplate

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    templates = Calendar.list_templates(user.household_id)
    json(conn, %{data: Enum.map(templates, &template_to_json/1)})
  end

  def create(conn, %{"template" => template_params}) do
    user = Guardian.Plug.current_resource(conn)
    template_params = template_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %TaskTemplate{} = template} <- Calendar.create_template(template_params) do
      conn
      |> put_status(:created)
      |> json(%{data: template_to_json(template)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Calendar.get_household_template(user.household_id, id) do
      nil -> {:error, :not_found}
      template -> json(conn, %{data: template_to_json(template)})
    end
  end

  def update(conn, %{"id" => id, "template" => template_params}) do
    user = Guardian.Plug.current_resource(conn)

    with template when not is_nil(template) <- Calendar.get_household_template(user.household_id, id),
         {:ok, %TaskTemplate{} = template} <- Calendar.update_template(template, template_params) do
      json(conn, %{data: template_to_json(template)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with template when not is_nil(template) <- Calendar.get_household_template(user.household_id, id),
         {:ok, %TaskTemplate{}} <- Calendar.delete_template(template) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Create a task from a template.
  """
  def apply(conn, %{"template_id" => template_id, "date" => date} = params) do
    user = Guardian.Plug.current_resource(conn)

    with template when not is_nil(template) <- Calendar.get_household_template(user.household_id, template_id),
         {:ok, task} <- Calendar.create_task_from_template(template, date, params) do
      conn
      |> put_status(:created)
      |> json(%{data: task_to_json(task)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp template_to_json(template) do
    %{
      id: template.id,
      name: template.name,
      description: template.description,
      category: template.category,
      title: template.title,
      task_description: template.task_description,
      duration_minutes: template.duration_minutes,
      priority: template.priority,
      task_type: template.task_type,
      default_steps: template.default_steps,
      inserted_at: template.inserted_at,
      updated_at: template.updated_at
    }
  end

  defp task_to_json(task) do
    %{
      id: task.id,
      title: task.title,
      description: task.description,
      date: task.date,
      start_time: task.start_time,
      duration_minutes: task.duration_minutes,
      priority: task.priority,
      status: task.status,
      is_recurring: task.is_recurring,
      recurrence_rule: task.recurrence_rule,
      task_type: task.task_type,
      parent_task_id: task.parent_task_id,
      steps: Enum.map(task.steps || [], fn step ->
        %{
          id: step.id,
          content: step.content,
          completed: step.completed,
          position: step.position
        }
      end),
      tags: Enum.map(task.tags || [], fn tag ->
        %{id: tag.id, name: tag.name, color: tag.color}
      end),
      inserted_at: task.inserted_at,
      updated_at: task.updated_at
    }
  end
end
