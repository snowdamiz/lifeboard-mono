defmodule MegaPlannerWeb.TagController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Tags
  alias MegaPlanner.Tags.Tag

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    # Check if usage stats are requested
    if params["with_usage"] == "true" do
      tags = Tags.get_tags_with_usage(user.household_id)
      json(conn, %{data: tags})
    else
      tags = Tags.list_tags(user.household_id)
      json(conn, %{data: Enum.map(tags, &tag_to_json/1)})
    end
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

  @doc """
  Get all items tagged with a specific tag.
  GET /tags/:tag_id/items
  """
  def items(conn, %{"tag_id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Tags.get_tag_with_items(user.household_id, id) do
      nil ->
        {:error, :not_found}
      tag ->
        json(conn, %{
          data: %{
            tag: tag_to_json(tag),
            items: %{
              tasks: Enum.map(tag.tasks, &task_to_json/1),
              goals: Enum.map(tag.goals, &goal_to_json/1),
              pages: Enum.map(tag.pages, &page_to_json/1),
              habits: Enum.map(tag.habits, &habit_to_json/1),
              inventory_items: Enum.map(tag.inventory_items, &inventory_item_to_json/1),
              budget_sources: Enum.map(tag.budget_sources, &budget_source_to_json/1)
            }
          }
        })
    end
  end

  @doc """
  Search for items by multiple tags.
  GET /tags/search?tag_ids=id1,id2&mode=any|all
  """
  def search(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    tag_ids = case params["tag_ids"] do
      nil -> []
      ids when is_binary(ids) -> String.split(ids, ",")
      ids when is_list(ids) -> ids
    end

    mode = case params["mode"] do
      "all" -> :all
      _ -> :any
    end

    if length(tag_ids) == 0 do
      json(conn, %{data: %{tasks: [], goals: [], pages: [], habits: [], inventory_items: [], budget_sources: []}})
    else
      items = Tags.search_by_tags(user.household_id, tag_ids, mode: mode)

      json(conn, %{
        data: %{
          tasks: Enum.map(items.tasks, &task_to_json/1),
          goals: Enum.map(items.goals, &goal_to_json/1),
          pages: Enum.map(items.pages, &page_to_json/1),
          habits: Enum.map(items.habits, &habit_to_json/1),
          inventory_items: Enum.map(items.inventory_items, &inventory_item_to_json/1),
          budget_sources: Enum.map(items.budget_sources, &budget_source_to_json/1)
        }
      })
    end
  end

  @doc """
  Create tasks from tagged items (one-click todo list creation).
  POST /tags/create-tasks
  """
  def create_tasks(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    tag_ids = case params["tag_ids"] do
      nil -> []
      ids when is_binary(ids) -> String.split(ids, ",")
      ids when is_list(ids) -> ids
    end

    include_types = case params["include_types"] do
      nil -> [:goals, :habits]
      types when is_list(types) -> Enum.map(types, &String.to_existing_atom/1)
      types when is_binary(types) -> String.split(types, ",") |> Enum.map(&String.to_existing_atom/1)
    end

    date = case params["date"] do
      nil -> Date.utc_today()
      date_str -> Date.from_iso8601!(date_str)
    end

    if length(tag_ids) == 0 do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "tag_ids is required"})
    else
      {:ok, tasks} = Tags.create_tasks_from_tags(
        user.household_id,
        user.id,
        tag_ids,
        include_types: include_types,
        date: date
      )

      conn
      |> put_status(:created)
      |> json(%{data: Enum.map(tasks, &task_to_json/1)})
    end
  end

  # JSON serializers

  defp tag_to_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color,
      inserted_at: tag.inserted_at,
      updated_at: tag.updated_at
    }
  end

  defp task_to_json(task) do
    %{
      id: task.id,
      title: task.title,
      description: task.description,
      date: task.date,
      status: task.status,
      task_type: task.task_type
    }
  end

  defp goal_to_json(goal) do
    %{
      id: goal.id,
      title: goal.title,
      description: goal.description,
      status: goal.status,
      progress: goal.progress
    }
  end

  defp page_to_json(page) do
    %{
      id: page.id,
      title: page.title,
      content: String.slice(page.content || "", 0, 100)
    }
  end

  defp habit_to_json(habit) do
    %{
      id: habit.id,
      name: habit.name,
      description: habit.description,
      frequency: habit.frequency,
      streak_count: habit.streak_count
    }
  end

  defp inventory_item_to_json(item) do
    %{
      id: item.id,
      name: item.name,
      quantity: decimal_to_string(item.quantity)
    }
  end

  defp decimal_to_string(%Decimal{} = d), do: Decimal.to_string(d)
  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(val), do: to_string(val)

  defp budget_source_to_json(source) do
    %{
      id: source.id,
      name: source.name,
      type: source.type,
      amount: source.amount
    }
  end
end
