defmodule MegaPlannerWeb.TaskStepController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Calendar
  alias MegaPlanner.Calendar.TaskStep

  action_fallback MegaPlannerWeb.FallbackController

  def create(conn, %{"task_id" => task_id, "step" => step_params}) do
    user = Guardian.Plug.current_resource(conn)

    with task when not is_nil(task) <- Calendar.get_household_task(user.household_id, task_id),
         step_params <- Map.put(step_params, "task_id", task.id),
         {:ok, %TaskStep{} = step} <- Calendar.create_task_step(step_params) do
      conn
      |> put_status(:created)
      |> json(%{data: step_to_json(step)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def update(conn, %{"task_id" => task_id, "step_id" => step_id, "step" => step_params}) do
    user = Guardian.Plug.current_resource(conn)

    with task when not is_nil(task) <- Calendar.get_household_task(user.household_id, task_id),
         step when not is_nil(step) <- Calendar.get_task_step(task.id, step_id),
         {:ok, %TaskStep{} = step} <- Calendar.update_task_step(step, step_params) do
      json(conn, %{data: step_to_json(step)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"task_id" => task_id, "step_id" => step_id}) do
    user = Guardian.Plug.current_resource(conn)

    with task when not is_nil(task) <- Calendar.get_household_task(user.household_id, task_id),
         step when not is_nil(step) <- Calendar.get_task_step(task.id, step_id),
         {:ok, %TaskStep{}} <- Calendar.delete_task_step(step) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp step_to_json(step) do
    %{
      id: step.id,
      content: step.content,
      completed: step.completed,
      position: step.position
    }
  end
end
