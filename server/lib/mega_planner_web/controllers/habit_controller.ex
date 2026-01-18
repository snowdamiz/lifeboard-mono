defmodule MegaPlannerWeb.HabitController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Goals
  alias MegaPlanner.Goals.Habit

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    opts = []
    opts = case params["tag_ids"] do
      nil -> opts
      "" -> opts
      tag_ids when is_binary(tag_ids) -> Keyword.put(opts, :tag_ids, String.split(tag_ids, ","))
      tag_ids when is_list(tag_ids) -> Keyword.put(opts, :tag_ids, tag_ids)
    end

    habits = Goals.list_habits(user.household_id, opts)

    # Get today's completions
    today = Date.utc_today()

    habits_with_status = Enum.map(habits, fn habit ->
      completed_today = Goals.habit_completed_on?(habit.id, today)
      habit_to_json(habit, completed_today)
    end)

    json(conn, %{data: habits_with_status})
  end

  def create(conn, %{"habit" => habit_params}) do
    user = Guardian.Plug.current_resource(conn)
    habit_params = habit_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %Habit{} = habit} <- Goals.create_habit(habit_params) do
      conn
      |> put_status(:created)
      |> json(%{data: habit_to_json(habit, false)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Goals.get_household_habit(user.household_id, id) do
      nil ->
        {:error, :not_found}
      habit ->
        today = Date.utc_today()
        completed_today = Goals.habit_completed_on?(habit.id, today)
        json(conn, %{data: habit_to_json(habit, completed_today)})
    end
  end

  def update(conn, %{"id" => id, "habit" => habit_params}) do
    user = Guardian.Plug.current_resource(conn)

    with habit when not is_nil(habit) <- Goals.get_household_habit(user.household_id, id),
         {:ok, %Habit{} = habit} <- Goals.update_habit(habit, habit_params) do
      today = Date.utc_today()
      completed_today = Goals.habit_completed_on?(habit.id, today)
      json(conn, %{data: habit_to_json(habit, completed_today)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with habit when not is_nil(habit) <- Goals.get_household_habit(user.household_id, id),
         {:ok, %Habit{}} <- Goals.delete_habit(habit) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def complete(conn, %{"habit_id" => habit_id}) do
    user = Guardian.Plug.current_resource(conn)

    with habit when not is_nil(habit) <- Goals.get_household_habit(user.household_id, habit_id),
         {:ok, {completion, updated_habit}} <- Goals.complete_habit(habit) do
      json(conn, %{
        data: %{
          completion: completion_to_json(completion),
          habit: habit_to_json(updated_habit, true)
        }
      })
    else
      nil -> {:error, :not_found}
      {:error, :already_completed} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Habit already completed today"})
      error -> error
    end
  end

  def uncomplete(conn, %{"habit_id" => habit_id}) do
    user = Guardian.Plug.current_resource(conn)

    with habit when not is_nil(habit) <- Goals.get_household_habit(user.household_id, habit_id),
         {:ok, updated_habit} <- Goals.uncomplete_habit(habit) do
      json(conn, %{data: habit_to_json(updated_habit, false)})
    else
      nil -> {:error, :not_found}
      {:error, :not_completed} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Habit not completed today"})
      error -> error
    end
  end

  def completions(conn, %{"habit_id" => habit_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with habit when not is_nil(habit) <- Goals.get_household_habit(user.household_id, habit_id) do
      # Default to last 90 days
      end_date = Date.utc_today()
      start_date =
        case params["start_date"] do
          nil -> Date.add(end_date, -90)
          date_str -> Date.from_iso8601!(date_str)
        end

      end_date =
        case params["end_date"] do
          nil -> end_date
          date_str -> Date.from_iso8601!(date_str)
        end

      completions = Goals.get_habit_completions(habit.id, start_date, end_date)
      json(conn, %{data: Enum.map(completions, &completion_to_json/1)})
    else
      nil -> {:error, :not_found}
    end
  end

  defp habit_to_json(habit, completed_today) do
    %{
      id: habit.id,
      name: habit.name,
      description: habit.description,
      frequency: habit.frequency,
      days_of_week: habit.days_of_week,
      reminder_time: habit.reminder_time,
      color: habit.color,
      streak_count: habit.streak_count,
      longest_streak: habit.longest_streak,
      completed_today: completed_today,
      tags: Enum.map(habit.tags || [], &tag_to_json/1),
      inserted_at: habit.inserted_at,
      updated_at: habit.updated_at
    }
  end

  defp tag_to_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color
    }
  end

  defp completion_to_json(completion) do
    %{
      id: completion.id,
      habit_id: completion.habit_id,
      date: completion.date,
      completed_at: completion.completed_at
    }
  end
end
