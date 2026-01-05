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
    field :color, :string, default: "#10b981"

    field :streak_count, :integer, default: 0
    field :longest_streak, :integer, default: 0
    field :last_completed_at, :utc_datetime

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    has_many :completions, MegaPlanner.Goals.HabitCompletion, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(habit, attrs) do
    habit
    |> cast(attrs, [:name, :description, :frequency, :days_of_week, :reminder_time, :color, :user_id, :household_id])
    |> validate_required([:name, :user_id, :household_id])
    |> validate_inclusion(:frequency, @frequencies)
    |> validate_days_of_week()
    |> foreign_key_constraint(:household_id)
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
end
