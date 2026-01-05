defmodule MegaPlanner.Inventory.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory_items" do
    field :name, :string
    field :quantity, :integer, default: 0
    field :min_quantity, :integer, default: 0
    field :is_necessity, :boolean, default: false
    field :store, :string
    field :unit_of_measure, :string
    field :brand, :string
    field :custom_fields, :map, default: %{}

    belongs_to :sheet, MegaPlanner.Inventory.Sheet
    has_many :shopping_list_items, MegaPlanner.Inventory.ShoppingListItem, foreign_key: :inventory_item_id
    many_to_many :tags, MegaPlanner.Tags.Tag,
      join_through: "inventory_items_tags",
      join_keys: [inventory_item_id: :id, tag_id: :id],
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :quantity, :min_quantity, :is_necessity, :store, :unit_of_measure, :brand, :custom_fields, :sheet_id])
    |> validate_required([:name, :sheet_id])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> validate_number(:min_quantity, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:sheet_id)
  end
end
