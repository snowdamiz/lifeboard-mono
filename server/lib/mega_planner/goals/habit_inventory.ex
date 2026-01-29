defmodule MegaPlanner.Goals.HabitInventory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "habit_inventories" do
    field :name, :string
    field :color, :string, default: "#10b981"
    field :position, :integer, default: 0
    field :coverage_mode, :string, default: "partial_day"
    field :linked_inventory_ids, {:array, :binary_id}, default: []
    field :day_start_time, :time
    field :day_end_time, :time

    belongs_to :household, MegaPlanner.Households.Household
    has_many :habits, MegaPlanner.Goals.Habit, foreign_key: :inventory_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(inventory, attrs) do
    inventory
    |> cast(attrs, [:name, :color, :position, :household_id, :coverage_mode, :linked_inventory_ids, :day_start_time, :day_end_time])
    |> validate_required([:name, :household_id])
    |> validate_inclusion(:coverage_mode, ["whole_day", "partial_day"])
    |> foreign_key_constraint(:household_id)
  end
end

