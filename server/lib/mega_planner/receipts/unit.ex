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
    |> capitalize_name()
    |> unique_constraint([:household_id, :name], name: :units_household_id_name_index)
  end

  # Capitalize the first letter of the unit name (e.g., "box" -> "Box")
  defp capitalize_name(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, String.capitalize(name))
    end
  end
end
