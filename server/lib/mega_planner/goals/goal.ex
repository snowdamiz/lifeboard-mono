defmodule MegaPlanner.Goals.Goal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(not_started in_progress completed abandoned)

  schema "goals" do
    field :title, :string
    field :description, :string
    field :target_date, :date
    field :status, :string, default: "not_started"
    field :category, :string
    field :progress, :integer, default: 0
    field :linked_task_ids, {:array, :binary_id}, default: []

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :goal_category, MegaPlanner.Goals.GoalCategory
    has_many :milestones, MegaPlanner.Goals.Milestone, on_delete: :delete_all
    has_many :status_changes, MegaPlanner.Goals.GoalStatusChange, on_delete: :delete_all
    many_to_many :tags, MegaPlanner.Tags.Tag, join_through: "goals_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:title, :description, :target_date, :status, :category, :progress, :linked_task_ids, :user_id, :household_id, :goal_category_id])
    |> validate_required([:title, :user_id, :household_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:progress, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:goal_category_id)
  end

  @doc """
  Changeset for updating tags on a goal.
  """
  def tags_changeset(goal, tags) do
    goal
    |> cast(%{}, [])
    |> put_assoc(:tags, tags)
  end
end
