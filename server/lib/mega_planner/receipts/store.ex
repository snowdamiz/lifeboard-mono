defmodule MegaPlanner.Receipts.Store do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stores" do
    field :name, :string
    field :address, :string
    field :state, :string
    field :store_code, :string
    field :tax_rate, :decimal
    field :image_url, :string

    belongs_to :household, MegaPlanner.Households.Household
    has_many :stops, MegaPlanner.Receipts.Stop

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(store, attrs) do
    store
    |> cast(attrs, [:name, :address, :state, :store_code, :tax_rate, :image_url, :household_id])
    |> validate_required([:name, :household_id])
    |> foreign_key_constraint(:household_id)
  end
end
