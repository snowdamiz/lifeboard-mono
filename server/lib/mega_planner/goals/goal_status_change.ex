defmodule MegaPlanner.Goals.GoalStatusChange do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "goal_status_changes" do
    field :from_status, :string
    field :to_status, :string
    field :notes, :string

    belongs_to :goal, MegaPlanner.Goals.Goal
    belongs_to :user, MegaPlanner.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(status_change, attrs) do
    status_change
    |> cast(attrs, [:from_status, :to_status, :notes, :goal_id, :user_id])
    |> validate_required([:to_status, :goal_id])
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:user_id)
  end
end

