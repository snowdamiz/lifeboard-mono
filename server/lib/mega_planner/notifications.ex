defmodule MegaPlanner.Notifications do
  @moduledoc """
  The Notifications context handles in-app notifications and user preferences.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Notifications.{Notification, Preferences}

  # ============================================================================
  # Notifications
  # ============================================================================

  @doc """
  Returns the list of notifications for a user.
  """
  def list_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    unread_only = Keyword.get(opts, :unread_only, false)

    query =
      from n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit

    query =
      if unread_only do
        from n in query, where: n.read == false
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets a single notification.
  """
  def get_notification(id, user_id) do
    Repo.get_by(Notification, id: id, user_id: user_id)
  end

  @doc """
  Creates a notification.
  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a notification for a user.
  """
  def create_notification_for_user(user_id, household_id, type, title, opts \\ []) do
    attrs = %{
      user_id: user_id,
      household_id: household_id,
      type: type,
      title: title,
      message: Keyword.get(opts, :message),
      data: Keyword.get(opts, :data, %{}),
      link_type: Keyword.get(opts, :link_type),
      link_id: Keyword.get(opts, :link_id)
    }

    create_notification(attrs)
  end

  @doc """
  Marks a notification as read.
  """
  def mark_as_read(%Notification{} = notification) do
    notification
    |> Notification.mark_read_changeset()
    |> Repo.update()
  end

  @doc """
  Marks all notifications as read for a user.
  """
  def mark_all_as_read(user_id) do
    now = DateTime.utc_now()

    from(n in Notification,
      where: n.user_id == ^user_id and n.read == false
    )
    |> Repo.update_all(set: [read: true, read_at: now])
  end

  @doc """
  Deletes a notification.
  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Gets unread notification count for a user.
  """
  def unread_count(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and n.read == false,
      select: count(n.id)
    )
    |> Repo.one()
  end

  @doc """
  Deletes old read notifications (older than 30 days).
  """
  def cleanup_old_notifications do
    cutoff = DateTime.add(DateTime.utc_now(), -30, :day)

    from(n in Notification,
      where: n.read == true and n.inserted_at < ^cutoff
    )
    |> Repo.delete_all()
  end

  # ============================================================================
  # Preferences
  # ============================================================================

  @doc """
  Gets notification preferences for a user, creating defaults if they don't exist.
  """
  def get_or_create_preferences(user_id, household_id) do
    case Repo.get_by(Preferences, user_id: user_id) do
      nil ->
        %Preferences{}
        |> Preferences.changeset(%{user_id: user_id, household_id: household_id})
        |> Repo.insert()

      preferences ->
        {:ok, preferences}
    end
  end

  @doc """
  Gets notification preferences for a user.
  """
  def get_preferences(user_id) do
    Repo.get_by(Preferences, user_id: user_id)
  end

  @doc """
  Updates notification preferences.
  """
  def update_preferences(%Preferences{} = preferences, attrs) do
    preferences
    |> Preferences.changeset(attrs)
    |> Repo.update()
  end

  # ============================================================================
  # Notification Triggers (to be called from other contexts)
  # ============================================================================

  @doc """
  Creates a task due notification.
  """
  def notify_task_due(user_id, household_id, task) do
    create_notification_for_user(
      user_id,
      household_id,
      "task_due",
      "Task due soon: #{task.title}",
      message: "Your task is due #{format_due_time(task.date, task.start_time)}",
      link_type: "task",
      link_id: task.id,
      data: %{task_id: task.id}
    )
  end

  @doc """
  Creates a low inventory notification.
  """
  def notify_low_inventory(user_id, household_id, item) do
    create_notification_for_user(
      user_id,
      household_id,
      "low_inventory",
      "Low stock: #{item.name}",
      message: "#{item.name} is running low (#{item.quantity} left, min: #{item.min_quantity})",
      link_type: "inventory_item",
      link_id: item.id,
      data: %{item_id: item.id, quantity: item.quantity, min_quantity: item.min_quantity}
    )
  end

  @doc """
  Creates a budget warning notification.
  """
  def notify_budget_warning(user_id, household_id, percent_spent, month_name) do
    create_notification_for_user(
      user_id,
      household_id,
      "budget_warning",
      "Budget alert: #{percent_spent}% spent",
      message: "You've spent #{percent_spent}% of your monthly budget for #{month_name}",
      data: %{percent_spent: percent_spent, month: month_name}
    )
  end

  @doc """
  Creates a habit reminder notification.
  """
  def notify_habit_reminder(user_id, household_id, habit) do
    create_notification_for_user(
      user_id,
      household_id,
      "habit_reminder",
      "Time for: #{habit.name}",
      message: "Don't forget to complete your habit today!",
      link_type: "habit",
      link_id: habit.id,
      data: %{habit_id: habit.id, streak: habit.streak_count}
    )
  end

  # Private helpers

  defp format_due_time(date, nil), do: "on #{date}"
  defp format_due_time(date, time), do: "on #{date} at #{time}"
end
