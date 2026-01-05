defmodule MegaPlanner.Goals.HabitCompletion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "habit_completions" do
    field :completed_at, :utc_datetime
    field :date, :date

    belongs_to :habit, MegaPlanner.Goals.Habit

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(completion, attrs) do
    completion
    |> cast(attrs, [:completed_at, :date, :habit_id])
    |> validate_required([:completed_at, :date, :habit_id])
    |> unique_constraint([:habit_id, :date])
  end
end
