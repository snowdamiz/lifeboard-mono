defmodule MegaPlannerWeb.NotificationController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Notifications

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    opts = []
    opts = if params["unread_only"] == "true", do: Keyword.put(opts, :unread_only, true), else: opts
    opts = if limit = params["limit"], do: Keyword.put(opts, :limit, String.to_integer(limit)), else: opts

    notifications = Notifications.list_notifications(user.id, opts)
    unread_count = Notifications.unread_count(user.id)

    json(conn, %{
      data: Enum.map(notifications, &notification_to_json/1),
      unread_count: unread_count
    })
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Notifications.get_notification(id, user.id) do
      nil -> {:error, :not_found}
      notification -> json(conn, %{data: notification_to_json(notification)})
    end
  end

  def mark_read(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with notification when not is_nil(notification) <- Notifications.get_notification(id, user.id),
         {:ok, notification} <- Notifications.mark_as_read(notification) do
      json(conn, %{data: notification_to_json(notification)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def mark_all_read(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    {count, _} = Notifications.mark_all_as_read(user.id)

    json(conn, %{message: "Marked #{count} notifications as read"})
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with notification when not is_nil(notification) <- Notifications.get_notification(id, user.id),
         {:ok, _notification} <- Notifications.delete_notification(notification) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def unread_count(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    count = Notifications.unread_count(user.id)
    json(conn, %{count: count})
  end

  # Preferences endpoints

  def get_preferences(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    {:ok, preferences} = Notifications.get_or_create_preferences(user.id, user.household_id)
    json(conn, %{data: preferences_to_json(preferences)})
  end

  def update_preferences(conn, %{"preferences" => prefs_params}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, preferences} <- Notifications.get_or_create_preferences(user.id, user.household_id),
         {:ok, updated} <- Notifications.update_preferences(preferences, prefs_params) do
      json(conn, %{data: preferences_to_json(updated)})
    end
  end

  defp notification_to_json(notification) do
    %{
      id: notification.id,
      type: notification.type,
      title: notification.title,
      message: notification.message,
      data: notification.data,
      read: notification.read,
      read_at: notification.read_at,
      link_type: notification.link_type,
      link_id: notification.link_id,
      inserted_at: notification.inserted_at
    }
  end

  defp preferences_to_json(preferences) do
    %{
      task_due_enabled: preferences.task_due_enabled,
      task_due_hours_before: preferences.task_due_hours_before,
      low_inventory_enabled: preferences.low_inventory_enabled,
      budget_threshold_enabled: preferences.budget_threshold_enabled,
      budget_threshold_percent: preferences.budget_threshold_percent,
      habit_reminder_enabled: preferences.habit_reminder_enabled,
      push_enabled: preferences.push_enabled
    }
  end
end
