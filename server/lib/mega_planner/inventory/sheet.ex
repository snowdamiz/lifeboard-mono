defmodule MegaPlanner.Inventory.Sheet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory_sheets" do
    field :name, :string
    field :columns, :map, default: %{}

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    has_many :items, MegaPlanner.Inventory.Item

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sheet, attrs) do
    sheet
    |> cast(attrs, [:name, :columns, :user_id, :household_id])
    |> validate_required([:name, :user_id, :household_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
  end
end
