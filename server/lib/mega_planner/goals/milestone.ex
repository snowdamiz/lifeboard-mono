defmodule MegaPlanner.Goals.Milestone do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "goal_milestones" do
    field :title, :string
    field :completed, :boolean, default: false
    field :completed_at, :utc_datetime
    field :position, :integer, default: 0

    belongs_to :goal, MegaPlanner.Goals.Goal

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(milestone, attrs) do
    milestone
    |> cast(attrs, [:title, :completed, :completed_at, :position, :goal_id])
    |> validate_required([:title, :goal_id])
  end

  def complete_changeset(milestone) do
    milestone
    |> change(%{completed: true, completed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  def uncomplete_changeset(milestone) do
    milestone
    |> change(%{completed: false, completed_at: nil})
  end
end
