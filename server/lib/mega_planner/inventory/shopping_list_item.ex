defmodule MegaPlanner.Inventory.ShoppingListItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shopping_list_items" do
    field :quantity_needed, :integer, default: 1
    field :purchased, :boolean, default: false
    field :name, :string  # For manual items without inventory reference

    belongs_to :shopping_list, MegaPlanner.Inventory.ShoppingList
    belongs_to :inventory_item, MegaPlanner.Inventory.Item
    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:quantity_needed, :purchased, :name, :shopping_list_id, :inventory_item_id, :user_id, :household_id])
    |> validate_required([:user_id, :household_id])
    |> validate_number(:quantity_needed, greater_than: 0)
    |> validate_name_or_inventory_item()
    |> foreign_key_constraint(:shopping_list_id)
    |> foreign_key_constraint(:inventory_item_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
  end

  # Either name or inventory_item_id must be provided
  defp validate_name_or_inventory_item(changeset) do
    name = get_field(changeset, :name)
    inventory_item_id = get_field(changeset, :inventory_item_id)

    if is_nil(name) and is_nil(inventory_item_id) do
      add_error(changeset, :name, "or inventory_item_id must be provided")
    else
      changeset
    end
  end
end
