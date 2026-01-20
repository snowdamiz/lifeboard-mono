defmodule MegaPlanner.Receipts.Brand do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "brands" do
    field :name, :string
    field :default_item, :string
    field :default_unit_measurement, :string
    field :default_tags, {:array, :binary_id}
    field :image_url, :string

    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:name, :default_item, :default_unit_measurement, :default_tags, :image_url, :household_id])
    |> validate_required([:name, :household_id])
    |> unique_constraint([:household_id, :name])
    |> foreign_key_constraint(:household_id)
  end
end
