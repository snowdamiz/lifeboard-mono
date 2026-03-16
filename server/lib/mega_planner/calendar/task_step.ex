defmodule MegaPlanner.Calendar.TaskStep do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "task_steps" do
    field :content, :string
    field :completed, :boolean, default: false
    field :position, :integer, default: 0

    belongs_to :task, MegaPlanner.Calendar.Task

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(step, attrs) do
    step
    |> cast(attrs, [:content, :completed, :position, :task_id])
    |> validate_required([:content])
    |> validate_change(:task_id, fn :task_id, id ->
      if MegaPlanner.Repo.get(MegaPlanner.Calendar.Task, id),
        do: [],
        else: [task_id: "does not exist"]
    end)
  end
end
