defmodule MegaPlanner.Goals.HabitCompletion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "habit_completions" do
    field :completed_at, :utc_datetime
    field :date, :date
    field :status, :string, default: "completed"
    field :not_today_reason, :string

    belongs_to :habit, MegaPlanner.Goals.Habit

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(completion, attrs) do
    completion
    |> cast(attrs, [:completed_at, :date, :habit_id, :status, :not_today_reason])
    |> validate_required([:completed_at, :date, :habit_id, :status])
    |> validate_inclusion(:status, ["completed", "skipped"])
    |> validate_skip_reason()
    |> unique_constraint([:habit_id, :date])
  end

  defp validate_skip_reason(changeset) do
    status = get_field(changeset, :status)
    reason = get_field(changeset, :not_today_reason)

    if status == "skipped" and (is_nil(reason) or String.trim(reason) == "") do
      add_error(changeset, :not_today_reason, "is required when skipping a habit")
    else
      changeset
    end
  end
end
