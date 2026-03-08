defmodule MegaPlanner.Inventory.ShoppingListItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shopping_list_items" do
    field :quantity_needed, :integer, default: 1
    field :purchased, :boolean, default: false
    field :name, :string  # For manual items without inventory reference
    field :completed_at, :utc_datetime  # When a purchase auto-matched this item

    belongs_to :shopping_list, MegaPlanner.Inventory.ShoppingList
    belongs_to :inventory_item, MegaPlanner.Inventory.Item
    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:quantity_needed, :purchased, :completed_at, :name, :shopping_list_id, :inventory_item_id, :user_id, :household_id])
    |> validate_required([:user_id, :household_id])
    |> validate_number(:quantity_needed, greater_than: 0)
    |> validate_name_or_inventory_item()
    |> validate_change(:shopping_list_id, fn :shopping_list_id, id ->
         if MegaPlanner.Repo.get(MegaPlanner.Inventory.ShoppingList, id),
           do: [],
           else: [shopping_list_id: "does not exist"]
       end)
    |> validate_change(:inventory_item_id, fn :inventory_item_id, id ->
         if MegaPlanner.Repo.get(MegaPlanner.Inventory.Item, id),
           do: [],
           else: [inventory_item_id: "does not exist"]
       end)
    |> validate_change(:user_id, fn :user_id, id ->
         if MegaPlanner.Repo.get(MegaPlanner.Accounts.User, id),
           do: [],
           else: [user_id: "does not exist"]
       end)
    |> validate_change(:household_id, fn :household_id, id ->
         if MegaPlanner.Repo.get(MegaPlanner.Households.Household, id),
           do: [],
           else: [household_id: "does not exist"]
       end)
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
