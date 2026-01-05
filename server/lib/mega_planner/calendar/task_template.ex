defmodule MegaPlanner.Calendar.TaskTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @task_types ~w(todo timed floating)

  schema "task_templates" do
    field :name, :string
    field :description, :string
    field :category, :string

    # Template task data
    field :title, :string
    field :task_description, :string
    field :duration_minutes, :integer
    field :priority, :integer, default: 1
    field :task_type, :string, default: "todo"
    field :default_steps, {:array, :string}, default: []

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :description, :category, :title, :task_description, :duration_minutes, :priority, :task_type, :default_steps, :user_id, :household_id])
    |> validate_required([:name, :title, :user_id, :household_id])
    |> validate_inclusion(:task_type, @task_types)
    |> validate_number(:priority, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:duration_minutes, greater_than: 0)
    |> foreign_key_constraint(:household_id)
  end
end
