defmodule MegaPlannerWeb.GoalController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Goals
  alias MegaPlanner.Goals.Goal

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    opts = []
    opts = if status = params["status"], do: Keyword.put(opts, :status, status), else: opts
    opts = if category_id = params["category_id"], do: Keyword.put(opts, :category_id, category_id), else: opts
    opts = if tag_ids = params["tag_ids"], do: Keyword.put(opts, :tag_ids, String.split(tag_ids, ",")), else: opts

    goals = Goals.list_goals(user.household_id, opts)
    json(conn, %{data: Enum.map(goals, &goal_to_json/1)})
  end

  def create(conn, %{"goal" => goal_params}) do
    user = Guardian.Plug.current_resource(conn)
    goal_params = goal_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %Goal{} = goal} <- Goals.create_goal(goal_params) do
      conn
      |> put_status(:created)
      |> json(%{data: goal_to_json(goal)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Goals.get_household_goal(user.household_id, id) do
      nil -> {:error, :not_found}
      goal -> json(conn, %{data: goal_to_json(goal)})
    end
  end

  def update(conn, %{"id" => id, "goal" => goal_params}) do
    user = Guardian.Plug.current_resource(conn)

    with goal when not is_nil(goal) <- Goals.get_household_goal(user.household_id, id),
         {:ok, %Goal{} = goal} <- Goals.update_goal(goal, goal_params, user_id: user.id) do
      json(conn, %{data: goal_to_json(goal)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def history(conn, %{"goal_id" => goal_id}) do
    user = Guardian.Plug.current_resource(conn)

    with goal when not is_nil(goal) <- Goals.get_household_goal(user.household_id, goal_id) do
      history = Goals.get_goal_full_history(goal.id)
      json(conn, %{data: Enum.map(history, &history_item_to_json/1)})
    else
      nil -> {:error, :not_found}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with goal when not is_nil(goal) <- Goals.get_household_goal(user.household_id, id),
         {:ok, %Goal{}} <- Goals.delete_goal(goal) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  # Milestone actions

  def create_milestone(conn, %{"goal_id" => goal_id, "milestone" => milestone_params}) do
    user = Guardian.Plug.current_resource(conn)

    with goal when not is_nil(goal) <- Goals.get_household_goal(user.household_id, goal_id),
         {:ok, milestone} <- Goals.create_milestone(goal.id, milestone_params) do
      conn
      |> put_status(:created)
      |> json(%{data: milestone_to_json(milestone)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def update_milestone(conn, %{"goal_id" => goal_id, "milestone_id" => milestone_id, "milestone" => milestone_params}) do
    user = Guardian.Plug.current_resource(conn)

    with goal when not is_nil(goal) <- Goals.get_household_goal(user.household_id, goal_id),
         milestone when not is_nil(milestone) <- Goals.get_goal_milestone(goal.id, milestone_id),
         {:ok, milestone} <- Goals.update_milestone(milestone, milestone_params) do
      json(conn, %{data: milestone_to_json(milestone)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def toggle_milestone(conn, %{"goal_id" => goal_id, "milestone_id" => milestone_id}) do
    user = Guardian.Plug.current_resource(conn)

    with goal when not is_nil(goal) <- Goals.get_household_goal(user.household_id, goal_id),
         milestone when not is_nil(milestone) <- Goals.get_goal_milestone(goal.id, milestone_id),
         {:ok, milestone} <- Goals.toggle_milestone(milestone) do
      json(conn, %{data: milestone_to_json(milestone)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete_milestone(conn, %{"goal_id" => goal_id, "milestone_id" => milestone_id}) do
    user = Guardian.Plug.current_resource(conn)

    with goal when not is_nil(goal) <- Goals.get_household_goal(user.household_id, goal_id),
         milestone when not is_nil(milestone) <- Goals.get_goal_milestone(goal.id, milestone_id),
         {:ok, _} <- Goals.delete_milestone(milestone) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def update_tags(conn, %{"goal_id" => goal_id, "tag_ids" => tag_ids}) do
    user = Guardian.Plug.current_resource(conn)

    with goal when not is_nil(goal) <- Goals.get_household_goal(user.household_id, goal_id),
         {:ok, goal} <- Goals.update_goal_tags(goal, tag_ids) do
      json(conn, %{data: goal_to_json(goal)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp goal_to_json(goal) do
    %{
      id: goal.id,
      title: goal.title,
      description: goal.description,
      target_date: goal.target_date,
      status: goal.status,
      category: goal.category,
      goal_category_id: goal.goal_category_id,
      goal_category: if(Ecto.assoc_loaded?(goal.goal_category) && goal.goal_category, do: %{
        id: goal.goal_category.id,
        name: goal.goal_category.name,
        color: goal.goal_category.color,
        parent: if(Ecto.assoc_loaded?(goal.goal_category.parent) && goal.goal_category.parent, do: %{
          id: goal.goal_category.parent.id,
          name: goal.goal_category.parent.name,
          color: goal.goal_category.parent.color
        }, else: nil)
      }, else: nil),
      progress: goal.progress,
      milestones: Enum.map(goal.milestones || [], &milestone_to_json/1),
      tags: if(Ecto.assoc_loaded?(goal.tags), do: Enum.map(goal.tags, &tag_to_json/1), else: []),
      linked_tasks: goal.linked_task_ids || [],
      inserted_at: goal.inserted_at,
      updated_at: goal.updated_at
    }
  end

  defp tag_to_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color
    }
  end

  defp milestone_to_json(milestone) do
    %{
      id: milestone.id,
      title: milestone.title,
      completed: milestone.completed,
      completed_at: milestone.completed_at,
      position: milestone.position
    }
  end

  defp history_item_to_json(%{type: "status_change"} = item) do
    %{
      type: "status_change",
      id: item.id,
      from_status: item.from_status,
      to_status: item.to_status,
      notes: item.notes,
      user: if(item[:user], do: %{id: item.user.id, name: item.user.name}, else: nil),
      timestamp: item.timestamp
    }
  end

  defp history_item_to_json(%{type: "milestone_completed"} = item) do
    %{
      type: "milestone_completed",
      id: item.id,
      title: item.title,
      timestamp: item.timestamp
    }
  end
end
