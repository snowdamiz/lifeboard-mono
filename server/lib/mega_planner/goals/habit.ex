defmodule MegaPlanner.Goals.Habit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @frequencies ~w(daily weekly)

  schema "habits" do
    field :name, :string
    field :description, :string
    field :frequency, :string, default: "daily"
    field :days_of_week, {:array, :integer}
    field :reminder_time, :time
    field :scheduled_time, :time
    field :duration_minutes, :integer
    field :color, :string, default: "#10b981"
    field :is_start_of_day, :boolean, default: false

    field :streak_count, :integer, default: 0
    field :longest_streak, :integer, default: 0
    field :last_completed_at, :utc_datetime

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :inventory, MegaPlanner.Goals.HabitInventory
    has_many :completions, MegaPlanner.Goals.HabitCompletion, on_delete: :delete_all
    many_to_many :tags, MegaPlanner.Tags.Tag, join_through: "habits_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(habit, attrs) do
    # Pre-process time fields to handle HH:MM format from HTML time inputs
    attrs = normalize_time_fields(attrs)
    
    habit
    |> cast(attrs, [:name, :description, :frequency, :days_of_week, :reminder_time, :scheduled_time, :duration_minutes, :color, :is_start_of_day, :inventory_id, :user_id, :household_id])
    |> validate_required([:name, :user_id, :household_id])
    |> validate_inclusion(:frequency, @frequencies)
    |> validate_days_of_week()
    |> validate_duration_minutes()
    |> foreign_key_constraint(:household_id)
  end

  # Normalize time fields to add seconds if missing (HH:MM -> HH:MM:SS)
  # Handles both string and atom keys
  defp normalize_time_fields(attrs) when is_map(attrs) do
    attrs
    |> normalize_time_field("scheduled_time")
    |> normalize_time_field(:scheduled_time)
    |> normalize_time_field("reminder_time")
    |> normalize_time_field(:reminder_time)
  end

  defp normalize_time_field(attrs, field) do
    case Map.get(attrs, field) do
      nil -> attrs
      time when is_binary(time) ->
        # If time is in HH:MM format, add :00 for seconds
        normalized = if String.match?(time, ~r/^\d{2}:\d{2}$/) do
          time <> ":00"
        else
          time
        end
        Map.put(attrs, field, normalized)
      _ -> attrs
    end
  end

  def streak_changeset(habit, attrs) do
    habit
    |> cast(attrs, [:streak_count, :longest_streak, :last_completed_at])
  end

  defp validate_days_of_week(changeset) do
    case get_field(changeset, :days_of_week) do
      nil -> changeset
      days when is_list(days) ->
        if Enum.all?(days, &(&1 >= 0 and &1 <= 6)) do
          changeset
        else
          add_error(changeset, :days_of_week, "must be between 0 (Sunday) and 6 (Saturday)")
        end
      _ -> add_error(changeset, :days_of_week, "must be a list")
    end
  end

  defp validate_duration_minutes(changeset) do
    case get_field(changeset, :duration_minutes) do
      nil -> changeset
      duration when is_integer(duration) and duration > 0 -> changeset
      _ -> add_error(changeset, :duration_minutes, "must be a positive integer")
    end
  end

  @doc """
  Changeset for updating habit tags.
  """
  def tags_changeset(habit, tags) do
    habit
    |> change()
    |> put_assoc(:tags, tags)
  end
end
