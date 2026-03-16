defmodule MegaPlanner.Accounts.UserPreferences do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @widget_types MapSet.new([
                  "tasks_today",
                  "tasks_detail",
                  "inventory_status",
                  "low_inventory",
                  "budget_summary",
                  "budget_sources",
                  "habits_progress",
                  "active_goals",
                  "recent_notes",
                  "upcoming_tasks",
                  "notifications_summary",
                  "habit_streaks",
                  "weekly_overview",
                  "quick_actions"
                ])
  @uuid_like_pattern ~r/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i

  schema "user_preferences" do
    field :nav_order, {:array, :string}, default: []
    field :dashboard_widgets, {:array, :map}, default: []
    field :theme, :string, default: "system"
    field :settings, :map, default: %{}

    belongs_to :user, MegaPlanner.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(preferences, attrs) do
    preferences
    |> cast(attrs, [:nav_order, :dashboard_widgets, :theme, :settings, :user_id])
    |> update_change(:dashboard_widgets, &normalize_dashboard_widgets/1)
    |> validate_required([:user_id])
    |> validate_inclusion(:theme, ["light", "dark", "system"])
    |> unique_constraint(:user_id)
    |> validate_change(:user_id, fn :user_id, id ->
      if MegaPlanner.Repo.get(MegaPlanner.Accounts.User, id),
        do: [],
        else: [user_id: "does not exist"]
    end)
  end

  def normalize_dashboard_widgets(widgets) when is_list(widgets) do
    widgets
    |> Enum.map(&normalize_dashboard_widget/1)
    |> Enum.filter(&valid_dashboard_widget?/1)
  end

  def normalize_dashboard_widgets(_), do: []

  defp normalize_dashboard_widget(widget) when is_map(widget) do
    normalized_widget =
      Enum.into(widget, %{}, fn {key, value} ->
        {to_string(key), value}
      end)

    type = normalize_widget_value(normalized_widget["type"])
    id = normalize_widget_value(normalized_widget["id"]) || type

    normalized_widget
    |> Map.put("type", type)
    |> Map.put("id", id)
  end

  defp normalize_dashboard_widget(widget), do: widget

  defp valid_dashboard_widget?(%{"id" => id, "type" => type})
       when is_binary(id) and is_binary(type) do
    MapSet.member?(@widget_types, type)
  end

  defp valid_dashboard_widget?(_), do: false

  defp normalize_widget_value(value) when is_binary(value) do
    case decode_migrated_widget_value(value) do
      {:ok, decoded} -> decoded
      :error -> value
    end
  end

  defp normalize_widget_value(value), do: value

  defp decode_migrated_widget_value(value) do
    if Regex.match?(@uuid_like_pattern, value) do
      value
      |> String.replace("-", "")
      |> Base.decode16(case: :mixed)
      |> case do
        {:ok, decoded} ->
          if String.valid?(decoded) and MapSet.member?(@widget_types, decoded) do
            {:ok, decoded}
          else
            :error
          end

        _ ->
          :error
      end
    else
      :error
    end
  end
end
