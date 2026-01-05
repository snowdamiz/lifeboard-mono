defmodule MegaPlanner.Inventory.ShoppingList do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shopping_lists" do
    field :name, :string
    field :is_auto_generated, :boolean, default: false
    field :notes, :string

    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :user, MegaPlanner.Accounts.User
    has_many :items, MegaPlanner.Inventory.ShoppingListItem, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :is_auto_generated, :notes, :household_id, :user_id])
    |> validate_required([:name, :household_id])
    |> validate_length(:name, min: 1, max: 200)
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:household_id, :is_auto_generated],
        name: :shopping_lists_household_auto_generated_unique,
        message: "only one auto-generated list per household")
  end
end

