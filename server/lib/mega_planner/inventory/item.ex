defmodule MegaPlanner.Inventory.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory_items" do
    field :name, :string
    field :quantity, :decimal, default: 0
    field :min_quantity, :decimal, default: 0
    field :is_necessity, :boolean, default: false
    field :store, :string
    field :unit_of_measure, :string
    field :brand, :string
    field :count, :decimal
    field :count_unit, :string
    field :price_per_count, :decimal
    field :price_per_unit, :decimal
    field :taxable, :boolean, default: false
    field :total_price, :decimal
    field :store_code, :string
    field :item_name, :string
    field :custom_fields, :map, default: %{}
    # "count" = consumed by individual pieces/weight (batteries, potatoes)
    # "quantity" = consumed as whole unit (couch, TV)
    field :usage_mode, :string, default: "count"

    field :purchase_date, :utc_datetime

    belongs_to :purchase, MegaPlanner.Receipts.Purchase
    belongs_to :trip, MegaPlanner.Receipts.Trip
    belongs_to :stop, MegaPlanner.Receipts.Stop

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
    |> cast(attrs, [
      :name, :quantity, :min_quantity, :is_necessity, :store, :unit_of_measure, :brand,
      :count, :count_unit, :price_per_count, :price_per_unit, :taxable, :total_price, :store_code, :item_name,
      :custom_fields, :sheet_id, :purchase_id, :trip_id, :stop_id, :purchase_date, :usage_mode
    ])
    |> validate_required([:name, :sheet_id])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> validate_number(:min_quantity, greater_than_or_equal_to: 0)
    |> validate_inclusion(:usage_mode, ["count", "quantity"])
    |> foreign_key_constraint(:sheet_id)
  end
end

