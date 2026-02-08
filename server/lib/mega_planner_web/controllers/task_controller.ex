defmodule MegaPlannerWeb.TaskController do
  use MegaPlannerWeb, :controller
  require Logger

  alias MegaPlanner.Calendar
  alias MegaPlanner.Calendar.Task

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    Logger.debug("[TASK_CTRL] INDEX params=#{inspect(params)}")

    opts = []
    |> maybe_add_date(:start_date, params["start_date"])
    |> maybe_add_date(:end_date, params["end_date"])
    |> maybe_add_status(params["status"])
    |> maybe_add_tag_ids(params["tag_ids"])

    tasks = Calendar.list_tasks(user.household_id, opts)
    trip_tasks = Enum.filter(tasks, & &1.trip_id)
    Logger.debug("[TASK_CTRL] INDEX returning #{length(tasks)} tasks, #{length(trip_tasks)} with trip_id")
    json(conn, %{data: Enum.map(tasks, &task_to_json/1)})
  end

  def create(conn, %{"task" => task_params}) do
    user = Guardian.Plug.current_resource(conn)
    Logger.debug("[TASK_CTRL] CREATE raw params=#{inspect(task_params)}")
    task_params = task_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    Logger.debug("[TASK_CTRL] CREATE full params=#{inspect(task_params)}")
    case Calendar.create_task(task_params) do
      {:ok, %Task{} = task} ->
        Logger.debug("[TASK_CTRL] CREATE success id=#{task.id}")
        conn
        |> put_status(:created)
        |> json(%{data: task_to_json(task)})
      {:error, changeset} ->
        Logger.error("[TASK_CTRL] CREATE FAILED changeset=#{inspect(changeset)}")
        {:error, changeset}
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Calendar.get_household_task(user.household_id, id) do
      nil -> {:error, :not_found}
      task -> json(conn, %{data: task_to_json(task)})
    end
  end

  def update(conn, %{"id" => id, "task" => task_params}) do
    user = Guardian.Plug.current_resource(conn)

    with task when not is_nil(task) <- Calendar.get_household_task(user.household_id, id),
         {:ok, %Task{} = task} <- Calendar.update_task(task, task_params) do
      json(conn, %{data: task_to_json(task)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with task when not is_nil(task) <- Calendar.get_household_task(user.household_id, id),
         {:ok, %Task{}} <- Calendar.delete_task(task) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def reorder(conn, %{"task_id" => task_id, "task_ids" => task_ids}) do
    user = Guardian.Plug.current_resource(conn)

    # Verify the main task belongs to household
    case Calendar.get_household_task(user.household_id, task_id) do
      nil ->
        {:error, :not_found}
      _task ->
        Calendar.reorder_tasks(user.household_id, task_ids)
        json(conn, %{message: "Tasks reordered"})
    end
  end

  defp maybe_add_date(opts, key, value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> Keyword.put(opts, key, date)
      _ -> opts
    end
  end
  defp maybe_add_date(opts, _key, _value), do: opts

  defp maybe_add_status(opts, value) when is_binary(value) and value != "" do
    statuses = String.split(value, ",")
    Keyword.put(opts, :status, statuses)
  end
  defp maybe_add_status(opts, _value), do: opts

  defp maybe_add_tag_ids(opts, value) when is_binary(value) and value != "" do
    tag_ids = String.split(value, ",")
    Keyword.put(opts, :tag_ids, tag_ids)
  end
  defp maybe_add_tag_ids(opts, _value), do: opts

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
      trip_id: task.trip_id,
      steps: Enum.map(task.steps || [], &step_to_json/1),
      tags: Enum.map(task.tags || [], &tag_to_json/1),
      inserted_at: task.inserted_at,
      updated_at: task.updated_at
    }
  end

  defp step_to_json(step) do
    %{
      id: step.id,
      content: step.content,
      completed: step.completed,
      position: step.position
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
