defmodule MegaPlanner.Receipts.Unit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "units" do
    field :name, :string
    belongs_to :household, MegaPlanner.Households.Household

    timestamps()
  end

  @doc false
  def changeset(unit, attrs) do
    unit
    |> cast(attrs, [:name, :household_id])
    |> validate_required([:name, :household_id])
    |> validate_length(:name, min: 1, max: 50)
    |> unique_constraint([:household_id, :name], name: :units_household_id_name_index)
  end
end
