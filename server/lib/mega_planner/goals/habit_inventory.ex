defmodule MegaPlanner.Goals.HabitInventory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "habit_inventories" do
    field :name, :string
    field :color, :string, default: "#10b981"
    field :position, :integer, default: 0

    belongs_to :household, MegaPlanner.Households.Household
    has_many :habits, MegaPlanner.Goals.Habit

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(inventory, attrs) do
    inventory
    |> cast(attrs, [:name, :color, :position, :household_id])
    |> validate_required([:name, :household_id])
    |> foreign_key_constraint(:household_id)
  end
end
