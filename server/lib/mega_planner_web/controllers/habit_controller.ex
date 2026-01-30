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

    # Get viewing date (defaults to today)
    viewing_date = case params["date"] do
      nil -> Date.utc_today()
      "" -> Date.utc_today()
      date_str ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> date
          {:error, _} -> Date.utc_today()
        end
    end

    habits_with_status = Enum.map(habits, fn habit ->
      completed_today = Goals.habit_completed_on?(habit.id, viewing_date)
      habit_to_json(habit, completed_today)
    end)

    json(conn, %{data: habits_with_status})
  end

  def create(conn, %{"habit" => habit_params}) do
    user = Guardian.Plug.current_resource(conn)
    habit_params = habit_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    case Goals.create_habit(habit_params) do
      {:ok, %Habit{} = habit} ->
        conn
        |> put_status(:created)
        |> json(%{data: habit_to_json(habit, false)})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset.errors})
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

  def complete(conn, %{"habit_id" => habit_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    # Parse optional date parameter
    date = case params["date"] do
      nil -> nil
      "" -> nil
      date_str ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> date
          {:error, _} -> nil
        end
    end

    with habit when not is_nil(habit) <- Goals.get_household_habit(user.household_id, habit_id),
         {:ok, {completion, updated_habit}} <- Goals.complete_habit(habit, date) do
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
        |> json(%{error: "Habit already completed for this date"})
      error -> error
    end
  end

  def uncomplete(conn, %{"habit_id" => habit_id} = params) do
    user = Guardian.Plug.current_resource(conn)

    # Parse optional date parameter
    date = case params["date"] do
      nil -> nil
      "" -> nil
      date_str ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> date
          {:error, _} -> nil
        end
    end

    with habit when not is_nil(habit) <- Goals.get_household_habit(user.household_id, habit_id),
         {:ok, updated_habit} <- Goals.uncomplete_habit(habit, date) do
      json(conn, %{data: habit_to_json(updated_habit, false)})
    else
      nil -> {:error, :not_found}
      {:error, :not_completed} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Habit not completed for this date"})
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

  def skip(conn, %{"habit_id" => habit_id, "reason" => reason} = params) do
    user = Guardian.Plug.current_resource(conn)

    # Parse optional date parameter
    date = case params["date"] do
      nil -> nil
      "" -> nil
      date_str ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> date
          {:error, _} -> nil
        end
    end

    with habit when not is_nil(habit) <- Goals.get_household_habit(user.household_id, habit_id),
         {:ok, {completion, habit}} <- Goals.skip_habit(habit, reason, date) do
      json(conn, %{
        data: %{
          completion: completion_to_json(completion),
          habit: habit_to_json(habit, false)
        }
      })
    else
      nil -> {:error, :not_found}
      {:error, :already_has_entry} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Habit already has an entry for this date"})
      error -> error
    end
  end

  def analytics(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    # Parse date range with error handling
    end_date = Date.utc_today()
    
    start_date = case params["start_date"] do
      nil -> Date.add(end_date, -90)
      "" -> Date.add(end_date, -90)
      date_str ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> date
          {:error, _} -> Date.add(end_date, -90)
        end
    end

    end_date = case params["end_date"] do
      nil -> end_date
      "" -> end_date
      date_str ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> date
          {:error, _} -> end_date
        end
    end

    habit_id = params["habit_id"]
    inventory_id = case params["inventory_id"] do
      "" -> nil
      val -> val
    end

    # Parse tag_ids if provided
    tag_ids = case params["tag_ids"] do
      nil -> nil
      "" -> nil
      tag_ids when is_binary(tag_ids) -> String.split(tag_ids, ",")
      tag_ids when is_list(tag_ids) -> tag_ids
    end

    # Parse status_filter if provided
    status_filter = case params["status_filter"] do
      nil -> nil
      "" -> nil
      val -> val
    end

    analytics = Goals.get_habit_analytics(user.household_id, start_date, end_date, habit_id, inventory_id, tag_ids, status_filter)
    json(conn, %{data: analytics})
  end

  defp habit_to_json(habit, completed_today) do
    # Format time to HH:MM for HTML time inputs (remove seconds)
    scheduled_time = case habit.scheduled_time do
      nil -> nil
      time -> Time.to_string(time) |> String.slice(0, 5)  # "14:30:00" -> "14:30"
    end

    %{
      id: habit.id,
      name: habit.name,
      description: habit.description,
      frequency: habit.frequency,
      days_of_week: habit.days_of_week,
      reminder_time: habit.reminder_time,
      scheduled_time: scheduled_time,
      duration_minutes: habit.duration_minutes,
      color: habit.color,
      is_start_of_day: habit.is_start_of_day,
      inventory_id: habit.inventory_id,
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
      completed_at: completion.completed_at,
      status: completion.status,
      not_today_reason: completion.not_today_reason
    }
  end
end
