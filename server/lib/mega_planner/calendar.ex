defmodule MegaPlanner.Calendar do
  @moduledoc """
  The Calendar context handles tasks, task steps, templates, and recurring items.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Calendar.{Task, TaskStep, TaskTemplate}

  # Tasks

  @doc """
  Returns the list of tasks for a household within a date range.
  """
  def list_tasks(household_id, opts \\ []) do
    query = from t in Task,
      where: t.household_id == ^household_id,
      order_by: [asc: t.date, asc: t.start_time, asc: t.priority],
      preload: [:steps, :tags]

    query
    |> filter_by_date_range(opts)
    |> filter_by_status(opts)
    |> Repo.all()
  end

  defp filter_by_date_range(query, opts) do
    case {Keyword.get(opts, :start_date), Keyword.get(opts, :end_date)} do
      {nil, nil} -> query
      {start_date, nil} -> from t in query, where: t.date >= ^start_date
      {nil, end_date} -> from t in query, where: t.date <= ^end_date
      {start_date, end_date} -> from t in query, where: t.date >= ^start_date and t.date <= ^end_date
    end
  end

  defp filter_by_status(query, opts) do
    case Keyword.get(opts, :status) do
      nil -> query
      status -> from t in query, where: t.status == ^status
    end
  end

  @doc """
  Gets a single task.
  """
  def get_task(id) do
    Task
    |> Repo.get(id)
    |> Repo.preload([:steps, :tags])
  end

  @doc """
  Gets a task for a specific household.
  """
  def get_household_task(household_id, id) do
    Task
    |> Repo.get_by(id: id, household_id: household_id)
    |> Repo.preload([:steps, :tags])
  end

  @doc """
  Creates a task.
  """
  def create_task(attrs \\ %{}) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, task} -> {:ok, Repo.preload(task, [:steps, :tags])}
      error -> error
    end
  end

  @doc """
  Updates a task.
  """
  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, task} -> {:ok, Repo.preload(task, [:steps, :tags], force: true)}
      error -> error
    end
  end

  @doc """
  Deletes a task.
  """
  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end

  @doc """
  Reorders tasks by updating their priorities.
  """
  def reorder_tasks(household_id, task_ids) do
    Enum.with_index(task_ids)
    |> Enum.each(fn {task_id, index} ->
      from(t in Task, where: t.id == ^task_id and t.household_id == ^household_id)
      |> Repo.update_all(set: [priority: index])
    end)

    :ok
  end

  # Task Steps

  @doc """
  Creates a task step.
  """
  def create_task_step(attrs \\ %{}) do
    %TaskStep{}
    |> TaskStep.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a task step.
  """
  def update_task_step(%TaskStep{} = step, attrs) do
    step
    |> TaskStep.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a task step.
  """
  def delete_task_step(%TaskStep{} = step) do
    Repo.delete(step)
  end

  @doc """
  Gets a task step.
  """
  def get_task_step(id) do
    Repo.get(TaskStep, id)
  end

  @doc """
  Gets a task step belonging to a specific task.
  """
  def get_task_step(task_id, step_id) do
    Repo.get_by(TaskStep, id: step_id, task_id: task_id)
  end

  @doc """
  Reorders task steps.
  """
  def reorder_task_steps(task_id, step_ids) do
    Enum.with_index(step_ids)
    |> Enum.each(fn {step_id, index} ->
      from(s in TaskStep, where: s.id == ^step_id and s.task_id == ^task_id)
      |> Repo.update_all(set: [position: index])
    end)

    :ok
  end

  # Task Templates

  @doc """
  Returns the list of task templates for a household.
  """
  def list_templates(household_id) do
    from(t in TaskTemplate,
      where: t.household_id == ^household_id,
      order_by: [asc: t.category, asc: t.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single template.
  """
  def get_template(id) do
    Repo.get(TaskTemplate, id)
  end

  @doc """
  Gets a template for a specific household.
  """
  def get_household_template(household_id, id) do
    Repo.get_by(TaskTemplate, id: id, household_id: household_id)
  end

  @doc """
  Creates a task template.
  """
  def create_template(attrs \\ %{}) do
    %TaskTemplate{}
    |> TaskTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a task template.
  """
  def update_template(%TaskTemplate{} = template, attrs) do
    template
    |> TaskTemplate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a task template.
  """
  def delete_template(%TaskTemplate{} = template) do
    Repo.delete(template)
  end

  @doc """
  Creates a task from a template.
  """
  def create_task_from_template(%TaskTemplate{} = template, date, attrs \\ %{}) do
    task_attrs = %{
      "user_id" => template.user_id,
      "household_id" => template.household_id,
      "title" => attrs["title"] || template.title,
      "description" => attrs["description"] || template.task_description,
      "date" => date,
      "start_time" => attrs["start_time"],
      "duration_minutes" => template.duration_minutes,
      "priority" => template.priority,
      "task_type" => template.task_type,
      "status" => "not_started"
    }

    with {:ok, task} <- create_task(task_attrs) do
      # Create steps from template
      template.default_steps
      |> Enum.with_index()
      |> Enum.each(fn {step_content, index} ->
        create_task_step(%{
          "task_id" => task.id,
          "content" => step_content,
          "position" => index
        })
      end)

      {:ok, Repo.preload(task, [:steps, :tags], force: true)}
    end
  end
end
