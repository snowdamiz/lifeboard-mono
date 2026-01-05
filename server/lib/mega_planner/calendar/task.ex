defmodule MegaPlanner.Calendar.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ["not_started", "in_progress", "completed"]
  @task_types ["todo", "timed", "floating"]

  schema "tasks" do
    field :title, :string
    field :description, :string
    field :date, :date
    field :start_time, :time
    field :duration_minutes, :integer
    field :priority, :integer, default: 0
    field :status, :string, default: "not_started"
    field :is_recurring, :boolean, default: false
    field :recurrence_rule, :map
    field :task_type, :string, default: "todo"

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :parent_task, __MODULE__
    has_many :steps, MegaPlanner.Calendar.TaskStep
    many_to_many :tags, MegaPlanner.Tags.Tag, join_through: "tasks_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:title, :description, :date, :start_time, :duration_minutes,
                    :priority, :status, :is_recurring, :recurrence_rule, :task_type,
                    :user_id, :household_id, :parent_task_id])
    |> validate_required([:title, :user_id, :household_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:task_type, @task_types)
    |> validate_number(:duration_minutes, greater_than: 0)
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:parent_task_id)
  end
end
